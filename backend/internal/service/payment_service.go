package service

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	"github.com/abshwabu/fikir/backend/internal/domain"
	"github.com/abshwabu/fikir/backend/internal/platform/payment"
	"github.com/abshwabu/fikir/backend/internal/platform/push"
)

var (
	ErrPlanNotFound     = errors.New("subscription plan not found")
	ErrProviderNotFound = errors.New("payment provider not supported")
	ErrPaymentNotFound  = errors.New("payment not found")
)

type PaymentService interface {
	GetPlans(ctx context.Context) ([]domain.SubscriptionPlan, error)
	InitiateCheckout(ctx context.Context, userID uuid.UUID, planID, providerName, paymentMethod, returnURL, callbackURL string) (*domain.Payment, error)
	HandleWebhook(ctx context.Context, providerName string, rawBody []byte, signature string) error
	GetPaymentStatus(ctx context.Context, reference string) (*domain.Payment, error)
	GetUserSubscription(ctx context.Context, userID uuid.UUID) (*domain.Subscription, error)
	ReconcilePendingPayments(ctx context.Context) (int, error)
	ProcessExpiringSubscriptions(ctx context.Context) (int, error)
	GetPaymentsLedger(ctx context.Context, limit, offset int) ([]domain.Payment, int, error)
}

type paymentService struct {
	repo       domain.PaymentRepository
	userRepo   domain.UserRepository
	deviceRepo domain.DeviceRepository
	providers  map[string]payment.PaymentProvider
	notifier   push.PushNotifier
}

func NewPaymentService(
	repo domain.PaymentRepository,
	userRepo domain.UserRepository,
	deviceRepo domain.DeviceRepository,
	providers map[string]payment.PaymentProvider,
	notifier push.PushNotifier,
) PaymentService {
	return &paymentService{
		repo:       repo,
		userRepo:   userRepo,
		deviceRepo: deviceRepo,
		providers:  providers,
		notifier:   notifier,
	}
}

func (s *paymentService) GetPlans(ctx context.Context) ([]domain.SubscriptionPlan, error) {
	return s.repo.GetPlans(ctx)
}

func (s *paymentService) InitiateCheckout(
	ctx context.Context,
	userID uuid.UUID,
	planID, providerName, paymentMethod, returnURL, callbackURL string,
) (*domain.Payment, error) {
	plan, err := s.repo.GetPlanByID(ctx, planID)
	if err != nil {
		return nil, err
	}
	if plan == nil || !plan.IsActive {
		return nil, ErrPlanNotFound
	}

	if providerName == "" {
		providerName = "chapa"
	}
	prov, ok := s.providers[providerName]
	if !ok {
		return nil, ErrProviderNotFound
	}

	var userPhone string
	if s.userRepo != nil {
		user, err := s.userRepo.GetByID(ctx, userID)
		if err == nil && user != nil {
			userPhone = user.PhoneE164
		}
	}

	txRef := fmt.Sprintf("fikir_%d_%s", time.Now().Unix(), uuid.New().String()[:8])
	now := time.Now().UTC()

	chkReq := &payment.CheckoutRequest{
		TxRef:         txRef,
		UserID:        userID,
		UserPhone:     userPhone,
		Amount:        plan.PriceETB,
		Currency:      "ETB",
		Title:         plan.Name,
		Description:   fmt.Sprintf("Subscription to %s (%d days)", plan.Name, plan.DurationDays),
		CallbackURL:   callbackURL,
		ReturnURL:     returnURL,
		PaymentMethod: paymentMethod,
	}

	resp, err := prov.InitiateCheckout(ctx, chkReq)
	if err != nil {
		return nil, fmt.Errorf("checkout initiation failed: %w", err)
	}

	record := &domain.Payment{
		ID:            uuid.New(),
		UserID:        userID,
		PlanID:        &plan.ID,
		Provider:      prov.Name(),
		Reference:     txRef,
		Amount:        plan.PriceETB,
		Currency:      "ETB",
		Status:        domain.PaymentStatusPending,
		PaymentMethod: paymentMethod,
		CheckoutURL:   resp.CheckoutURL,
		CreatedAt:     now,
		UpdatedAt:     now,
	}

	if err := s.repo.CreatePayment(ctx, record); err != nil {
		return nil, fmt.Errorf("failed to persist payment record: %w", err)
	}

	return record, nil
}

func (s *paymentService) HandleWebhook(ctx context.Context, providerName string, rawBody []byte, signature string) error {
	prov, ok := s.providers[providerName]
	if !ok {
		return ErrProviderNotFound
	}

	payload, err := prov.VerifyWebhook(ctx, rawBody, signature)
	if err != nil {
		return fmt.Errorf("webhook verification failed: %w", err)
	}

	pay, err := s.repo.GetPaymentByReference(ctx, payload.TxRef)
	if err != nil {
		return err
	}
	if pay == nil {
		return ErrPaymentNotFound
	}

	// Idempotency check: if already completed successfully, return without re-extending
	if pay.Status == domain.PaymentStatusSuccess {
		log.Info().Str("tx_ref", payload.TxRef).Msg("Payment already processed; ignoring duplicate webhook")
		return nil
	}

	now := time.Now().UTC()

	if payload.Status == "success" {
		// Update payment
		if err := s.repo.UpdatePaymentStatus(ctx, payload.TxRef, domain.PaymentStatusSuccess, &now, payload.Raw); err != nil {
			return fmt.Errorf("failed to update payment status: %w", err)
		}

		// Activate/extend subscription
		if pay.PlanID != nil {
			if err := s.activateSubscription(ctx, pay.UserID, *pay.PlanID); err != nil {
				log.Error().Err(err).Str("user_id", pay.UserID.String()).Msg("Failed to activate subscription")
				return err
			}
		}

		// Send push notification
		s.notifyUserPaymentSuccess(ctx, pay.UserID, pay.PlanID)
	} else {
		_ = s.repo.UpdatePaymentStatus(ctx, payload.TxRef, domain.PaymentStatusFailed, &now, payload.Raw)
	}

	return nil
}

func (s *paymentService) activateSubscription(ctx context.Context, userID uuid.UUID, planID string) error {
	plan, err := s.repo.GetPlanByID(ctx, planID)
	if err != nil {
		return err
	}
	if plan == nil {
		return ErrPlanNotFound
	}

	existingSub, err := s.repo.GetActiveSubscription(ctx, userID)
	if err != nil {
		return err
	}

	now := time.Now().UTC()
	var sub *domain.Subscription

	if existingSub != nil && existingSub.ExpiresAt.After(now) {
		// Extend from existing expiration
		sub = existingSub
		sub.Tier = plan.Tier
		sub.PlanID = &plan.ID
		sub.Status = domain.SubscriptionStatusActive
		sub.ExpiresAt = existingSub.ExpiresAt.AddDate(0, 0, plan.DurationDays)
		sub.ReminderSentAt = nil
	} else {
		// Fresh subscription
		sub = &domain.Subscription{
			ID:        uuid.New(),
			UserID:    userID,
			Tier:      plan.Tier,
			PlanID:    &plan.ID,
			Status:    domain.SubscriptionStatusActive,
			StartsAt:  now,
			ExpiresAt: now.AddDate(0, 0, plan.DurationDays),
			AutoRenew: false,
			CreatedAt: now,
		}
	}

	return s.repo.UpsertSubscription(ctx, sub)
}

func (s *paymentService) notifyUserPaymentSuccess(ctx context.Context, userID uuid.UUID, planID *string) {
	if s.notifier == nil || s.deviceRepo == nil {
		return
	}

	devices, err := s.deviceRepo.GetActiveDevicesForUser(ctx, userID)
	if err != nil || len(devices) == 0 {
		return
	}

	tokens := make([]string, len(devices))
	for i, d := range devices {
		tokens[i] = d.FCMToken
	}

	planName := "Premium"
	if planID != nil {
		planName = strings.ReplaceAll(*planID, "_", " ")
	}

	msg := &push.NotificationMessage{
		Tokens:   tokens,
		Category: "payment_success",
		Title:    "🎉 Subscription Activated!",
		Body:     fmt.Sprintf("Your Fikir %s plan is now active. Enjoy unlimited likes & features!", planName),
		Data: map[string]string{
			"type": "payment_success",
		},
	}
	_ = s.notifier.Send(ctx, msg)
}

func (s *paymentService) GetPaymentStatus(ctx context.Context, reference string) (*domain.Payment, error) {
	return s.repo.GetPaymentByReference(ctx, reference)
}

func (s *paymentService) GetUserSubscription(ctx context.Context, userID uuid.UUID) (*domain.Subscription, error) {
	return s.repo.GetActiveSubscription(ctx, userID)
}

func (s *paymentService) ReconcilePendingPayments(ctx context.Context) (int, error) {
	pending, err := s.repo.GetPendingPaymentsOlderThan(ctx, 5*time.Minute)
	if err != nil {
		return 0, err
	}

	reconciled := 0
	for _, p := range pending {
		prov, ok := s.providers[p.Provider]
		if !ok {
			continue
		}

		status, err := prov.VerifyTransaction(ctx, p.Reference)
		if err != nil {
			log.Warn().Err(err).Str("reference", p.Reference).Msg("Reconciliation verify failed")
			continue
		}

		now := time.Now().UTC()
		if status.Status == "success" {
			_ = s.repo.UpdatePaymentStatus(ctx, p.Reference, domain.PaymentStatusSuccess, &now, status.Raw)
			if p.PlanID != nil {
				_ = s.activateSubscription(ctx, p.UserID, *p.PlanID)
			}
			s.notifyUserPaymentSuccess(ctx, p.UserID, p.PlanID)
			reconciled++
		} else if status.Status == "failed" {
			_ = s.repo.UpdatePaymentStatus(ctx, p.Reference, domain.PaymentStatusFailed, &now, status.Raw)
			reconciled++
		}
	}

	return reconciled, nil
}

func (s *paymentService) ProcessExpiringSubscriptions(ctx context.Context) (int, error) {
	// 1. Remind users whose subscriptions expire within 2 days
	expiring, err := s.repo.GetExpiringSubscriptions(ctx, 48*time.Hour)
	if err != nil {
		return 0, err
	}

	remindedCount := 0
	for _, sub := range expiring {
		if s.notifier != nil && s.deviceRepo != nil {
			devices, _ := s.deviceRepo.GetActiveDevicesForUser(ctx, sub.UserID)
			if len(devices) > 0 {
				tokens := make([]string, len(devices))
				for i, d := range devices {
					tokens[i] = d.FCMToken
				}
				_ = s.notifier.Send(ctx, &push.NotificationMessage{
					Tokens:   tokens,
					Category: "subscription_expiry_reminder",
					Title:    "⏳ Your subscription expires soon",
					Body:     "Your Fikir subscription will expire in 2 days. Renew to continue enjoying all premium perks!",
					Data: map[string]string{
						"type": "subscription_expiry_reminder",
					},
				})
			}
		}
		_ = s.repo.MarkReminderSent(ctx, sub.ID)
		remindedCount++
	}

	return remindedCount, nil
}

func (s *paymentService) GetPaymentsLedger(ctx context.Context, limit, offset int) ([]domain.Payment, int, error) {
	return s.repo.GetPaymentsLedger(ctx, limit, offset)
}
