package repository

import (
	"context"
	"encoding/json"
	"errors"

	"github.com/abshwabu/fikir/backend/internal/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

type pgAuthRepository struct {
	q *Queries
}

func NewAuthRepository(q *Queries) domain.AuthRepository {
	return &pgAuthRepository{q: q}
}

func (r *pgAuthRepository) CreateRefreshToken(ctx context.Context, token *domain.RefreshToken) error {
	rt, err := r.q.CreateRefreshToken(ctx, CreateRefreshTokenParams{
		UserID:    token.UserID,
		TokenHash: token.TokenHash,
		FamilyID:  token.FamilyID,
		ExpiresAt: pgtype.Timestamptz{Time: token.ExpiresAt, Valid: true},
	})
	if err != nil {
		return err
	}
	token.ID = rt.ID
	token.CreatedAt = rt.CreatedAt.Time
	return nil
}

func (r *pgAuthRepository) GetRefreshTokenByHash(ctx context.Context, tokenHash string) (*domain.RefreshToken, error) {
	rt, err := r.q.GetRefreshTokenByHash(ctx, tokenHash)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &domain.RefreshToken{
		ID:        rt.ID,
		UserID:    rt.UserID,
		TokenHash: rt.TokenHash,
		FamilyID:  rt.FamilyID,
		IsRevoked: rt.IsRevoked,
		ExpiresAt: rt.ExpiresAt.Time,
		CreatedAt: rt.CreatedAt.Time,
	}, nil
}

func (r *pgAuthRepository) RevokeRefreshToken(ctx context.Context, id uuid.UUID) error {
	return r.q.RevokeRefreshToken(ctx, id)
}

func (r *pgAuthRepository) RevokeTokenFamily(ctx context.Context, familyID uuid.UUID) error {
	return r.q.RevokeTokenFamily(ctx, familyID)
}

func (r *pgAuthRepository) RevokeAllUserTokens(ctx context.Context, userID uuid.UUID) error {
	return r.q.RevokeAllUserTokens(ctx, userID)
}

func (r *pgAuthRepository) CreateAuditLog(ctx context.Context, log *domain.AuthAuditLog) error {
	var uid pgtype.UUID
	if log.UserID != nil {
		uid = pgtype.UUID{Bytes: *log.UserID, Valid: true}
	}

	metadataBytes := []byte("{}")
	if log.Metadata != nil {
		if b, err := json.Marshal(log.Metadata); err == nil {
			metadataBytes = b
		}
	}

	row, err := r.q.CreateAuthAuditLog(ctx, CreateAuthAuditLogParams{
		UserID:            uid,
		PhoneE164:         pgtype.Text{String: log.PhoneE164, Valid: log.PhoneE164 != ""},
		Event:             log.Event,
		IpAddress:         pgtype.Text{String: log.IPAddress, Valid: log.IPAddress != ""},
		UserAgent:         pgtype.Text{String: log.UserAgent, Valid: log.UserAgent != ""},
		DeviceFingerprint: pgtype.Text{String: log.DeviceFingerprint, Valid: log.DeviceFingerprint != ""},
		Metadata:          metadataBytes,
	})
	if err != nil {
		return err
	}
	log.ID = row.ID
	log.CreatedAt = row.CreatedAt.Time
	return nil
}

func (r *pgAuthRepository) UpsertDevice(ctx context.Context, device *domain.Device) error {
	d, err := r.q.UpsertDevice(ctx, UpsertDeviceParams{
		UserID:   device.UserID,
		FcmToken: device.FCMToken,
		Platform: device.Platform,
	})
	if err != nil {
		return err
	}
	device.ID = d.ID
	device.CreatedAt = d.CreatedAt.Time
	device.UpdatedAt = d.UpdatedAt.Time
	return nil
}
