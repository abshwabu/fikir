package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// Message represents a chat message between matched users
type Message struct {
	ID        int64      `json:"id"`
	MatchID   uuid.UUID  `json:"match_id"`
	SenderID  uuid.UUID  `json:"sender_id"`
	Body      string     `json:"body"`
	Type      string     `json:"type"`
	MediaID   *uuid.UUID `json:"media_id,omitempty"`
	CreatedAt time.Time  `json:"created_at"`
	ReadAt    *time.Time `json:"read_at,omitempty"`
}

// MessageRepository defines chat message storage operations
type MessageRepository interface {
	SendMessage(ctx context.Context, msg *Message) error
	ListMessages(ctx context.Context, matchID uuid.UUID, limit int, beforeID int64) ([]Message, error)
	MarkRead(ctx context.Context, matchID uuid.UUID, readerID uuid.UUID) error
}
