package payment

import (
	"context"

	"github.com/google/uuid"
)

type CheckoutRequest struct {
	TxRef         string
	UserID        uuid.UUID
	UserEmail     string
	UserPhone     string
	UserName      string
	Amount        float64
	Currency      string
	Title         string
	Description   string
	CallbackURL   string
	ReturnURL     string
	PaymentMethod string // "telebirr", "cbe_birr", "card"
}

type CheckoutResponse struct {
	TxRef       string `json:"tx_ref"`
	CheckoutURL string `json:"checkout_url"`
	Status      string `json:"status"`
}

type WebhookPayload struct {
	TxRef         string  `json:"tx_ref"`
	Amount        float64 `json:"amount"`
	Currency      string  `json:"currency"`
	Status        string  `json:"status"` // "success", "failed"
	PaymentMethod string  `json:"payment_method"`
	Reference     string  `json:"reference"`
	Raw           map[string]any `json:"raw"`
}

type TransactionStatus struct {
	TxRef         string  `json:"tx_ref"`
	Amount        float64 `json:"amount"`
	Currency      string  `json:"currency"`
	Status        string  `json:"status"` // "success", "pending", "failed"
	PaymentMethod string  `json:"payment_method"`
	Reference     string  `json:"reference"`
	Raw           map[string]any `json:"raw"`
}

type PaymentProvider interface {
	Name() string
	InitiateCheckout(ctx context.Context, req *CheckoutRequest) (*CheckoutResponse, error)
	VerifyWebhook(ctx context.Context, rawBody []byte, signature string) (*WebhookPayload, error)
	VerifyTransaction(ctx context.Context, txRef string) (*TransactionStatus, error)
}
