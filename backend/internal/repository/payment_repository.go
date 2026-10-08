package repository

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/abshwabu/fikir/backend/internal/domain"
)

type pgPaymentRepository struct {
	db DBTX
}

func NewPaymentRepository(db DBTX) domain.PaymentRepository {
	return &pgPaymentRepository{db: db}
}

func (r *pgPaymentRepository) GetPlans(ctx context.Context) ([]domain.SubscriptionPlan, error) {
	query := `
		SELECT id, tier, name, duration_days, price_etb, perks, is_active, created_at
		FROM subscription_plans
		WHERE is_active = true
		ORDER BY price_etb ASC
	`
	rows, err := r.db.Query(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var plans []domain.SubscriptionPlan
	for rows.Next() {
		var p domain.SubscriptionPlan
		var perksJSON []byte
		var tier string
		if err := rows.Scan(&p.ID, &tier, &p.Name, &p.DurationDays, &p.PriceETB, &perksJSON, &p.IsActive, &p.CreatedAt); err != nil {
			return nil, err
		}
		p.Tier = domain.SubscriptionTier(tier)
		if len(perksJSON) > 0 {
			_ = json.Unmarshal(perksJSON, &p.Perks)
		}
		plans = append(plans, p)
	}
	return plans, rows.Err()
}

func (r *pgPaymentRepository) GetPlanByID(ctx context.Context, id string) (*domain.SubscriptionPlan, error) {
	query := `
		SELECT id, tier, name, duration_days, price_etb, perks, is_active, created_at
		FROM subscription_plans
		WHERE id = $1
	`
	row := r.db.QueryRow(ctx, query, id)
	var p domain.SubscriptionPlan
	var perksJSON []byte
	var tier string
	if err := row.Scan(&p.ID, &tier, &p.Name, &p.DurationDays, &p.PriceETB, &perksJSON, &p.IsActive, &p.CreatedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	p.Tier = domain.SubscriptionTier(tier)
	if len(perksJSON) > 0 {
		_ = json.Unmarshal(perksJSON, &p.Perks)
	}
	return &p, nil
}

func (r *pgPaymentRepository) CreatePayment(ctx context.Context, payment *domain.Payment) error {
	query := `
		INSERT INTO payments (id, user_id, plan_id, provider, reference, amount, currency, status, payment_method, checkout_url, raw_response, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
	`
	var rawJSON []byte
	if payment.RawResponse != nil {
		rawJSON, _ = json.Marshal(payment.RawResponse)
	}

	_, err := r.db.Exec(ctx, query,
		payment.ID,
		payment.UserID,
		payment.PlanID,
		payment.Provider,
		payment.Reference,
		payment.Amount,
		payment.Currency,
		string(payment.Status),
		payment.PaymentMethod,
		payment.CheckoutURL,
		rawJSON,
		payment.CreatedAt,
		payment.UpdatedAt,
	)
	return err
}

func (r *pgPaymentRepository) GetPaymentByReference(ctx context.Context, reference string) (*domain.Payment, error) {
	query := `
		SELECT id, user_id, plan_id, provider, reference, amount, currency, status, payment_method, checkout_url, raw_response, created_at, updated_at, completed_at
		FROM payments
		WHERE reference = $1
	`
	row := r.db.QueryRow(ctx, query, reference)
	var p domain.Payment
	var status string
	var rawJSON []byte
	var completedAt pgtype.Timestamptz

	if err := row.Scan(
		&p.ID,
		&p.UserID,
		&p.PlanID,
		&p.Provider,
		&p.Reference,
		&p.Amount,
		&p.Currency,
		&status,
		&p.PaymentMethod,
		&p.CheckoutURL,
		&rawJSON,
		&p.CreatedAt,
		&p.UpdatedAt,
		&completedAt,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	p.Status = domain.PaymentStatus(status)
	if len(rawJSON) > 0 {
		_ = json.Unmarshal(rawJSON, &p.RawResponse)
	}
	if completedAt.Valid {
		p.CompletedAt = &completedAt.Time
	}
	return &p, nil
}

func (r *pgPaymentRepository) UpdatePaymentStatus(ctx context.Context, reference string, status domain.PaymentStatus, completedAt *time.Time, rawResponse map[string]any) error {
	query := `
		UPDATE payments
		SET status = $2, completed_at = $3, raw_response = COALESCE($4, raw_response), updated_at = NOW()
		WHERE reference = $1
	`
	var rawJSON []byte
	if rawResponse != nil {
		rawJSON, _ = json.Marshal(rawResponse)
	}
	var completedTs pgtype.Timestamptz
	if completedAt != nil {
		completedTs = pgtype.Timestamptz{Time: *completedAt, Valid: true}
	}

	_, err := r.db.Exec(ctx, query, reference, string(status), completedTs, rawJSON)
	return err
}

func (r *pgPaymentRepository) GetActiveSubscription(ctx context.Context, userID uuid.UUID) (*domain.Subscription, error) {
	query := `
		SELECT id, user_id, tier, plan_id, status, starts_at, expires_at, auto_renew, reminder_sent_at, created_at
		FROM subscriptions
		WHERE user_id = $1 AND status = 'active' AND expires_at > NOW()
		ORDER BY expires_at DESC
		LIMIT 1
	`
	row := r.db.QueryRow(ctx, query, userID)
	var sub domain.Subscription
	var tier, status string
	var reminderTs pgtype.Timestamptz

	if err := row.Scan(
		&sub.ID,
		&sub.UserID,
		&tier,
		&sub.PlanID,
		&status,
		&sub.StartsAt,
		&sub.ExpiresAt,
		&sub.AutoRenew,
		&reminderTs,
		&sub.CreatedAt,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	sub.Tier = domain.SubscriptionTier(tier)
	sub.Status = domain.SubscriptionStatus(status)
	if reminderTs.Valid {
		sub.ReminderSentAt = &reminderTs.Time
	}
	return &sub, nil
}

func (r *pgPaymentRepository) UpsertSubscription(ctx context.Context, sub *domain.Subscription) error {
	query := `
		INSERT INTO subscriptions (id, user_id, tier, plan_id, status, starts_at, expires_at, auto_renew, reminder_sent_at, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		ON CONFLICT (id) DO UPDATE SET
			tier = EXCLUDED.tier,
			plan_id = EXCLUDED.plan_id,
			status = EXCLUDED.status,
			starts_at = EXCLUDED.starts_at,
			expires_at = EXCLUDED.expires_at,
			auto_renew = EXCLUDED.auto_renew,
			reminder_sent_at = EXCLUDED.reminder_sent_at
	`
	var reminderTs pgtype.Timestamptz
	if sub.ReminderSentAt != nil {
		reminderTs = pgtype.Timestamptz{Time: *sub.ReminderSentAt, Valid: true}
	}

	_, err := r.db.Exec(ctx, query,
		sub.ID,
		sub.UserID,
		string(sub.Tier),
		sub.PlanID,
		string(sub.Status),
		sub.StartsAt,
		sub.ExpiresAt,
		sub.AutoRenew,
		reminderTs,
		sub.CreatedAt,
	)
	return err
}

func (r *pgPaymentRepository) ExpireSubscription(ctx context.Context, subID uuid.UUID) error {
	query := `UPDATE subscriptions SET status = 'expired' WHERE id = $1`
	_, err := r.db.Exec(ctx, query, subID)
	return err
}

func (r *pgPaymentRepository) GetPendingPaymentsOlderThan(ctx context.Context, age time.Duration) ([]domain.Payment, error) {
	query := `
		SELECT id, user_id, plan_id, provider, reference, amount, currency, status, payment_method, checkout_url, raw_response, created_at, updated_at, completed_at
		FROM payments
		WHERE status = 'pending' AND created_at < NOW() - ($1 * INTERVAL '1 second')
		ORDER BY created_at ASC
		LIMIT 100
	`
	seconds := int(age.Seconds())
	rows, err := r.db.Query(ctx, query, seconds)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []domain.Payment
	for rows.Next() {
		var p domain.Payment
		var status string
		var rawJSON []byte
		var completedAt pgtype.Timestamptz

		if err := rows.Scan(
			&p.ID,
			&p.UserID,
			&p.PlanID,
			&p.Provider,
			&p.Reference,
			&p.Amount,
			&p.Currency,
			&status,
			&p.PaymentMethod,
			&p.CheckoutURL,
			&rawJSON,
			&p.CreatedAt,
			&p.UpdatedAt,
			&completedAt,
		); err != nil {
			return nil, err
		}
		p.Status = domain.PaymentStatus(status)
		if len(rawJSON) > 0 {
			_ = json.Unmarshal(rawJSON, &p.RawResponse)
		}
		if completedAt.Valid {
			p.CompletedAt = &completedAt.Time
		}
		list = append(list, p)
	}
	return list, rows.Err()
}

func (r *pgPaymentRepository) GetExpiringSubscriptions(ctx context.Context, within time.Duration) ([]domain.Subscription, error) {
	query := `
		SELECT id, user_id, tier, plan_id, status, starts_at, expires_at, auto_renew, reminder_sent_at, created_at
		FROM subscriptions
		WHERE status = 'active'
		  AND reminder_sent_at IS NULL
		  AND expires_at <= NOW() + ($1 * INTERVAL '1 second')
		  AND expires_at > NOW()
		ORDER BY expires_at ASC
		LIMIT 200
	`
	seconds := int(within.Seconds())
	rows, err := r.db.Query(ctx, query, seconds)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []domain.Subscription
	for rows.Next() {
		var sub domain.Subscription
		var tier, status string
		var reminderTs pgtype.Timestamptz

		if err := rows.Scan(
			&sub.ID,
			&sub.UserID,
			&tier,
			&sub.PlanID,
			&status,
			&sub.StartsAt,
			&sub.ExpiresAt,
			&sub.AutoRenew,
			&reminderTs,
			&sub.CreatedAt,
		); err != nil {
			return nil, err
		}
		sub.Tier = domain.SubscriptionTier(tier)
		sub.Status = domain.SubscriptionStatus(status)
		if reminderTs.Valid {
			sub.ReminderSentAt = &reminderTs.Time
		}
		list = append(list, sub)
	}
	return list, rows.Err()
}

func (r *pgPaymentRepository) MarkReminderSent(ctx context.Context, subID uuid.UUID) error {
	query := `UPDATE subscriptions SET reminder_sent_at = NOW() WHERE id = $1`
	_, err := r.db.Exec(ctx, query, subID)
	return err
}

func (r *pgPaymentRepository) GetPaymentsLedger(ctx context.Context, limit, offset int) ([]domain.Payment, int, error) {
	countQuery := `SELECT COUNT(*) FROM payments`
	var total int
	if err := r.db.QueryRow(ctx, countQuery).Scan(&total); err != nil {
		return nil, 0, err
	}

	query := `
		SELECT id, user_id, plan_id, provider, reference, amount, currency, status, payment_method, checkout_url, raw_response, created_at, updated_at, completed_at
		FROM payments
		ORDER BY created_at DESC
		LIMIT $1 OFFSET $2
	`
	rows, err := r.db.Query(ctx, query, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var list []domain.Payment
	for rows.Next() {
		var p domain.Payment
		var status string
		var rawJSON []byte
		var completedAt pgtype.Timestamptz

		if err := rows.Scan(
			&p.ID,
			&p.UserID,
			&p.PlanID,
			&p.Provider,
			&p.Reference,
			&p.Amount,
			&p.Currency,
			&status,
			&p.PaymentMethod,
			&p.CheckoutURL,
			&rawJSON,
			&p.CreatedAt,
			&p.UpdatedAt,
			&completedAt,
		); err != nil {
			return nil, 0, err
		}
		p.Status = domain.PaymentStatus(status)
		if len(rawJSON) > 0 {
			_ = json.Unmarshal(rawJSON, &p.RawResponse)
		}
		if completedAt.Valid {
			p.CompletedAt = &completedAt.Time
		}
		list = append(list, p)
	}
	return list, total, rows.Err()
}

func (r *pgPaymentRepository) GetUserPayments(ctx context.Context, userID uuid.UUID) ([]domain.Payment, error) {
	query := `
		SELECT id, user_id, plan_id, provider, reference, amount, currency, status, payment_method, checkout_url, raw_response, created_at, updated_at, completed_at
		FROM payments
		WHERE user_id = $1
		ORDER BY created_at DESC
	`
	rows, err := r.db.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []domain.Payment
	for rows.Next() {
		var p domain.Payment
		var status string
		var rawJSON []byte
		var completedAt pgtype.Timestamptz

		if err := rows.Scan(
			&p.ID,
			&p.UserID,
			&p.PlanID,
			&p.Provider,
			&p.Reference,
			&p.Amount,
			&p.Currency,
			&status,
			&p.PaymentMethod,
			&p.CheckoutURL,
			&rawJSON,
			&p.CreatedAt,
			&p.UpdatedAt,
			&completedAt,
		); err != nil {
			return nil, err
		}
		p.Status = domain.PaymentStatus(status)
		if len(rawJSON) > 0 {
			_ = json.Unmarshal(rawJSON, &p.RawResponse)
		}
		if completedAt.Valid {
			p.CompletedAt = &completedAt.Time
		}
		list = append(list, p)
	}
	return list, rows.Err()
}
