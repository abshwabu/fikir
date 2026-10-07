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

// SwipeRepository defines operations for swipes and match detection
type SwipeRepository interface {
	RecordSwipe(ctx context.Context, swipe *Swipe) (isMatch bool, match *Match, err error)
}

// MatchRepository defines operations for matches
type MatchRepository interface {
	GetByID(ctx context.Context, id uuid.UUID) (*Match, error)
	ListForUser(ctx context.Context, userID uuid.UUID, limit int, cursor string) ([]Match, string, error)
}
