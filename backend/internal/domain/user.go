package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

type UserStatus string

const (
	UserStatusActive    UserStatus = "active"
	UserStatusSuspended UserStatus = "suspended"
	UserStatusDeleted   UserStatus = "deleted"
	UserStatusBanned    UserStatus = "banned"
)

// User represents the core account entity
type User struct {
	ID           uuid.UUID  `json:"id"`
	PhoneE164    string     `json:"phone_e164"`
	Status       UserStatus `json:"status"`
	CreatedAt    time.Time  `json:"created_at"`
	LastActiveAt time.Time  `json:"last_active_at"`
	IsPremium    bool       `json:"is_premium"`
	PremiumUntil *time.Time `json:"premium_until,omitempty"`
	Locale       string     `json:"locale"`
	DeletedAt    *time.Time `json:"deleted_at,omitempty"`
}

// UserRepository defines persistent operations on Users
type UserRepository interface {
	GetByID(ctx context.Context, id uuid.UUID) (*User, error)
	GetByPhone(ctx context.Context, phone string) (*User, error)
	Create(ctx context.Context, user *User) error
	UpdateLastActive(ctx context.Context, id uuid.UUID) error
	SoftDelete(ctx context.Context, id uuid.UUID) error
	PurgeDeleted(ctx context.Context, before time.Time) (int64, error)
}
