package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// ProfileCardPhoto represents a card-optimized photo
type ProfileCardPhoto struct {
	ID       uuid.UUID `json:"id"`
	Position int       `json:"position"`
	Blurhash string    `json:"blurhash"`
	URL      string    `json:"url"`
	Width    int       `json:"width"`
	Height   int       `json:"height"`
}

// ProfileCard represents a lightweight dating card rendered on discovery and match feeds
type ProfileCard struct {
	UserID            uuid.UUID          `json:"user_id"`
	DisplayName       string             `json:"display_name"`
	Age               int                `json:"age"`
	Gender            string             `json:"gender"`
	Bio               string             `json:"bio,omitempty"`
	JobTitle          string             `json:"job_title,omitempty"`
	Education         string             `json:"education,omitempty"`
	HeightCm          *int               `json:"height_cm,omitempty"`
	Religion          string             `json:"religion,omitempty"`
	City              string             `json:"city,omitempty"`
	Region            string             `json:"region,omitempty"`
	DistanceKm        float64            `json:"distance_km"`
	Verified          bool               `json:"verified"`
	CompletenessScore int                `json:"completeness_score"`
	Interests         []string           `json:"interests"`
	Photos            []ProfileCardPhoto `json:"photos"`
	LastActiveAt      time.Time          `json:"last_active_at"`
	BoostUntil        *time.Time         `json:"boost_until,omitempty"`
}

// DiscoveryParams holds candidate selection parameters
type DiscoveryParams struct {
	UserID         uuid.UUID
	Gender         string
	InterestedIn   []string
	Birthdate      time.Time
	AgeMin         int
	AgeMax         int
	Latitude       float64
	Longitude      float64
	RadiusMeters   float64
	ExcludedIDs    []uuid.UUID
	Limit          int
}

// DiscoveryCandidate represents a raw discovery candidate before photo hydration
type DiscoveryCandidate struct {
	UserID            uuid.UUID
	DisplayName       string
	Birthdate         time.Time
	Gender            string
	Bio               string
	JobTitle          string
	Education         string
	HeightCm          *int
	Religion          string
	City              string
	Region            string
	Latitude          *float64
	Longitude         *float64
	DistanceKm        float64
	Verified          bool
	CompletenessScore int
	LastActiveAt      time.Time
	BoostUntil        *time.Time
	Score             float64
}

// DiscoveryRepository defines methods for querying discovery candidates
type DiscoveryRepository interface {
	GetCandidates(ctx context.Context, params DiscoveryParams) ([]DiscoveryCandidate, error)
	GetProfileCards(ctx context.Context, userIDs []uuid.UUID, acceptHeader string) (map[uuid.UUID]*ProfileCard, error)
	GetProfileCard(ctx context.Context, userID uuid.UUID, acceptHeader string) (*ProfileCard, error)
}
