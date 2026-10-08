package repository

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/abshwabu/fikir/backend/internal/domain"
)

type pgDiscoveryRepository struct {
	q          *Queries
	cdnBaseURL string
}

func NewDiscoveryRepository(q *Queries, cdnBaseURL ...string) domain.DiscoveryRepository {
	cdn := "http://localhost/media"
	if len(cdnBaseURL) > 0 && cdnBaseURL[0] != "" {
		cdn = cdnBaseURL[0]
	}
	return &pgDiscoveryRepository{
		q:          q,
		cdnBaseURL: strings.TrimRight(cdn, "/"),
	}
}

func (r *pgDiscoveryRepository) GetCandidates(ctx context.Context, params domain.DiscoveryParams) ([]domain.DiscoveryCandidate, error) {
	var myBirthdate pgtype.Date
	if !params.Birthdate.IsZero() {
		myBirthdate = pgtype.Date{Time: params.Birthdate, Valid: true}
	}

	interestedIn := params.InterestedIn
	if interestedIn == nil {
		interestedIn = []string{}
	}

	excluded := params.ExcludedIDs
	if excluded == nil {
		excluded = []uuid.UUID{}
	}

	rows, err := r.q.GetDiscoveryCandidates(ctx, GetDiscoveryCandidatesParams{
		MyLat:          params.Latitude,
		MyLng:          params.Longitude,
		UserID:         params.UserID,
		MyGender:       params.Gender,
		MyInterestedIn: interestedIn,
		MyBirthdate:    myBirthdate,
		AgeMin:         int32(params.AgeMin),
		AgeMax:         int32(params.AgeMax),
		RadiusMeters:   params.RadiusMeters,
		ExcludedIds:    excluded,
		ResultLimit:    int32(params.Limit),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to query discovery candidates: %w", err)
	}

	candidates := make([]domain.DiscoveryCandidate, len(rows))
	for i, row := range rows {
		var heightCm *int
		if row.HeightCm.Valid {
			h := int(row.HeightCm.Int32)
			heightCm = &h
		}

		var lat, lng *float64
		if l, ok := row.Latitude.(float64); ok {
			lat = &l
		}
		if l, ok := row.Longitude.(float64); ok {
			lng = &l
		}

		distKm := row.DistanceKm

		var boostUntil *time.Time
		if row.BoostUntil.Valid {
			boostUntil = &row.BoostUntil.Time
		}

		candidates[i] = domain.DiscoveryCandidate{
			UserID:            row.UserID,
			DisplayName:       row.DisplayName,
			Birthdate:         row.Birthdate.Time,
			Gender:            row.Gender,
			Bio:               row.Bio.String,
			JobTitle:          row.JobTitle.String,
			Education:         row.Education.String,
			HeightCm:          heightCm,
			Religion:          row.Religion.String,
			City:              row.City.String,
			Region:            row.Region.String,
			Latitude:          lat,
			Longitude:         lng,
			DistanceKm:        distKm,
			Verified:          row.Verified,
			CompletenessScore: int(row.CompletenessScore),
			LastActiveAt:      row.LastActiveAt.Time,
			BoostUntil:        boostUntil,
			Score:             row.Score,
		}
	}

	return candidates, nil
}

func (r *pgDiscoveryRepository) GetProfileCard(ctx context.Context, userID uuid.UUID, acceptHeader string) (*domain.ProfileCard, error) {
	row, err := r.q.GetProfileCardByUserID(ctx, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to fetch profile for card: %w", err)
	}

	interests, err := r.q.GetUserInterests(ctx, userID)
	if err != nil {
		interests = []string{}
	}

	photos, err := r.q.GetPhotosByUserID(ctx, userID)
	if err != nil {
		photos = []ProfilePhoto{}
	}

	cardPhotos := make([]domain.ProfileCardPhoto, 0, len(photos))
	for _, ph := range photos {
		if ph.Status != "approved" && len(photos) > 1 {
			continue
		}
		cardPhotos = append(cardPhotos, r.formatCardPhoto(ph, acceptHeader))
	}

	var heightCm *int
	if row.HeightCm.Valid {
		h := int(row.HeightCm.Int32)
		heightCm = &h
	}

	age := calculateAge(row.Birthdate.Time)

	return &domain.ProfileCard{
		UserID:            row.UserID,
		DisplayName:       row.DisplayName,
		Age:               age,
		Gender:            row.Gender,
		Bio:               row.Bio.String,
		JobTitle:          row.JobTitle.String,
		Education:         row.Education.String,
		HeightCm:          heightCm,
		Religion:          row.Religion.String,
		City:              row.City.String,
		Region:            row.Region.String,
		Verified:          row.Verified,
		CompletenessScore: int(row.CompletenessScore),
		Interests:         interests,
		Photos:            cardPhotos,
		LastActiveAt:      row.LastActiveAt.Time,
	}, nil
}

func (r *pgDiscoveryRepository) GetProfileCards(ctx context.Context, userIDs []uuid.UUID, acceptHeader string) (map[uuid.UUID]*domain.ProfileCard, error) {
	cards := make(map[uuid.UUID]*domain.ProfileCard, len(userIDs))
	for _, id := range userIDs {
		card, err := r.GetProfileCard(ctx, id, acceptHeader)
		if err != nil {
			return nil, err
		}
		if card != nil {
			cards[id] = card
		}
	}
	return cards, nil
}

func (r *pgDiscoveryRepository) formatCardPhoto(p ProfilePhoto, acceptHeader string) domain.ProfileCardPhoto {
	var variants map[string]any
	if len(p.Variants) > 0 {
		_ = json.Unmarshal(p.Variants, &variants)
	}

	var cardURL string
	if variants != nil {
		if cardData, ok := variants["card"].(map[string]any); ok {
			if strings.Contains(acceptHeader, "image/avif") {
				if avif, ok := cardData["avif"].(map[string]any); ok {
					if path, ok := avif["path"].(string); ok && path != "" {
						cardURL = r.qualifyURL(path)
					}
				}
			}
			if cardURL == "" {
				if webp, ok := cardData["webp"].(map[string]any); ok {
					if path, ok := webp["path"].(string); ok && path != "" {
						cardURL = r.qualifyURL(path)
					}
				}
			}
			if cardURL == "" {
				if jpeg, ok := cardData["jpeg"].(map[string]any); ok {
					if path, ok := jpeg["path"].(string); ok && path != "" {
						cardURL = r.qualifyURL(path)
					}
				}
			}
		}

		if cardURL == "" {
			if fullData, ok := variants["full"].(map[string]any); ok {
				if webp, ok := fullData["webp"].(map[string]any); ok {
					if path, ok := webp["path"].(string); ok && path != "" {
						cardURL = r.qualifyURL(path)
					}
				}
			}
		}
	}

	return domain.ProfileCardPhoto{
		ID:       p.ID,
		Position: int(p.Position),
		Blurhash: p.Blurhash.String,
		URL:      cardURL,
		Width:    int(p.Width.Int32),
		Height:   int(p.Height.Int32),
	}
}

func (r *pgDiscoveryRepository) qualifyURL(path string) string {
	if strings.HasPrefix(path, "http://") || strings.HasPrefix(path, "https://") {
		return path
	}
	return fmt.Sprintf("%s/%s", r.cdnBaseURL, strings.TrimPrefix(path, "/"))
}

func calculateAge(birthdate time.Time) int {
	if birthdate.IsZero() {
		return 18
	}
	now := time.Now()
	age := now.Year() - birthdate.Year()
	if now.YearDay() < birthdate.YearDay() {
		age--
	}
	if age < 0 {
		return 0
	}
	return age
}
