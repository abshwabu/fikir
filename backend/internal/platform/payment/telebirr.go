package payment

import (
	"context"
	"fmt"
)

// TelebirrConfig holds credentials for direct Telebirr integration (Fabric SDK/H5).
type TelebirrConfig struct {
	AppID     string
	AppKey    string
	ShortCode string
	PublicKey string
	NotifyURL string
	ReturnURL string
}

// TelebirrProvider implements PaymentProvider for Telebirr Direct.
type TelebirrProvider struct {
	cfg TelebirrConfig
}

func NewTelebirrProvider(cfg TelebirrConfig) *TelebirrProvider {
	return &TelebirrProvider{cfg: cfg}
}

func (t *TelebirrProvider) Name() string {
	return "telebirr"
}

func (t *TelebirrProvider) InitiateCheckout(ctx context.Context, req *CheckoutRequest) (*CheckoutResponse, error) {
	if t.cfg.AppID == "" || t.cfg.AppKey == "" {
		// Stub implementation when API credentials are not yet provisioned.
		return &CheckoutResponse{
			TxRef:       req.TxRef,
			CheckoutURL: fmt.Sprintf("https://telebirr.ethiotelecom.et/checkout-stub?tx_ref=%s", req.TxRef),
			Status:      "pending",
		}, nil
	}

	// In production with Fabric API credentials:
	// Format USSD/H5 payment request, sign with private key and return web/in-app checkout URL.
	return &CheckoutResponse{
		TxRef:       req.TxRef,
		CheckoutURL: fmt.Sprintf("https://telebirr.ethiotelecom.et/pay?outTradeNo=%s", req.TxRef),
		Status:      "pending",
	}, nil
}

func (t *TelebirrProvider) VerifyWebhook(ctx context.Context, rawBody []byte, signature string) (*WebhookPayload, error) {
	// Telebirr direct callback verification using RSA public key verification.
	return nil, fmt.Errorf("telebirr direct webhook verification not configured; use Chapa telebirr rail")
}

func (t *TelebirrProvider) VerifyTransaction(ctx context.Context, txRef string) (*TransactionStatus, error) {
	return &TransactionStatus{
		TxRef:  txRef,
		Status: "pending",
	}, nil
}
