package push

import (
	"context"
	"fmt"
	"os"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"github.com/rs/zerolog/log"
	"google.golang.org/api/option"

	"github.com/abshwabu/fikir/backend/internal/config"
)

// NotificationMessage encapsulates push payload
type NotificationMessage struct {
	Tokens      []string          `json:"tokens"`
	Category    string            `json:"category"`
	Title       string            `json:"title"`
	Body        string            `json:"body"`
	CollapseKey string            `json:"collapse_key,omitempty"`
	Data        map[string]string `json:"data,omitempty"`
}

// PushNotifier defines the push notification dispatch interface
type PushNotifier interface {
	Send(ctx context.Context, msg *NotificationMessage) error
}

// ConsolePushNotifier prints notifications for development/testing
type ConsolePushNotifier struct{}

func NewConsolePushNotifier() *ConsolePushNotifier {
	return &ConsolePushNotifier{}
}

func (c *ConsolePushNotifier) Send(ctx context.Context, msg *NotificationMessage) error {
	log.Info().
		Int("token_count", len(msg.Tokens)).
		Str("category", msg.Category).
		Str("title", msg.Title).
		Str("body", msg.Body).
		Str("collapse_key", msg.CollapseKey).
		Interface("data", msg.Data).
		Msg("[PUSH-CONSOLE] Simulated push notification sent")
	return nil
}

// FCMNotifier sends real push notifications via Firebase Cloud Messaging
type FCMNotifier struct {
	client *messaging.Client
}

func NewFCMNotifier(ctx context.Context, cfg config.FCMConfig) (*FCMNotifier, error) {
	var opts []option.ClientOption
	if cfg.CredentialsFile != "" {
		if _, err := os.Stat(cfg.CredentialsFile); err != nil {
			return nil, fmt.Errorf("FCM credentials file not found: %w", err)
		}
		opts = append(opts, option.WithCredentialsFile(cfg.CredentialsFile))
	}

	var fbCfg *firebase.Config
	if cfg.ProjectID != "" {
		fbCfg = &firebase.Config{ProjectID: cfg.ProjectID}
	}

	app, err := firebase.NewApp(ctx, fbCfg, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to init firebase app: %w", err)
	}

	client, err := app.Messaging(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to init firebase messaging client: %w", err)
	}

	return &FCMNotifier{client: client}, nil
}

func (f *FCMNotifier) Send(ctx context.Context, msg *NotificationMessage) error {
	if len(msg.Tokens) == 0 {
		return nil
	}

	// Prepare data map
	data := make(map[string]string)
	for k, v := range msg.Data {
		data[k] = v
	}
	data["category"] = msg.Category

	multicast := &messaging.MulticastMessage{
		Tokens: msg.Tokens,
		Notification: &messaging.Notification{
			Title: msg.Title,
			Body:  msg.Body,
		},
		Data: data,
		Android: &messaging.AndroidConfig{
			Priority:    "high",
			CollapseKey: msg.CollapseKey,
		},
	}

	if msg.CollapseKey != "" {
		multicast.APNS = &messaging.APNSConfig{
			Headers: map[string]string{
				"apns-collapse-id": msg.CollapseKey,
			},
		}
	}

	resp, err := f.client.SendEachForMulticast(ctx, multicast)
	if err != nil {
		log.Error().Err(err).Msg("Failed to send FCM multicast push")
		return err
	}

	log.Debug().
		Int("success_count", resp.SuccessCount).
		Int("failure_count", resp.FailureCount).
		Msg("FCM multicast push completed")

	return nil
}

// NewNotifier creates an appropriate PushNotifier based on config
func NewNotifier(ctx context.Context, cfg config.FCMConfig) PushNotifier {
	if cfg.Enabled && (cfg.CredentialsFile != "" || cfg.ProjectID != "") {
		client, err := NewFCMNotifier(ctx, cfg)
		if err == nil {
			log.Info().Msg("FCM Push Notifier initialized successfully")
			return client
		}
		log.Warn().Err(err).Msg("Failed to initialize FCM client; falling back to ConsolePushNotifier")
	}

	log.Info().Msg("Using ConsolePushNotifier for push notifications")
	return NewConsolePushNotifier()
}
