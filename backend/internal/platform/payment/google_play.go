package payment

import (
	"context"
	"fmt"
)

type GooglePlayConfig struct {
	PackageName            string
	ServiceAccountJSONPath string
}

type GooglePlayProvider struct {
	cfg GooglePlayConfig
}

func NewGooglePlayProvider(cfg GooglePlayConfig) *GooglePlayProvider {
	return &GooglePlayProvider{cfg: cfg}
}

func (g *GooglePlayProvider) Name() string {
	return "google_play"
}

func (g *GooglePlayProvider) InitiateCheckout(ctx context.Context, req *CheckoutRequest) (*CheckoutResponse, error) {
	// Google Play is initiated client-side on Android device through in-app billing library
	return &CheckoutResponse{
		TxRef:       req.TxRef,
		CheckoutURL: "",
		Status:      "pending",
	}, nil
}

func (g *GooglePlayProvider) VerifyWebhook(ctx context.Context, rawBody []byte, signature string) (*WebhookPayload, error) {
	// Google Cloud Pub/Sub Real-time developer notifications (RTDN)
	return nil, fmt.Errorf("google play RTDN webhook not implemented yet")
}

func (g *GooglePlayProvider) VerifyTransaction(ctx context.Context, txRef string) (*TransactionStatus, error) {
	return &TransactionStatus{
		TxRef:  txRef,
		Status: "pending",
	}, nil
}
