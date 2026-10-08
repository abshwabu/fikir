package repository

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/abshwabu/fikir/backend/internal/domain"
)

type pgChatRepository struct {
	q *Queries
}

func NewChatRepository(q *Queries) domain.ChatRepository {
	return &pgChatRepository{q: q}
}

func (r *pgChatRepository) CreateMessage(ctx context.Context, msg *domain.Message) error {
	metaJSON, err := json.Marshal(msg.Metadata)
	if err != nil {
		metaJSON = []byte("{}")
	}

	var clientMsgID pgtype.Text
	if msg.ClientMsgID != "" {
		clientMsgID = pgtype.Text{String: msg.ClientMsgID, Valid: true}
	}

	var mediaURL pgtype.Text
	if msg.MediaURL != "" {
		mediaURL = pgtype.Text{String: msg.MediaURL, Valid: true}
	}

	row, err := r.q.CreateMessage(ctx, CreateMessageParams{
		MatchID:     msg.MatchID,
		SenderID:    msg.SenderID,
		Body:        pgtype.Text{String: msg.Body, Valid: true},
		Type:        msg.Type,
		ClientMsgID: clientMsgID,
		MediaUrl:    mediaURL,
		Metadata:    metaJSON,
	})
	if err != nil {
		return fmt.Errorf("failed to insert message: %w", err)
	}

	msg.ID = row.ID
	msg.CreatedAt = row.CreatedAt.Time
	if row.ReadAt.Valid {
		msg.ReadAt = &row.ReadAt.Time
	}

	return nil
}

func (r *pgChatRepository) GetMessageByID(ctx context.Context, id int64) (*domain.Message, error) {
	row, err := r.q.GetMessageByID(ctx, id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return mapDBMessageToDomain(row), nil
}

func (r *pgChatRepository) GetMessageByClientMsgID(ctx context.Context, matchID uuid.UUID, clientMsgID string) (*domain.Message, error) {
	row, err := r.q.GetMessageByClientMsgID(ctx, GetMessageByClientMsgIDParams{
		MatchID:     matchID,
		ClientMsgID: pgtype.Text{String: clientMsgID, Valid: true},
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return mapDBMessageToDomain(row), nil
}

func (r *pgChatRepository) ListMessagesAfter(ctx context.Context, matchID uuid.UUID, afterID int64, limit int) ([]domain.Message, error) {
	if limit <= 0 {
		limit = 50
	}
	rows, err := r.q.ListMessagesAfter(ctx, ListMessagesAfterParams{
		MatchID: matchID,
		ID:      afterID,
		Limit:   int32(limit),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to list messages after: %w", err)
	}

	messages := make([]domain.Message, len(rows))
	for i, row := range rows {
		messages[i] = *mapDBMessageToDomain(row)
	}
	return messages, nil
}

func (r *pgChatRepository) ListMessagesBefore(ctx context.Context, matchID uuid.UUID, beforeID int64, limit int) ([]domain.Message, error) {
	if limit <= 0 {
		limit = 50
	}
	rows, err := r.q.ListMessagesBefore(ctx, ListMessagesBeforeParams{
		MatchID:     matchID,
		BeforeID:    beforeID,
		ResultLimit: int32(limit),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to list messages before: %w", err)
	}

	messages := make([]domain.Message, len(rows))
	for i, row := range rows {
		messages[i] = *mapDBMessageToDomain(row)
	}
	return messages, nil
}

func (r *pgChatRepository) MarkMessagesAsRead(ctx context.Context, matchID uuid.UUID, readerID uuid.UUID, upToID int64) error {
	return r.q.MarkMessagesAsRead(ctx, MarkMessagesAsReadParams{
		MatchID:  matchID,
		SenderID: readerID,
		ID:       upToID,
	})
}

func (r *pgChatRepository) UpdateMatchLastMessageAt(ctx context.Context, matchID uuid.UUID, t time.Time) error {
	return r.q.UpdateMatchLastMessageAt(ctx, UpdateMatchLastMessageAtParams{
		ID:            matchID,
		LastMessageAt: pgtype.Timestamptz{Time: t, Valid: true},
	})
}

func (r *pgChatRepository) GetMatchParticipants(ctx context.Context, matchID uuid.UUID) (userA, userB uuid.UUID, unmatchedAt *time.Time, err error) {
	row, err := r.q.GetMatchParticipants(ctx, matchID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return uuid.Nil, uuid.Nil, nil, nil
		}
		return uuid.Nil, uuid.Nil, nil, err
	}

	var un *time.Time
	if row.UnmatchedAt.Valid {
		un = &row.UnmatchedAt.Time
	}

	return row.UserA, row.UserB, un, nil
}

func mapDBMessageToDomain(row any) *domain.Message {
	switch m := row.(type) {
	case CreateMessageRow:
		return mapRow(m.ID, m.MatchID, m.SenderID, m.Body.String, m.Type, m.ClientMsgID.String, m.MediaUrl.String, m.Metadata, m.CreatedAt, m.ReadAt)
	case GetMessageByIDRow:
		return mapRow(m.ID, m.MatchID, m.SenderID, m.Body.String, m.Type, m.ClientMsgID.String, m.MediaUrl.String, m.Metadata, m.CreatedAt, m.ReadAt)
	case GetMessageByClientMsgIDRow:
		return mapRow(m.ID, m.MatchID, m.SenderID, m.Body.String, m.Type, m.ClientMsgID.String, m.MediaUrl.String, m.Metadata, m.CreatedAt, m.ReadAt)
	case ListMessagesAfterRow:
		return mapRow(m.ID, m.MatchID, m.SenderID, m.Body.String, m.Type, m.ClientMsgID.String, m.MediaUrl.String, m.Metadata, m.CreatedAt, m.ReadAt)
	case ListMessagesBeforeRow:
		return mapRow(m.ID, m.MatchID, m.SenderID, m.Body.String, m.Type, m.ClientMsgID.String, m.MediaUrl.String, m.Metadata, m.CreatedAt, m.ReadAt)
	default:
		return nil
	}
}

func mapRow(id int64, matchID, senderID uuid.UUID, body, msgType, clientMsgID, mediaURL string, rawMeta []byte, createdAt, readAt pgtype.Timestamptz) *domain.Message {
	var meta map[string]any
	if len(rawMeta) > 0 {
		_ = json.Unmarshal(rawMeta, &meta)
	}

	var warningFlags []string
	if meta != nil {
		if rawFlags, ok := meta["warning_flags"].([]any); ok {
			for _, f := range rawFlags {
				if s, ok := f.(string); ok {
					warningFlags = append(warningFlags, s)
				}
			}
		}
	}

	var rAt *time.Time
	if readAt.Valid {
		rAt = &readAt.Time
	}

	return &domain.Message{
		ID:           id,
		MatchID:      matchID,
		SenderID:     senderID,
		Body:         body,
		Type:         msgType,
		ClientMsgID:  clientMsgID,
		MediaURL:     mediaURL,
		Metadata:     meta,
		WarningFlags: warningFlags,
		CreatedAt:    createdAt.Time,
		ReadAt:       rAt,
	}
}

// -------------------------------------------------------------
// Device Repository
// -------------------------------------------------------------

type pgDeviceRepository struct {
	q *Queries
}

func NewDeviceRepository(q *Queries) domain.DeviceRepository {
	return &pgDeviceRepository{q: q}
}

func (r *pgDeviceRepository) UpsertDevice(ctx context.Context, userID uuid.UUID, fcmToken, platform string) error {
	_, err := r.q.UpsertDevice(ctx, UpsertDeviceParams{
		UserID:   userID,
		FcmToken: fcmToken,
		Platform: platform,
	})
	return err
}

func (r *pgDeviceRepository) DeleteDevice(ctx context.Context, userID uuid.UUID, fcmToken string) error {
	return r.q.DeleteDevice(ctx, DeleteDeviceParams{
		UserID:   userID,
		FcmToken: fcmToken,
	})
}

func (r *pgDeviceRepository) GetActiveDevicesForUser(ctx context.Context, userID uuid.UUID) ([]domain.Device, error) {
	rows, err := r.q.GetActiveDevicesForUser(ctx, userID)
	if err != nil {
		return nil, err
	}

	devices := make([]domain.Device, len(rows))
	for i, row := range rows {
		devices[i] = domain.Device{
			ID:        row.ID,
			UserID:    row.UserID,
			FCMToken:  row.FcmToken,
			Platform:  row.Platform,
			UpdatedAt: row.UpdatedAt.Time,
		}
	}
	return devices, nil
}

// -------------------------------------------------------------
// Notification Settings Repository
// -------------------------------------------------------------

type pgNotificationRepository struct {
	q *Queries
}

func NewNotificationRepository(q *Queries) domain.NotificationRepository {
	return &pgNotificationRepository{q: q}
}

func (r *pgNotificationRepository) GetUserNotificationSettings(ctx context.Context, userID uuid.UUID) (*domain.NotificationSettings, string, error) {
	row, err := r.q.GetUserNotificationSettings(ctx, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			def := domain.DefaultNotificationSettings()
			return &def, "en", nil
		}
		return nil, "", err
	}

	settings := domain.DefaultNotificationSettings()
	if len(row.NotificationSettings) > 0 {
		_ = json.Unmarshal(row.NotificationSettings, &settings)
	}

	return &settings, row.Locale, nil
}

func (r *pgNotificationRepository) UpdateUserNotificationSettings(ctx context.Context, userID uuid.UUID, settings *domain.NotificationSettings) error {
	bytes, err := json.Marshal(settings)
	if err != nil {
		return err
	}

	return r.q.UpdateUserNotificationSettings(ctx, UpdateUserNotificationSettingsParams{
		ID:                   userID,
		NotificationSettings: bytes,
	})
}
