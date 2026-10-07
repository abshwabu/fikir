package sms

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/abshwabu/fikir/backend/internal/config"
	"github.com/abshwabu/fikir/backend/internal/domain"
	"github.com/rs/zerolog/log"
)

var (
	ErrEmptyRecipient = errors.New("recipient phone number is required")
	ErrEmptyMessage   = errors.New("sms message body is required")
)

// ConsoleSender logs SMS messages to the console for local development and testing
type ConsoleSender struct{}

func NewConsoleSender() *ConsoleSender {
	return &ConsoleSender{}
}

func (s *ConsoleSender) SendSMS(ctx context.Context, to string, message string) error {
	if to == "" {
		return ErrEmptyRecipient
	}
	if message == "" {
		return ErrEmptyMessage
	}
	log.Info().
		Str("to", to).
		Str("sms_text", message).
		Msgf("[CONSOLE SMS] %s: %s", to, message)
	return nil
}

// AfroMessageSender integrates with the Ethiopian AfroMessage HTTP API
type AfroMessageSender struct {
	apiKey     string
	senderID   string
	baseURL    string
	httpClient *http.Client
}

type AfroMessagePayload struct {
	To      string `json:"to"`
	Message string `json:"message"`
	Sender  string `json:"sender,omitempty"`
}

type AfroMessageResponse struct {
	Acknowledge string `json:"acknowledge"`
	Response    struct {
		Status string `json:"status"`
	} `json:"response"`
}

func NewAfroMessageSender(apiKey, senderID, baseURL string) *AfroMessageSender {
	if baseURL == "" {
		baseURL = "https://api.afromessage.com/api/send"
	}
	return &AfroMessageSender{
		apiKey:   apiKey,
		senderID: senderID,
		baseURL:  baseURL,
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

func (s *AfroMessageSender) SendSMS(ctx context.Context, to string, message string) error {
	if to == "" {
		return ErrEmptyRecipient
	}
	if message == "" {
		return ErrEmptyMessage
	}

	payload := AfroMessagePayload{
		To:      to,
		Message: message,
		Sender:  s.senderID,
	}

	bodyBytes, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal AfroMessage payload: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, s.baseURL, bytes.NewReader(bodyBytes))
	if err != nil {
		return fmt.Errorf("failed to create AfroMessage request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	if s.apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+s.apiKey)
	}

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("AfroMessage request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("AfroMessage returned non-2xx status %d: %s", resp.StatusCode, string(respBody))
	}

	return nil
}

// FallbackSender tries a primary sender first and falls back to a secondary sender on error
type FallbackSender struct {
	primary  domain.SMSSender
	fallback domain.SMSSender
}

func NewFallbackSender(primary, fallback domain.SMSSender) *FallbackSender {
	return &FallbackSender{
		primary:  primary,
		fallback: fallback,
	}
}

func (s *FallbackSender) SendSMS(ctx context.Context, to string, message string) error {
	err := s.primary.SendSMS(ctx, to, message)
	if err == nil {
		return nil
	}

	log.Warn().
		Err(err).
		Str("to", to).
		Msg("Primary SMS sender failed; falling back to secondary sender")

	fallbackErr := s.fallback.SendSMS(ctx, to, message)
	if fallbackErr != nil {
		return fmt.Errorf("both primary and fallback SMS senders failed (primary: %v, fallback: %w)", err, fallbackErr)
	}

	return nil
}

// NewFromConfig builds a domain.SMSSender matching the provided configuration
func NewFromConfig(cfg config.SMSConfig) domain.SMSSender {
	console := NewConsoleSender()
	afro := NewAfroMessageSender(cfg.AfroMessageAPIKey, cfg.AfroMessageSenderID, cfg.AfroMessageBaseURL)

	switch cfg.Provider {
	case "afromessage":
		return afro
	case "fallback":
		return NewFallbackSender(afro, console)
	case "console":
		fallthrough
	default:
		return console
	}
}
