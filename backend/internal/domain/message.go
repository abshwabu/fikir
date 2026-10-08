package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// Frame type constants for WebSocket protocol
const (
	FrameTypeMessageSend = "message.send"
	FrameTypeMessageNew  = "message.new"
	FrameTypeMessageAck  = "message.ack"
	FrameTypeTyping      = "typing"
	FrameTypeRead        = "read"
	FrameTypePresence    = "presence"
	FrameTypeMatchNew    = "match.new"
	FrameTypePing        = "ping"
	FrameTypePong        = "pong"
	FrameTypeError       = "error"
)

// Message types
const (
	MessageTypeText  = "text"
	MessageTypeImage = "image"
	MessageTypeVoice = "voice"
)

// Message represents a chat message between matched users
type Message struct {
	ID           int64          `json:"id"`
	MatchID      uuid.UUID      `json:"match_id"`
	SenderID     uuid.UUID      `json:"sender_id"`
	Body         string         `json:"body"`
	Type         string         `json:"type"`
	ClientMsgID  string         `json:"client_msg_id,omitempty"`
	MediaURL     string         `json:"media_url,omitempty"`
	Metadata     map[string]any `json:"metadata,omitempty"`
	WarningFlags []string       `json:"warning_flags,omitempty"`
	CreatedAt    time.Time      `json:"created_at"`
	ReadAt       *time.Time     `json:"read_at,omitempty"`
}

// WSFrame represents an envelope for WebSocket frames
type WSFrame struct {
	Type         string         `json:"type"`
	ClientMsgID  string         `json:"client_msg_id,omitempty"`
	MatchID      *uuid.UUID     `json:"match_id,omitempty"`
	SenderID     *uuid.UUID     `json:"sender_id,omitempty"`
	MessageID    int64          `json:"message_id,omitempty"`
	Body         string         `json:"body,omitempty"`
	MsgType      string         `json:"msg_type,omitempty"`
	MediaURL     string         `json:"media_url,omitempty"`
	UpToID       int64          `json:"up_to_id,omitempty"`
	IsTyping     bool           `json:"is_typing,omitempty"`
	Status       string         `json:"status,omitempty"`
	WarningFlags []string       `json:"warning_flags,omitempty"`
	Metadata     map[string]any `json:"metadata,omitempty"`
	CreatedAt    time.Time      `json:"created_at,omitempty"`
	Error        string         `json:"error,omitempty"`
	Payload      any            `json:"payload,omitempty"`
}

// NotificationSettings captures user push notification preferences
type NotificationSettings struct {
	NewMatch   bool `json:"new_match"`
	NewMessage bool `json:"new_message"`
	SuperLike  bool `json:"super_like"`
}

// DefaultNotificationSettings returns default active settings
func DefaultNotificationSettings() NotificationSettings {
	return NotificationSettings{
		NewMatch:   true,
		NewMessage: true,
		SuperLike:  true,
	}
}

// ChatRepository defines storage operations for messages and match relations
type ChatRepository interface {
	CreateMessage(ctx context.Context, msg *Message) error
	GetMessageByID(ctx context.Context, id int64) (*Message, error)
	GetMessageByClientMsgID(ctx context.Context, matchID uuid.UUID, clientMsgID string) (*Message, error)
	ListMessagesAfter(ctx context.Context, matchID uuid.UUID, afterID int64, limit int) ([]Message, error)
	ListMessagesBefore(ctx context.Context, matchID uuid.UUID, beforeID int64, limit int) ([]Message, error)
	MarkMessagesAsRead(ctx context.Context, matchID uuid.UUID, readerID uuid.UUID, upToID int64) error
	UpdateMatchLastMessageAt(ctx context.Context, matchID uuid.UUID, t time.Time) error
	GetMatchParticipants(ctx context.Context, matchID uuid.UUID) (userA, userB uuid.UUID, unmatchedAt *time.Time, err error)
}

// DeviceRepository defines storage operations for FCM devices
type DeviceRepository interface {
	UpsertDevice(ctx context.Context, userID uuid.UUID, fcmToken, platform string) error
	DeleteDevice(ctx context.Context, userID uuid.UUID, fcmToken string) error
	GetActiveDevicesForUser(ctx context.Context, userID uuid.UUID) ([]Device, error)
}

// NotificationRepository defines storage operations for user push preferences
type NotificationRepository interface {
	GetUserNotificationSettings(ctx context.Context, userID uuid.UUID) (*NotificationSettings, string, error)
	UpdateUserNotificationSettings(ctx context.Context, userID uuid.UUID, settings *NotificationSettings) error
}
