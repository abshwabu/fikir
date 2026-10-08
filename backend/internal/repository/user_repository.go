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
	return mapDBUserToDomain(u), nil
}

func (r *pgUserRepository) GetByPhone(ctx context.Context, phone string) (*domain.User, error) {
	u, err := r.q.GetUserByPhone(ctx, phone)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return mapDBUserToDomain(u), nil
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
	created := mapDBUserToDomain(u)
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

func mapDBUserToDomain(u User) *domain.User {
	var premiumUntil *time.Time
	if u.PremiumUntil.Valid {
		t := u.PremiumUntil.Time
		premiumUntil = &t
	}
	var deletedAt *time.Time
	if u.DeletedAt.Valid {
		t := u.DeletedAt.Time
		deletedAt = &t
	}
	var boostUntil *time.Time
	if u.BoostUntil.Valid {
		t := u.BoostUntil.Time
		boostUntil = &t
	}
	return &domain.User{
		ID:           u.ID,
		PhoneE164:    u.PhoneE164,
		Status:       domain.UserStatus(u.Status),
		CreatedAt:    u.CreatedAt.Time,
		LastActiveAt: u.LastActiveAt.Time,
		IsPremium:    u.IsPremium,
		PremiumUntil: premiumUntil,
		Locale:       u.Locale,
		DeletedAt:    deletedAt,
		BoostUntil:   boostUntil,
	}
}
