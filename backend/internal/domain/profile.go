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

type Coordinates struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

// Profile represents a user's dating profile
type Profile struct {
	UserID            uuid.UUID      `json:"user_id"`
	DisplayName       string         `json:"display_name"`
	Birthdate         time.Time      `json:"birthdate"`
	Gender            string         `json:"gender"`
	InterestedIn      []string       `json:"interested_in"`
	Bio               string         `json:"bio,omitempty"`
	JobTitle          string         `json:"job_title,omitempty"`
	Education         string         `json:"education,omitempty"`
	HeightCm          *int           `json:"height_cm,omitempty"`
	Religion          string         `json:"religion,omitempty"`
	Languages         []string       `json:"languages"`
	City              string         `json:"city,omitempty"`
	Region            string         `json:"region,omitempty"`
	Location          *Coordinates   `json:"location,omitempty"`
	ShowMe            bool           `json:"show_me"`
	DistancePrefKm    int            `json:"distance_pref_km"`
	AgeMin            int            `json:"age_min"`
	AgeMax            int            `json:"age_max"`
	Verified          bool           `json:"verified"`
	CompletenessScore int            `json:"completeness_score"`
	Interests         []string       `json:"interests,omitempty"`
	Photos            []ProfilePhoto `json:"photos,omitempty"`
	CreatedAt         time.Time      `json:"created_at"`
	UpdatedAt         time.Time      `json:"updated_at"`
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

// Verification represents a pose-based selfie submitted for identity verification
type Verification struct {
	ID         uuid.UUID  `json:"id"`
	UserID     uuid.UUID  `json:"user_id"`
	PhotoURL   string     `json:"photo_url"`
	Pose       string     `json:"pose"`
	Status     string     `json:"status"`
	CreatedAt  time.Time  `json:"created_at"`
	ReviewedAt *time.Time `json:"reviewed_at,omitempty"`
}

// ProfileRepository defines database access for profiles, photos, and verifications
type ProfileRepository interface {
	GetByUserID(ctx context.Context, userID uuid.UUID) (*Profile, error)
	Upsert(ctx context.Context, profile *Profile) error
	UpdateInterests(ctx context.Context, userID uuid.UUID, interests []string) error
	GetUserInterests(ctx context.Context, userID uuid.UUID) ([]string, error)
	UpdateLocation(ctx context.Context, userID uuid.UUID, lat, lng float64, city, region string) error
	GetPhotos(ctx context.Context, userID uuid.UUID) ([]ProfilePhoto, error)
	GetPhotoByID(ctx context.Context, id uuid.UUID) (*ProfilePhoto, error)
	CreatePhoto(ctx context.Context, photo *ProfilePhoto) error
	UpdatePhoto(ctx context.Context, photo *ProfilePhoto) error
	DeletePhoto(ctx context.Context, id, userID uuid.UUID) error
	ReorderPhotos(ctx context.Context, userID uuid.UUID, photoIDs []uuid.UUID) error
	CountPhotos(ctx context.Context, userID uuid.UUID) (int, error)
	CreateVerification(ctx context.Context, v *Verification) error
}
