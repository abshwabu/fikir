package service

import (
	"context"

	"github.com/google/uuid"

	"github.com/abshwabu/fikir/backend/internal/domain"
)

// UserService defines user account business logic
type UserService interface {
	GetUser(ctx context.Context, id uuid.UUID) (*domain.User, error)
}

// MatchingService defines swiping and discovery business logic
type MatchingService interface {
	Swipe(ctx context.Context, swiperID uuid.UUID, targetID uuid.UUID, direction domain.SwipeDirection) (bool, *domain.Match, error)
}

// Container holds instantiated services
type Container struct {
	Auth     AuthService
	OTP      OTPService
	User     UserService
	Matching MatchingService
	Chat     ChatService
	Profile   ProfileService
	Media     MediaService
	Discovery DiscoveryService
	Swipe     SwipeService
}
