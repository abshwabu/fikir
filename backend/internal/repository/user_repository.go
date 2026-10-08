package repository

import (
	"context"
	"errors"
	"time"

	"github.com/abshwabu/fikir/backend/internal/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

type pgUserRepository struct {
	q *Queries
}

func NewUserRepository(q *Queries) domain.UserRepository {
	return &pgUserRepository{q: q}
}

func (r *pgUserRepository) GetByID(ctx context.Context, id uuid.UUID) (*domain.User, error) {
	u, err := r.q.GetUserByID(ctx, id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return mapUserFields(u.ID, u.PhoneE164, u.Status, u.CreatedAt, u.LastActiveAt, u.IsPremium, u.PremiumUntil, u.Locale, u.DeletedAt, u.BoostUntil), nil
}

func (r *pgUserRepository) GetByPhone(ctx context.Context, phone string) (*domain.User, error) {
	u, err := r.q.GetUserByPhone(ctx, phone)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return mapUserFields(u.ID, u.PhoneE164, u.Status, u.CreatedAt, u.LastActiveAt, u.IsPremium, u.PremiumUntil, u.Locale, u.DeletedAt, u.BoostUntil), nil
}

func (r *pgUserRepository) Create(ctx context.Context, user *domain.User) error {
	u, err := r.q.CreateUser(ctx, CreateUserParams{
		PhoneE164: user.PhoneE164,
		Status:    string(user.Status),
		Locale:    user.Locale,
	})
	if err != nil {
		return err
	}
	created := mapUserFields(u.ID, u.PhoneE164, u.Status, u.CreatedAt, u.LastActiveAt, u.IsPremium, u.PremiumUntil, u.Locale, u.DeletedAt, u.BoostUntil)
	*user = *created
	return nil
}

func (r *pgUserRepository) UpdateLastActive(ctx context.Context, id uuid.UUID) error {
	return r.q.UpdateUserLastActive(ctx, id)
}

func (r *pgUserRepository) SoftDelete(ctx context.Context, id uuid.UUID) error {
	return r.q.SoftDeleteUser(ctx, id)
}

func (r *pgUserRepository) PurgeDeleted(ctx context.Context, before time.Time) (int64, error) {
	return r.q.PurgeDeletedUsers(ctx, pgtype.Timestamptz{Time: before, Valid: true})
}

func mapUserFields(id uuid.UUID, phone, status string, createdAt, lastActiveAt pgtype.Timestamptz, isPremium bool, premiumUntil pgtype.Timestamptz, locale string, deletedAt, boostUntil pgtype.Timestamptz) *domain.User {
	var pUntil *time.Time
	if premiumUntil.Valid {
		t := premiumUntil.Time
		pUntil = &t
	}
	var dAt *time.Time
	if deletedAt.Valid {
		t := deletedAt.Time
		dAt = &t
	}
	var bUntil *time.Time
	if boostUntil.Valid {
		t := boostUntil.Time
		bUntil = &t
	}
	return &domain.User{
		ID:           id,
		PhoneE164:    phone,
		Status:       domain.UserStatus(status),
		CreatedAt:    createdAt.Time,
		LastActiveAt: lastActiveAt.Time,
		IsPremium:    isPremium,
		PremiumUntil: pUntil,
		Locale:       locale,
		DeletedAt:    dAt,
		BoostUntil:   bUntil,
	}
}
