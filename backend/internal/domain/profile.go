package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

type PhotoStatus string

const (
	PhotoStatusPending  PhotoStatus = "pending"
	PhotoStatusApproved PhotoStatus = "approved"
	PhotoStatusRejected PhotoStatus = "rejected"
)

// Profile represents a user's dating profile
type Profile struct {
	UserID            uuid.UUID `json:"user_id"`
	DisplayName       string    `json:"display_name"`
	Birthdate         time.Time `json:"birthdate"`
	Gender            string    `json:"gender"`
	InterestedIn      []string  `json:"interested_in"`
	Bio               string    `json:"bio,omitempty"`
	JobTitle          string    `json:"job_title,omitempty"`
	Education         string    `json:"education,omitempty"`
	HeightCm          *int      `json:"height_cm,omitempty"`
	Religion          string    `json:"religion,omitempty"`
	Languages         []string  `json:"languages"`
	City              string    `json:"city,omitempty"`
	Region            string    `json:"region,omitempty"`
	Latitude          *float64  `json:"latitude,omitempty"`
	Longitude         *float64  `json:"longitude,omitempty"`
	ShowMe            bool      `json:"show_me"`
	DistancePrefKm    int       `json:"distance_pref_km"`
	AgeMin            int       `json:"age_min"`
	AgeMax            int       `json:"age_max"`
	Verified          bool      `json:"verified"`
	CompletenessScore int       `json:"completeness_score"`
	CreatedAt         time.Time `json:"created_at"`
	UpdatedAt         time.Time `json:"updated_at"`
}

// ProfilePhoto represents uploaded photos
type ProfilePhoto struct {
	ID        uuid.UUID      `json:"id"`
	UserID    uuid.UUID      `json:"user_id"`
	Position  int            `json:"position"`
	Blurhash  string         `json:"blurhash,omitempty"`
	Width     int            `json:"width"`
	Height    int            `json:"height"`
	Variants  map[string]any `json:"variants"`
	Status    PhotoStatus    `json:"status"`
	CreatedAt time.Time      `json:"created_at"`
}

// ProfileRepository defines database access for profiles
type ProfileRepository interface {
	GetByUserID(ctx context.Context, userID uuid.UUID) (*Profile, error)
	Upsert(ctx context.Context, profile *Profile) error
	GetPhotos(ctx context.Context, userID uuid.UUID) ([]ProfilePhoto, error)
}
