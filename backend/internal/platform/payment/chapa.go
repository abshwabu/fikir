package payment

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"
)

var (
	ErrInvalidSignature    = errors.New("invalid webhook signature")
	ErrTransactionNotFound = errors.New("transaction not found")
	ErrPaymentFailed       = errors.New("payment failed or cancelled")
)

type ChapaConfig struct {
	BaseURL       string
	SecretKey     string
	WebhookSecret string
	HTTPClient    *http.Client
}

type ChapaProvider struct {
	cfg        ChapaConfig
	httpClient *http.Client
}

func NewChapaProvider(cfg ChapaConfig) *ChapaProvider {
	if cfg.BaseURL == "" {
		cfg.BaseURL = "https://api.chapa.co/v1"
	}
	client := cfg.HTTPClient
	if client == nil {
		client = &http.Client{Timeout: 15 * time.Second}
	}
	return &ChapaProvider{
		cfg:        cfg,
		httpClient: client,
	}
}

func (c *ChapaProvider) Name() string {
	return "chapa"
}

func (c *ChapaProvider) InitiateCheckout(ctx context.Context, req *CheckoutRequest) (*CheckoutResponse, error) {
	url := fmt.Sprintf("%s/transaction/initialize", strings.TrimRight(c.cfg.BaseURL, "/"))

	firstName := req.UserName
	lastName := "User"
	if parts := strings.Fields(req.UserName); len(parts) > 1 {
		firstName = parts[0]
		lastName = strings.Join(parts[1:], " ")
	}
	if firstName == "" {
		firstName = "Fikir"
	}

	email := req.UserEmail
	if email == "" {
		email = fmt.Sprintf("user_%s@fikir.et", req.UserID.String()[:8])
	}

	payload := map[string]any{
		"amount":                     fmt.Sprintf("%.2f", req.Amount),
		"currency":                   req.Currency,
		"email":                      email,
		"first_name":                 firstName,
		"last_name":                  lastName,
		"phone_number":               req.UserPhone,
		"tx_ref":                     req.TxRef,
		"callback_url":               req.CallbackURL,
		"return_url":                 req.ReturnURL,
		"customization[title]":       req.Title,
		"customization[description]": req.Description,
	}

	bodyBytes, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal chapa initialize payload: %w", err)
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(bodyBytes))
	if err != nil {
		return nil, fmt.Errorf("failed to create http request: %w", err)
	}
	httpReq.Header.Set("Authorization", "Bearer "+c.cfg.SecretKey)
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("chapa initialize request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read chapa response: %w", err)
	}

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("chapa returned status %d: %s", resp.StatusCode, string(respBody))
	}

	var initResp struct {
		Message string `json:"message"`
		Status  string `json:"status"`
		Data    struct {
			CheckoutURL string `json:"checkout_url"`
		} `json:"data"`
	}

	if err := json.Unmarshal(respBody, &initResp); err != nil {
		return nil, fmt.Errorf("failed to parse chapa response: %w", err)
	}

	if initResp.Data.CheckoutURL == "" {
		return nil, fmt.Errorf("chapa did not return checkout url: %s", string(respBody))
	}

	return &CheckoutResponse{
		TxRef:       req.TxRef,
		CheckoutURL: initResp.Data.CheckoutURL,
		Status:      "pending",
	}, nil
}

func (c *ChapaProvider) VerifyWebhook(ctx context.Context, rawBody []byte, signature string) (*WebhookPayload, error) {
	secret := c.cfg.WebhookSecret
	if secret == "" {
		secret = c.cfg.SecretKey
	}

	if secret != "" {
		mac := hmac.New(sha256.New, []byte(secret))
		mac.Write(rawBody)
		expectedMAC := hex.EncodeToString(mac.Sum(nil))

		if !hmac.Equal([]byte(strings.ToLower(signature)), []byte(strings.ToLower(expectedMAC))) {
			return nil, ErrInvalidSignature
		}
	}

	var payload struct {
		Event         string         `json:"event"`
		TxRef         string         `json:"tx_ref"`
		Reference     string         `json:"reference"`
		Amount        any            `json:"amount"`
		Currency      string         `json:"currency"`
		Status        string         `json:"status"`
		PaymentMethod string         `json:"payment_method"`
		Raw           map[string]any `json:"-"`
	}

	if err := json.Unmarshal(rawBody, &payload); err != nil {
		return nil, fmt.Errorf("failed to parse webhook body: %w", err)
	}

	var rawMap map[string]any
	_ = json.Unmarshal(rawBody, &rawMap)

	amountFloat := parseAmount(payload.Amount)

	status := strings.ToLower(payload.Status)
	if status == "success" || payload.Event == "charge.success" {
		status = "success"
	} else {
		status = "failed"
	}

	return &WebhookPayload{
		TxRef:         payload.TxRef,
		Amount:        amountFloat,
		Currency:      payload.Currency,
		Status:        status,
		PaymentMethod: payload.PaymentMethod,
		Reference:     payload.Reference,
		Raw:           rawMap,
	}, nil
}

func (c *ChapaProvider) VerifyTransaction(ctx context.Context, txRef string) (*TransactionStatus, error) {
	url := fmt.Sprintf("%s/transaction/verify/%s", strings.TrimRight(c.cfg.BaseURL, "/"), txRef)

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create http request: %w", err)
	}
	httpReq.Header.Set("Authorization", "Bearer "+c.cfg.SecretKey)

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("chapa verify request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read chapa verify response: %w", err)
	}

	if resp.StatusCode == http.StatusNotFound {
		return nil, ErrTransactionNotFound
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("chapa verify returned status %d: %s", resp.StatusCode, string(respBody))
	}

	var verifyResp struct {
		Message string `json:"message"`
		Status  string `json:"status"`
		Data    struct {
			TxRef         string `json:"tx_ref"`
			Reference     string `json:"reference"`
			Status        string `json:"status"`
			Amount        any    `json:"amount"`
			Currency      string `json:"currency"`
			PaymentMethod string `json:"payment_method"`
		} `json:"data"`
	}

	if err := json.Unmarshal(respBody, &verifyResp); err != nil {
		return nil, fmt.Errorf("failed to parse chapa verify body: %w", err)
	}

	rawMap := make(map[string]any)
	_ = json.Unmarshal(respBody, &rawMap)

	statusStr := strings.ToLower(verifyResp.Data.Status)
	if statusStr == "success" {
		statusStr = "success"
	} else if statusStr == "pending" {
		statusStr = "pending"
	} else {
		statusStr = "failed"
	}

	return &TransactionStatus{
		TxRef:         verifyResp.Data.TxRef,
		Amount:        parseAmount(verifyResp.Data.Amount),
		Currency:      verifyResp.Data.Currency,
		Status:        statusStr,
		PaymentMethod: verifyResp.Data.PaymentMethod,
		Reference:     verifyResp.Data.Reference,
		Raw:           rawMap,
	}, nil
}

func parseAmount(v any) float64 {
	switch val := v.(type) {
	case float64:
		return val
	case int:
		return float64(val)
	case int64:
		return float64(val)
	case string:
		f, _ := strconv.ParseFloat(val, 64)
		return f
	default:
		return 0
	}
}
