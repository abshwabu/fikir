package repository

import (
	"context"
	"encoding/json"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/abshwabu/fikir/backend/internal/domain"
)

type pgProfileRepository struct {
	q *Queries
}

func NewProfileRepository(q *Queries) domain.ProfileRepository {
	return &pgProfileRepository{q: q}
}

func (r *pgProfileRepository) GetByUserID(ctx context.Context, userID uuid.UUID) (*domain.Profile, error) {
	row, err := r.q.GetProfileByUserID(ctx, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return mapGetProfileRowToDomain(row), nil
}

func (r *pgProfileRepository) Upsert(ctx context.Context, p *domain.Profile) error {
	var bio, jobTitle, education, religion, city, region pgtype.Text
	if p.Bio != "" {
		bio = pgtype.Text{String: p.Bio, Valid: true}
	}
	if p.JobTitle != "" {
		jobTitle = pgtype.Text{String: p.JobTitle, Valid: true}
	}
	if p.Education != "" {
		education = pgtype.Text{String: p.Education, Valid: true}
	}
	if p.Religion != "" {
		religion = pgtype.Text{String: p.Religion, Valid: true}
	}
	if p.City != "" {
		city = pgtype.Text{String: p.City, Valid: true}
	}
	if p.Region != "" {
		region = pgtype.Text{String: p.Region, Valid: true}
	}

	var heightCm pgtype.Int4
	if p.HeightCm != nil {
		heightCm = pgtype.Int4{Int32: int32(*p.HeightCm), Valid: true}
	}

	var birthdate pgtype.Date
	if !p.Birthdate.IsZero() {
		birthdate = pgtype.Date{Time: p.Birthdate, Valid: true}
	}

	interestedIn := p.InterestedIn
	if interestedIn == nil {
		interestedIn = []string{}
	}
	languages := p.Languages
	if languages == nil {
		languages = []string{}
	}

	row, err := r.q.UpsertProfile(ctx, UpsertProfileParams{
		UserID:            p.UserID,
		DisplayName:       p.DisplayName,
		Birthdate:         birthdate,
		Gender:            p.Gender,
		InterestedIn:      interestedIn,
		Bio:               bio,
		JobTitle:          jobTitle,
		Education:         education,
		HeightCm:          heightCm,
		Religion:          religion,
		Languages:         languages,
		City:              city,
		Region:            region,
		ShowMe:            p.ShowMe,
		DistancePrefKm:    int32(p.DistancePrefKm),
		AgeMin:            int32(p.AgeMin),
		AgeMax:            int32(p.AgeMax),
		CompletenessScore: int32(p.CompletenessScore),
	})
	if err != nil {
		return err
	}

	updated := mapUpsertProfileRowToDomain(row)
	*p = *updated
	return nil
}

func (r *pgProfileRepository) UpdateInterests(ctx context.Context, userID uuid.UUID, interests []string) error {
	if err := r.q.ClearUserInterests(ctx, userID); err != nil {
		return err
	}
	for _, interest := range interests {
		if err := r.q.AddUserInterestByName(ctx, AddUserInterestByNameParams{
			UserID: userID,
			Lower:  interest,
		}); err != nil {
			return err
		}
	}
	return nil
}

func (r *pgProfileRepository) GetUserInterests(ctx context.Context, userID uuid.UUID) ([]string, error) {
	return r.q.GetUserInterests(ctx, userID)
}

func (r *pgProfileRepository) UpdateLocation(ctx context.Context, userID uuid.UUID, lat, lng float64, city, region string) error {
	return r.q.UpdateProfileLocation(ctx, UpdateProfileLocationParams{
		UserID:    userID,
		StMakepoint:   lng,
		StMakepoint_2: lat,
		City:      pgtype.Text{String: city, Valid: city != ""},
		Region:    pgtype.Text{String: region, Valid: region != ""},
	})
}

func (r *pgProfileRepository) GetPhotos(ctx context.Context, userID uuid.UUID) ([]domain.ProfilePhoto, error) {
	rows, err := r.q.GetPhotosByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}

	photos := make([]domain.ProfilePhoto, 0, len(rows))
	for _, row := range rows {
		photos = append(photos, mapPhotoRowToDomain(row))
	}
	return photos, nil
}

func (r *pgProfileRepository) GetPhotoByID(ctx context.Context, id uuid.UUID) (*domain.ProfilePhoto, error) {
	row, err := r.q.GetPhotoByID(ctx, id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	p := mapPhotoRowToDomain(row)
	return &p, nil
}

func (r *pgProfileRepository) CreatePhoto(ctx context.Context, photo *domain.ProfilePhoto) error {
	variantsBytes := []byte("{}")
	if photo.Variants != nil {
		if b, err := json.Marshal(photo.Variants); err == nil {
			variantsBytes = b
		}
	}

	row, err := r.q.CreateProfilePhoto(ctx, CreateProfilePhotoParams{
		ID:       photo.ID,
		UserID:   photo.UserID,
		Position: int32(photo.Position),
		Blurhash: pgtype.Text{String: photo.Blurhash, Valid: photo.Blurhash != ""},
		Width:    pgtype.Int4{Int32: int32(photo.Width), Valid: photo.Width > 0},
		Height:   pgtype.Int4{Int32: int32(photo.Height), Valid: photo.Height > 0},
		Variants: variantsBytes,
		Status:   string(photo.Status),
	})
	if err != nil {
		return err
	}

	photo.CreatedAt = row.CreatedAt.Time
	return nil
}

func (r *pgProfileRepository) UpdatePhoto(ctx context.Context, photo *domain.ProfilePhoto) error {
	variantsBytes := []byte("{}")
	if photo.Variants != nil {
		if b, err := json.Marshal(photo.Variants); err == nil {
			variantsBytes = b
		}
	}

	return r.q.UpdateProfilePhoto(ctx, UpdateProfilePhotoParams{
		ID:       photo.ID,
		Blurhash: pgtype.Text{String: photo.Blurhash, Valid: photo.Blurhash != ""},
		Width:    pgtype.Int4{Int32: int32(photo.Width), Valid: photo.Width > 0},
		Height:   pgtype.Int4{Int32: int32(photo.Height), Valid: photo.Height > 0},
		Variants: variantsBytes,
		Status:   string(photo.Status),
	})
}

func (r *pgProfileRepository) DeletePhoto(ctx context.Context, id, userID uuid.UUID) error {
	return r.q.DeleteProfilePhoto(ctx, DeleteProfilePhotoParams{
		ID:     id,
		UserID: userID,
	})
}

func (r *pgProfileRepository) ReorderPhotos(ctx context.Context, userID uuid.UUID, photoIDs []uuid.UUID) error {
	for i, id := range photoIDs {
		if err := r.q.UpdatePhotoPosition(ctx, UpdatePhotoPositionParams{
			ID:       id,
			Position: int32(i + 1),
			UserID:   userID,
		}); err != nil {
			return err
		}
	}
	return nil
}

func (r *pgProfileRepository) CountPhotos(ctx context.Context, userID uuid.UUID) (int, error) {
	count, err := r.q.CountProfilePhotos(ctx, userID)
	return int(count), err
}

func (r *pgProfileRepository) CreateVerification(ctx context.Context, v *domain.Verification) error {
	row, err := r.q.CreateVerification(ctx, CreateVerificationParams{
		ID:       v.ID,
		UserID:   v.UserID,
		PhotoUrl: v.PhotoURL,
		Pose:     v.Pose,
		Status:   v.Status,
	})
	if err != nil {
		return err
	}
	v.CreatedAt = row.CreatedAt.Time
	return nil
}

func mapGetProfileRowToDomain(row GetProfileByUserIDRow) *domain.Profile {
	var heightCm *int
	if row.HeightCm.Valid {
		h := int(row.HeightCm.Int32)
		heightCm = &h
	}

	var loc *domain.Coordinates
	if lat, ok := row.Latitude.(float64); ok {
		if lng, ok2 := row.Longitude.(float64); ok2 {
			loc = &domain.Coordinates{Latitude: lat, Longitude: lng}
		}
	}

	return &domain.Profile{
		UserID:            row.UserID,
		DisplayName:       row.DisplayName,
		Birthdate:         row.Birthdate.Time,
		Gender:            row.Gender,
		InterestedIn:      row.InterestedIn,
		Bio:               row.Bio.String,
		JobTitle:          row.JobTitle.String,
		Education:         row.Education.String,
		HeightCm:          heightCm,
		Religion:          row.Religion.String,
		Languages:         row.Languages,
		City:              row.City.String,
		Region:            row.Region.String,
		Location:          loc,
		ShowMe:            row.ShowMe,
		DistancePrefKm:    int(row.DistancePrefKm),
		AgeMin:            int(row.AgeMin),
		AgeMax:            int(row.AgeMax),
		Verified:          row.Verified,
		CompletenessScore: int(row.CompletenessScore),
		CreatedAt:         row.CreatedAt.Time,
		UpdatedAt:         row.UpdatedAt.Time,
	}
}

func mapUpsertProfileRowToDomain(row UpsertProfileRow) *domain.Profile {
	var heightCm *int
	if row.HeightCm.Valid {
		h := int(row.HeightCm.Int32)
		heightCm = &h
	}

	var loc *domain.Coordinates
	if lat, ok := row.Latitude.(float64); ok {
		if lng, ok2 := row.Longitude.(float64); ok2 {
			loc = &domain.Coordinates{Latitude: lat, Longitude: lng}
		}
	}

	return &domain.Profile{
		UserID:            row.UserID,
		DisplayName:       row.DisplayName,
		Birthdate:         row.Birthdate.Time,
		Gender:            row.Gender,
		InterestedIn:      row.InterestedIn,
		Bio:               row.Bio.String,
		JobTitle:          row.JobTitle.String,
		Education:         row.Education.String,
		HeightCm:          heightCm,
		Religion:          row.Religion.String,
		Languages:         row.Languages,
		City:              row.City.String,
		Region:            row.Region.String,
		Location:          loc,
		ShowMe:            row.ShowMe,
		DistancePrefKm:    int(row.DistancePrefKm),
		AgeMin:            int(row.AgeMin),
		AgeMax:            int(row.AgeMax),
		Verified:          row.Verified,
		CompletenessScore: int(row.CompletenessScore),
		CreatedAt:         row.CreatedAt.Time,
		UpdatedAt:         row.UpdatedAt.Time,
	}
}

func mapPhotoRowToDomain(row ProfilePhoto) domain.ProfilePhoto {
	var variants map[string]any
	if len(row.Variants) > 0 {
		_ = json.Unmarshal(row.Variants, &variants)
	}
	if variants == nil {
		variants = make(map[string]any)
	}

	return domain.ProfilePhoto{
		ID:        row.ID,
		UserID:    row.UserID,
		Position:  int(row.Position),
		Blurhash:  row.Blurhash.String,
		Width:     int(row.Width.Int32),
		Height:    int(row.Height.Int32),
		Variants:  variants,
		Status:    domain.PhotoStatus(row.Status),
		CreatedAt: row.CreatedAt.Time,
	}
}
