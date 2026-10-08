package service_test

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/abshwabu/fikir/backend/internal/domain"
	paymentplatform "github.com/abshwabu/fikir/backend/internal/platform/payment"
	"github.com/abshwabu/fikir/backend/internal/platform/push"
	"github.com/abshwabu/fikir/backend/internal/service"
)

type mockPaymentRepo struct {
	plans         map[string]domain.SubscriptionPlan
	payments      map[string]*domain.Payment
	subscriptions map[uuid.UUID]*domain.Subscription
	remindersSent map[uuid.UUID]bool
}

func newMockPaymentRepo() *mockPaymentRepo {
	return &mockPaymentRepo{
		plans: map[string]domain.SubscriptionPlan{
			"gold_monthly": {
				ID:           "gold_monthly",
				Tier:         domain.TierGold,
				Name:         "Fikir Gold Monthly",
				DurationDays: 30,
				PriceETB:     499.00,
				IsActive:     true,
			},
		},
		payments:      make(map[string]*domain.Payment),
		subscriptions: make(map[uuid.UUID]*domain.Subscription),
		remindersSent: make(map[uuid.UUID]bool),
	}
}

func (m *mockPaymentRepo) GetPlans(ctx context.Context) ([]domain.SubscriptionPlan, error) {
	var list []domain.SubscriptionPlan
	for _, p := range m.plans {
		list = append(list, p)
	}
	return list, nil
}

func (m *mockPaymentRepo) GetPlanByID(ctx context.Context, id string) (*domain.SubscriptionPlan, error) {
	p, ok := m.plans[id]
	if !ok {
		return nil, nil
	}
	return &p, nil
}

func (m *mockPaymentRepo) CreatePayment(ctx context.Context, payment *domain.Payment) error {
	m.payments[payment.Reference] = payment
	return nil
}

func (m *mockPaymentRepo) GetPaymentByReference(ctx context.Context, reference string) (*domain.Payment, error) {
	p, ok := m.payments[reference]
	if !ok {
		return nil, nil
	}
	return p, nil
}

func (m *mockPaymentRepo) UpdatePaymentStatus(ctx context.Context, reference string, status domain.PaymentStatus, completedAt *time.Time, rawResponse map[string]any) error {
	p, ok := m.payments[reference]
	if !ok {
		return nil
	}
	p.Status = status
	p.CompletedAt = completedAt
	p.RawResponse = rawResponse
	return nil
}

func (m *mockPaymentRepo) GetActiveSubscription(ctx context.Context, userID uuid.UUID) (*domain.Subscription, error) {
	sub, ok := m.subscriptions[userID]
	if !ok {
		return nil, nil
	}
	if sub.ExpiresAt.Before(time.Now()) {
		return nil, nil
	}
	return sub, nil
}

func (m *mockPaymentRepo) UpsertSubscription(ctx context.Context, sub *domain.Subscription) error {
	m.subscriptions[sub.UserID] = sub
	return nil
}

func (m *mockPaymentRepo) ExpireSubscription(ctx context.Context, subID uuid.UUID) error {
	for _, s := range m.subscriptions {
		if s.ID == subID {
			s.Status = domain.SubscriptionStatusExpired
		}
	}
	return nil
}

func (m *mockPaymentRepo) GetPendingPaymentsOlderThan(ctx context.Context, age time.Duration) ([]domain.Payment, error) {
	return nil, nil
}

func (m *mockPaymentRepo) GetExpiringSubscriptions(ctx context.Context, within time.Duration) ([]domain.Subscription, error) {
	var list []domain.Subscription
	cutoff := time.Now().Add(within)
	for _, s := range m.subscriptions {
		if s.Status == domain.SubscriptionStatusActive && s.ExpiresAt.Before(cutoff) && !m.remindersSent[s.ID] {
			list = append(list, *s)
		}
	}
	return list, nil
}

func (m *mockPaymentRepo) MarkReminderSent(ctx context.Context, subID uuid.UUID) error {
	m.remindersSent[subID] = true
	return nil
}

func (m *mockPaymentRepo) GetPaymentsLedger(ctx context.Context, limit, offset int) ([]domain.Payment, int, error) {
	var list []domain.Payment
	for _, p := range m.payments {
		list = append(list, *p)
	}
	return list, len(list), nil
}

func (m *mockPaymentRepo) GetUserPayments(ctx context.Context, userID uuid.UUID) ([]domain.Payment, error) {
	var list []domain.Payment
	for _, p := range m.payments {
		if p.UserID == userID {
			list = append(list, *p)
		}
	}
	return list, nil
}

type mockPushNotifier struct {
	sent []*push.NotificationMessage
}

func (m *mockPushNotifier) Send(ctx context.Context, msg *push.NotificationMessage) error {
	m.sent = append(m.sent, msg)
	return nil
}

type mockDeviceRepo struct {
	devices map[uuid.UUID][]domain.Device
}

func (m *mockDeviceRepo) UpsertDevice(ctx context.Context, userID uuid.UUID, fcmToken, platform string) error {
	return nil
}

func (m *mockDeviceRepo) DeleteDevice(ctx context.Context, userID uuid.UUID, fcmToken string) error {
	return nil
}

func (m *mockDeviceRepo) GetActiveDevicesForUser(ctx context.Context, userID uuid.UUID) ([]domain.Device, error) {
	return m.devices[userID], nil
}

func TestChapaWebhook_SignatureAndActivation_Idempotency(t *testing.T) {
	secretKey := "test_secret_key_fikir_12345"
	webhookSecret := "test_webhook_secret_fikir_67890"

	repo := newMockPaymentRepo()
	notifier := &mockPushNotifier{}
	userID := uuid.New()
	deviceRepo := &mockDeviceRepo{
		devices: map[uuid.UUID][]domain.Device{
			userID: {{FCMToken: "test_token_123"}},
		},
	}

	chapaProv := paymentplatform.NewChapaProvider(paymentplatform.ChapaConfig{
		SecretKey:     secretKey,
		WebhookSecret: webhookSecret,
	})
	providers := map[string]paymentplatform.PaymentProvider{
		"chapa": chapaProv,
	}

	svc := service.NewPaymentService(repo, nil, deviceRepo, providers, notifier)
	ctx := context.Background()

	// 1. Create a pending payment
	txRef := "fikir_tx_test_001"
	planID := "gold_monthly"
	paymentRecord := &domain.Payment{
		ID:        uuid.New(),
		UserID:    userID,
		PlanID:    &planID,
		Provider:  "chapa",
		Reference: txRef,
		Amount:    499.00,
		Currency:  "ETB",
		Status:    domain.PaymentStatusPending,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, repo.CreatePayment(ctx, paymentRecord))

	// 2. Prepare valid webhook payload
	payloadMap := map[string]any{
		"event":          "charge.success",
		"tx_ref":         txRef,
		"amount":         499.00,
		"currency":       "ETB",
		"status":         "success",
		"payment_method": "telebirr",
	}
	rawPayload, err := json.Marshal(payloadMap)
	require.NoError(t, err)

	// Compute HMAC-SHA256 signature
	mac := hmac.New(sha256.New, []byte(webhookSecret))
	mac.Write(rawPayload)
	validSignature := hex.EncodeToString(mac.Sum(nil))

	// Case A: Invalid signature must fail
	err = svc.HandleWebhook(ctx, "chapa", rawPayload, "invalid_signature_hex")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "invalid webhook signature")

	// Case B: Valid signature activates subscription
	err = svc.HandleWebhook(ctx, "chapa", rawPayload, validSignature)
	require.NoError(t, err)

	// Verify payment status updated to success
	p, err := repo.GetPaymentByReference(ctx, txRef)
	require.NoError(t, err)
	assert.Equal(t, domain.PaymentStatusSuccess, p.Status)

	// Verify subscription created
	sub, err := repo.GetActiveSubscription(ctx, userID)
	require.NoError(t, err)
	require.NotNil(t, sub)
	assert.Equal(t, domain.TierGold, sub.Tier)
	assert.True(t, sub.IsActive())
	initialExpiresAt := sub.ExpiresAt

	// Verify push notification sent
	assert.Len(t, notifier.sent, 1)
	assert.Equal(t, "payment_success", notifier.sent[0].Category)

	// Case C: Replayed webhook (Idempotency) MUST NOT extend subscription expiration date again
	err = svc.HandleWebhook(ctx, "chapa", rawPayload, validSignature)
	require.NoError(t, err)

	subAfterReplay, err := repo.GetActiveSubscription(ctx, userID)
	require.NoError(t, err)
	require.NotNil(t, subAfterReplay)
	assert.Equal(t, initialExpiresAt, subAfterReplay.ExpiresAt, "replayed webhook must not extend duration further")
	assert.Len(t, notifier.sent, 1, "no duplicate push notification on replayed webhook")
}

func TestPaymentService_SubscriptionExpiryReminders(t *testing.T) {
	repo := newMockPaymentRepo()
	notifier := &mockPushNotifier{}
	userID := uuid.New()
	deviceRepo := &mockDeviceRepo{
		devices: map[uuid.UUID][]domain.Device{
			userID: {{FCMToken: "device_token_abc"}},
		},
	}

	svc := service.NewPaymentService(repo, nil, deviceRepo, nil, notifier)
	ctx := context.Background()

	// Subscription expiring in 24 hours (within 48 hours)
	planID := "gold_monthly"
	sub := &domain.Subscription{
		ID:        uuid.New(),
		UserID:    userID,
		Tier:      domain.TierGold,
		PlanID:    &planID,
		Status:    domain.SubscriptionStatusActive,
		StartsAt:  time.Now().AddDate(0, 0, -29),
		ExpiresAt: time.Now().Add(24 * time.Hour),
		CreatedAt: time.Now().AddDate(0, 0, -29),
	}
	require.NoError(t, repo.UpsertSubscription(ctx, sub))

	// Run reminder process
	count, err := svc.ProcessExpiringSubscriptions(ctx)
	require.NoError(t, err)
	assert.Equal(t, 1, count)

	// Check reminder sent
	assert.True(t, repo.remindersSent[sub.ID])
	assert.Len(t, notifier.sent, 1)
	assert.Equal(t, "subscription_expiry_reminder", notifier.sent[0].Category)

	// Running again should not re-remind
	count2, err := svc.ProcessExpiringSubscriptions(ctx)
	require.NoError(t, err)
	assert.Equal(t, 0, count2)
}
