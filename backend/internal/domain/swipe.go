package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

type SwipeDirection string

const (
	SwipeDirectionLike  SwipeDirection = "like"
	SwipeDirectionNope  SwipeDirection = "nope"
	SwipeDirectionSuper SwipeDirection = "super"
)

// Swipe represents a directional swipe interaction
type Swipe struct {
	SwiperID  uuid.UUID      `json:"swiper_id"`
	TargetID  uuid.UUID      `json:"target_id"`
	Direction SwipeDirection `json:"direction"`
	CreatedAt time.Time      `json:"created_at"`
}

// Match represents a bidirectional match
type Match struct {
	ID          uuid.UUID  `json:"id"`
	UserA       uuid.UUID  `json:"user_a"`
	UserB       uuid.UUID  `json:"user_b"`
	CreatedAt   time.Time  `json:"created_at"`
	UnmatchedAt *time.Time `json:"unmatched_at,omitempty"`
}

// LastMessagePreview represents the snippet of the most recent message in a match
type LastMessagePreview struct {
	ID        int64     `json:"id"`
	SenderID  uuid.UUID `json:"sender_id"`
	Body      string    `json:"body"`
	Type      string    `json:"type"`
	CreatedAt time.Time `json:"created_at"`
}

// MatchWithPreview represents a match enriched with the other user's profile card and last message
type MatchWithPreview struct {
	ID          uuid.UUID           `json:"id"`
	UserA       uuid.UUID           `json:"user_a"`
	UserB       uuid.UUID           `json:"user_b"`
	CreatedAt   time.Time           `json:"created_at"`
	OtherUser   *ProfileCard        `json:"other_user"`
	LastMessage *LastMessagePreview `json:"last_message,omitempty"`
}

// LikesYouItem represents a user who liked the current user
type LikesYouItem struct {
	UserID    uuid.UUID    `json:"user_id"`
	Direction string       `json:"direction"`
	CreatedAt time.Time    `json:"created_at"`
	Profile   *ProfileCard `json:"profile,omitempty"`
}

// Block represents a block interaction
type Block struct {
	BlockerID uuid.UUID `json:"blocker_id"`
	BlockedID uuid.UUID `json:"blocked_id"`
	CreatedAt time.Time `json:"created_at"`
}

// Report represents a reported user
type Report struct {
	ID         uuid.UUID `json:"id"`
	ReporterID uuid.UUID `json:"reporter_id"`
	ReportedID uuid.UUID `json:"reported_id"`
	Reason     string    `json:"reason"`
	Details    string    `json:"details,omitempty"`
	Status     string    `json:"status"`
	CreatedAt  time.Time `json:"created_at"`
}

// SwipeRepository defines operations for swipes and match detection
type SwipeRepository interface {
	UpsertSwipe(ctx context.Context, swipe *Swipe) error
	DeleteSwipe(ctx context.Context, swiperID, targetID uuid.UUID) error
	GetSwipe(ctx context.Context, swiperID, targetID uuid.UUID) (*Swipe, error)
	CheckMutualLike(ctx context.Context, swiperID, targetID uuid.UUID) (bool, error)
	GetLikesYouList(ctx context.Context, userID uuid.UUID, limit int) ([]LikesYouItem, error)
	CountLikesYou(ctx context.Context, userID uuid.UUID) (int64, error)
}

// MatchRepository defines operations for matches
type MatchRepository interface {
	CreateMatch(ctx context.Context, userA, userB uuid.UUID) (*Match, error)
	GetByID(ctx context.Context, id uuid.UUID) (*Match, error)
	GetBetweenUsers(ctx context.Context, userA, userB uuid.UUID) (*Match, error)
	Unmatch(ctx context.Context, matchID, userID uuid.UUID) error
	ListForUser(ctx context.Context, userID uuid.UUID, limit int, cursorCreatedAt *time.Time) ([]MatchWithPreview, *time.Time, error)
}

// BlockRepository defines operations for blocks
type BlockRepository interface {
	CreateBlock(ctx context.Context, blockerID, blockedID uuid.UUID) error
	IsBlocked(ctx context.Context, userA, userB uuid.UUID) (bool, error)
}

// ReportRepository defines operations for reports
type ReportRepository interface {
	CreateReport(ctx context.Context, report *Report) error
}
