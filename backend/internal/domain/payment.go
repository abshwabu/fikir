package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

type SubscriptionTier string

const (
	TierPlus SubscriptionTier = "plus"
	TierGold SubscriptionTier = "gold"
)

type SubscriptionStatus string

const (
	SubscriptionStatusActive    SubscriptionStatus = "active"
	SubscriptionStatusExpired   SubscriptionStatus = "expired"
	SubscriptionStatusCancelled SubscriptionStatus = "cancelled"
)

type PaymentStatus string

const (
	PaymentStatusPending   PaymentStatus = "pending"
	PaymentStatusSuccess   PaymentStatus = "success"
	PaymentStatusFailed    PaymentStatus = "failed"
	PaymentStatusRefunded  PaymentStatus = "refunded"
)

// SubscriptionPlan represents a tier offering with pricing in ETB
type SubscriptionPlan struct {
	ID           string           `json:"id"`
	Tier         SubscriptionTier `json:"tier"`
	Name         string           `json:"name"`
	DurationDays int              `json:"duration_days"`
	PriceETB     float64          `json:"price_etb"`
	Perks        []string         `json:"perks"`
	IsActive     bool             `json:"is_active"`
	CreatedAt    time.Time        `json:"created_at"`
}

// Subscription represents an active or past user entitlement
type Subscription struct {
	ID             uuid.UUID          `json:"id"`
	UserID         uuid.UUID          `json:"user_id"`
	Tier           SubscriptionTier   `json:"tier"`
	PlanID         *string            `json:"plan_id,omitempty"`
	Status         SubscriptionStatus `json:"status"`
	StartsAt       time.Time          `json:"starts_at"`
	ExpiresAt      time.Time          `json:"expires_at"`
	AutoRenew      bool               `json:"auto_renew"`
	ReminderSentAt *time.Time         `json:"reminder_sent_at,omitempty"`
	CreatedAt      time.Time          `json:"created_at"`
}

func (s *Subscription) IsActive() bool {
	return s.Status == SubscriptionStatusActive && time.Now().Before(s.ExpiresAt)
}

// Payment represents a transaction record in the ledger
type Payment struct {
	ID            uuid.UUID     `json:"id"`
	UserID        uuid.UUID     `json:"user_id"`
	PlanID        *string       `json:"plan_id,omitempty"`
	Provider      string        `json:"provider"` // "chapa", "telebirr", "cbe_birr", "google_play"
	Reference     string        `json:"reference"`
	Amount        float64       `json:"amount"`
	Currency      string        `json:"currency"`
	Status        PaymentStatus `json:"status"`
	PaymentMethod string        `json:"payment_method"`
	CheckoutURL   string        `json:"checkout_url,omitempty"`
	RawResponse   map[string]any `json:"raw_response,omitempty"`
	CreatedAt     time.Time     `json:"created_at"`
	UpdatedAt     time.Time     `json:"updated_at"`
	CompletedAt   *time.Time    `json:"completed_at,omitempty"`
}

// PaymentRepository defines database operations for plans, payments, and subscriptions
type PaymentRepository interface {
	GetPlans(ctx context.Context) ([]SubscriptionPlan, error)
	GetPlanByID(ctx context.Context, id string) (*SubscriptionPlan, error)
	CreatePayment(ctx context.Context, payment *Payment) error
	GetPaymentByReference(ctx context.Context, reference string) (*Payment, error)
	UpdatePaymentStatus(ctx context.Context, reference string, status PaymentStatus, completedAt *time.Time, rawResponse map[string]any) error
	GetActiveSubscription(ctx context.Context, userID uuid.UUID) (*Subscription, error)
	UpsertSubscription(ctx context.Context, sub *Subscription) error
	ExpireSubscription(ctx context.Context, subID uuid.UUID) error
	GetPendingPaymentsOlderThan(ctx context.Context, age time.Duration) ([]Payment, error)
	GetExpiringSubscriptions(ctx context.Context, within time.Duration) ([]Subscription, error)
	MarkReminderSent(ctx context.Context, subID uuid.UUID) error
	GetPaymentsLedger(ctx context.Context, limit, offset int) ([]Payment, int, error)
	GetUserPayments(ctx context.Context, userID uuid.UUID) ([]Payment, error)
}
