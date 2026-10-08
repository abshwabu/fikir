package service

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/abshwabu/fikir/backend/internal/cache"
	"github.com/abshwabu/fikir/backend/internal/domain"
	apperrors "github.com/abshwabu/fikir/backend/internal/platform/errors"
	"github.com/abshwabu/fikir/backend/internal/platform/ethiopia"
)

type UpdateProfileRequest struct {
	DisplayName    *string   `json:"display_name,omitempty"`
	Birthdate      *string   `json:"birthdate,omitempty"` // YYYY-MM-DD
	Gender         *string   `json:"gender,omitempty"`
	InterestedIn   []string  `json:"interested_in,omitempty"`
	Bio            *string   `json:"bio,omitempty"`
	JobTitle       *string   `json:"job_title,omitempty"`
	Education      *string   `json:"education,omitempty"`
	HeightCm       *int      `json:"height_cm,omitempty"`
	Religion       *string   `json:"religion,omitempty"`
	Languages      []string  `json:"languages,omitempty"`
	City           *string   `json:"city,omitempty"`
	ShowMe         *bool     `json:"show_me,omitempty"`
	DistancePrefKm *int      `json:"distance_pref_km,omitempty"`
	AgeMin         *int      `json:"age_min,omitempty"`
	AgeMax         *int      `json:"age_max,omitempty"`
}

type UpdateLocationRequest struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
	City      string  `json:"city"`
}

type ProfileService interface {
	GetProfile(ctx context.Context, userID uuid.UUID) (*domain.Profile, error)
	UpdateProfile(ctx context.Context, userID uuid.UUID, req UpdateProfileRequest) (*domain.Profile, error)
	UpdateInterests(ctx context.Context, userID uuid.UUID, interests []string) ([]string, error)
	UpdateLocation(ctx context.Context, userID uuid.UUID, req UpdateLocationRequest) (*domain.Profile, error)
	SubmitVerification(ctx context.Context, userID uuid.UUID, photoURL, pose string) (*domain.Verification, error)
}

type profileService struct {
	profileRepo  domain.ProfileRepository
	mediaService MediaService
	cardCache    cache.ProfileCardCache
}

func NewProfileService(profileRepo domain.ProfileRepository, mediaService MediaService, cardCache ...cache.ProfileCardCache) ProfileService {
	var cc cache.ProfileCardCache
	if len(cardCache) > 0 {
		cc = cardCache[0]
	}
	return &profileService{
		profileRepo:  profileRepo,
		mediaService: mediaService,
		cardCache:    cc,
	}
}

func (s *profileService) GetProfile(ctx context.Context, userID uuid.UUID) (*domain.Profile, error) {
	p, err := s.profileRepo.GetByUserID(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch profile: %w", err)
	}
	if p == nil {
		return nil, apperrors.NotFound("profile not found")
	}

	interests, _ := s.profileRepo.GetUserInterests(ctx, userID)
	p.Interests = interests

	photos, _ := s.profileRepo.GetPhotos(ctx, userID)
	p.Photos = photos

	return p, nil
}

func (s *profileService) UpdateProfile(ctx context.Context, userID uuid.UUID, req UpdateProfileRequest) (*domain.Profile, error) {
	existing, err := s.profileRepo.GetByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}

	if existing == nil {
		existing = &domain.Profile{
			UserID:         userID,
			ShowMe:         true,
			DistancePrefKm: 50,
			AgeMin:         18,
			AgeMax:         100,
		}
	}

	if req.DisplayName != nil {
		existing.DisplayName = *req.DisplayName
	}

	if req.Birthdate != nil {
		t, err := time.Parse("2006-01-02", *req.Birthdate)
		if err != nil {
			return nil, apperrors.BadRequest("Invalid birthdate format; expected YYYY-MM-DD")
		}
		if err := ethiopia.ValidateAge18(t); err != nil {
			return nil, apperrors.BadRequest("You must be at least 18 years old")
		}
		existing.Birthdate = t
	}

	if req.Gender != nil {
		existing.Gender = *req.Gender
	}
	if req.InterestedIn != nil {
		existing.InterestedIn = req.InterestedIn
	}
	if req.Bio != nil {
		existing.Bio = *req.Bio
	}
	if req.JobTitle != nil {
		existing.JobTitle = *req.JobTitle
	}
	if req.Education != nil {
		existing.Education = *req.Education
	}
	if req.HeightCm != nil {
		existing.HeightCm = req.HeightCm
	}
	if req.Religion != nil {
		existing.Religion = *req.Religion
	}
	if req.Languages != nil {
		existing.Languages = req.Languages
	}
	if req.City != nil {
		city, region := ethiopia.ResolveRegion(*req.City)
		existing.City = city
		existing.Region = region
	}
	if req.ShowMe != nil {
		existing.ShowMe = *req.ShowMe
	}
	if req.DistancePrefKm != nil {
		existing.DistancePrefKm = *req.DistancePrefKm
	}
	if req.AgeMin != nil {
		existing.AgeMin = *req.AgeMin
	}
	if req.AgeMax != nil {
		existing.AgeMax = *req.AgeMax
	}

	// Count approved photos for completeness score
	photoCount, _ := s.profileRepo.CountPhotos(ctx, userID)
	existing.CompletenessScore = ethiopia.CalculateCompletenessScore(existing, photoCount)

	// Rule: minimum 1 photo to be discoverable
	if photoCount == 0 {
		existing.ShowMe = false
	}

	if err := s.profileRepo.Upsert(ctx, existing); err != nil {
		return nil, fmt.Errorf("failed to save profile: %w", err)
	}

	if s.cardCache != nil {
		_ = s.cardCache.Invalidate(ctx, userID)
	}

	return s.GetProfile(ctx, userID)
}

func (s *profileService) UpdateInterests(ctx context.Context, userID uuid.UUID, interests []string) ([]string, error) {
	if err := s.profileRepo.UpdateInterests(ctx, userID, interests); err != nil {
		return nil, fmt.Errorf("failed to update interests: %w", err)
	}
	if s.cardCache != nil {
		_ = s.cardCache.Invalidate(ctx, userID)
	}
	return s.profileRepo.GetUserInterests(ctx, userID)
}

func (s *profileService) UpdateLocation(ctx context.Context, userID uuid.UUID, req UpdateLocationRequest) (*domain.Profile, error) {
	city, region := ethiopia.ResolveRegion(req.City)
	if err := s.profileRepo.UpdateLocation(ctx, userID, req.Latitude, req.Longitude, city, region); err != nil {
		return nil, fmt.Errorf("failed to update location: %w", err)
	}
	if s.cardCache != nil {
		_ = s.cardCache.Invalidate(ctx, userID)
	}

	return s.GetProfile(ctx, userID)
}

func (s *profileService) SubmitVerification(ctx context.Context, userID uuid.UUID, photoURL, pose string) (*domain.Verification, error) {
	if photoURL == "" || pose == "" {
		return nil, apperrors.BadRequest("selfie photo_url and pose are required")
	}

	v := &domain.Verification{
		ID:        uuid.New(),
		UserID:    userID,
		PhotoURL:  photoURL,
		Pose:      pose,
		Status:    "pending",
		CreatedAt: time.Now(),
	}

	if err := s.profileRepo.CreateVerification(ctx, v); err != nil {
		return nil, fmt.Errorf("failed to submit verification: %w", err)
	}

	return v, nil
}
