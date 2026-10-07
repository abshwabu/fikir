package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// RefreshToken represents a persisted refresh token for session rotation
type RefreshToken struct {
	ID        uuid.UUID `json:"id"`
	UserID    uuid.UUID `json:"user_id"`
	TokenHash string    `json:"token_hash"`
	FamilyID  uuid.UUID `json:"family_id"`
	IsRevoked bool      `json:"is_revoked"`
	ExpiresAt time.Time `json:"expires_at"`
	CreatedAt time.Time `json:"created_at"`
}

// AuthAuditLog tracks authentication lifecycle events for abuse detection
type AuthAuditLog struct {
	ID                int64                  `json:"id"`
	UserID            *uuid.UUID             `json:"user_id,omitempty"`
	PhoneE164         string                 `json:"phone_e164"`
	Event             string                 `json:"event"`
	IPAddress         string                 `json:"ip_address"`
	UserAgent         string                 `json:"user_agent"`
	DeviceFingerprint string                 `json:"device_fingerprint"`
	Metadata          map[string]interface{} `json:"metadata"`
	CreatedAt         time.Time              `json:"created_at"`
}

// Device represents a user device for push notifications
type Device struct {
	ID        uuid.UUID `json:"id"`
	UserID    uuid.UUID `json:"user_id"`
	FCMToken  string    `json:"fcm_token"`
	Platform  string    `json:"platform"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// AuthRepository defines persistence for tokens, audit logs, and devices
type AuthRepository interface {
	CreateRefreshToken(ctx context.Context, token *RefreshToken) error
	GetRefreshTokenByHash(ctx context.Context, tokenHash string) (*RefreshToken, error)
	RevokeRefreshToken(ctx context.Context, id uuid.UUID) error
	RevokeTokenFamily(ctx context.Context, familyID uuid.UUID) error
	RevokeAllUserTokens(ctx context.Context, userID uuid.UUID) error
	CreateAuditLog(ctx context.Context, log *AuthAuditLog) error
	UpsertDevice(ctx context.Context, device *Device) error
}

// SMSSender defines the SMS dispatch interface
type SMSSender interface {
	SendSMS(ctx context.Context, to string, message string) error
}
