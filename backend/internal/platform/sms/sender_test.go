package sms_test

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/abshwabu/fikir/backend/internal/config"
	"github.com/abshwabu/fikir/backend/internal/platform/sms"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type mockSender struct {
	err error
}

func (m *mockSender) SendSMS(ctx context.Context, to string, message string) error {
	return m.err
}

func TestConsoleSender(t *testing.T) {
	sender := sms.NewConsoleSender()
	ctx := context.Background()

	err := sender.SendSMS(ctx, "+251911223344", "Your code is 123456")
	assert.NoError(t, err)

	err = sender.SendSMS(ctx, "", "code")
	assert.ErrorIs(t, err, sms.ErrEmptyRecipient)

	err = sender.SendSMS(ctx, "+251911223344", "")
	assert.ErrorIs(t, err, sms.ErrEmptyMessage)
}

func TestAfroMessageSender(t *testing.T) {
	ctx := context.Background()

	t.Run("success", func(t *testing.T) {
		ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			assert.Equal(t, "POST", r.Method)
			assert.Equal(t, "Bearer test-key", r.Header.Get("Authorization"))
			w.WriteHeader(http.StatusOK)
			_, _ = w.Write([]byte(`{"acknowledge":"success"}`))
		}))
		defer ts.Close()

		sender := sms.NewAfroMessageSender("test-key", "Fikir", ts.URL)
		err := sender.SendSMS(ctx, "+251911223344", "Code 123456")
		assert.NoError(t, err)
	})

	t.Run("server error", func(t *testing.T) {
		ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusInternalServerError)
			_, _ = w.Write([]byte(`{"error":"upstream down"}`))
		}))
		defer ts.Close()

		sender := sms.NewAfroMessageSender("test-key", "Fikir", ts.URL)
		err := sender.SendSMS(ctx, "+251911223344", "Code 123456")
		assert.Error(t, err)
	})
}

func TestFallbackSender(t *testing.T) {
	ctx := context.Background()

	t.Run("primary succeeds", func(t *testing.T) {
		primary := &mockSender{err: nil}
		fallback := &mockSender{err: errors.New("should not be called")}

		s := sms.NewFallbackSender(primary, fallback)
		err := s.SendSMS(ctx, "+251911223344", "test")
		assert.NoError(t, err)
	})

	t.Run("primary fails fallback succeeds", func(t *testing.T) {
		primary := &mockSender{err: errors.New("primary down")}
		fallback := &mockSender{err: nil}

		s := sms.NewFallbackSender(primary, fallback)
		err := s.SendSMS(ctx, "+251911223344", "test")
		assert.NoError(t, err)
	})

	t.Run("both fail", func(t *testing.T) {
		primary := &mockSender{err: errors.New("primary down")}
		fallback := &mockSender{err: errors.New("fallback down")}

		s := sms.NewFallbackSender(primary, fallback)
		err := s.SendSMS(ctx, "+251911223344", "test")
		assert.Error(t, err)
	})
}

func TestNewFromConfig(t *testing.T) {
	sender := sms.NewFromConfig(config.SMSConfig{Provider: "console"})
	require.NotNil(t, sender)
	err := sender.SendSMS(context.Background(), "+251911223344", "test")
	assert.NoError(t, err)
}
