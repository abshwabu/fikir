package service

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	"github.com/abshwabu/fikir/backend/internal/domain"
	apperrors "github.com/abshwabu/fikir/backend/internal/platform/errors"
	"github.com/abshwabu/fikir/backend/internal/platform/ethiopia"
	"github.com/abshwabu/fikir/backend/internal/platform/media"
	"github.com/abshwabu/fikir/backend/internal/queue"
	"github.com/abshwabu/fikir/backend/internal/storage"
)

const (
	MaxPhotosPerUser = 6
	MaxUploadBytes   = 8 * 1024 * 1024 // 8 MB
)

var allowedContentTypes = map[string]string{
	"image/jpeg": "jpg",
	"image/png":  "png",
	"image/heic": "heic",
	"image/webp": "webp",
}

type UploadURLRequest struct {
	ContentType string `json:"content_type"`
	FileSize    int64  `json:"file_size"`
}

type UploadURLResponse struct {
	PhotoID   uuid.UUID `json:"photo_id"`
	UploadURL string    `json:"upload_url"`
	ExpiresIn int       `json:"expires_in"` // seconds
}

type ReorderPhotosRequest struct {
	PhotoIDs []uuid.UUID `json:"photo_ids"`
}

type PhotoVariantResponse struct {
	URL    string `json:"url"`
	Width  int    `json:"width"`
	Height int    `json:"height"`
	Size   int    `json:"size"`
}

type PhotoResponse struct {
	ID            uuid.UUID                                       `json:"id"`
	Position      int                                             `json:"position"`
	Status        domain.PhotoStatus                              `json:"status"`
	Blurhash      string                                          `json:"blurhash,omitempty"`
	DominantColor string                                          `json:"dominant_color,omitempty"`
	Width         int                                             `json:"width"`
	Height        int                                             `json:"height"`
	URL           string                                          `json:"url"`
	Variants      map[string]map[string]PhotoVariantResponse      `json:"variants,omitempty"`
	CreatedAt     time.Time                                       `json:"created_at"`
}

type MediaService interface {
	RequestUploadURL(ctx context.Context, userID uuid.UUID, req UploadURLRequest) (*UploadURLResponse, error)
	CompleteUpload(ctx context.Context, userID, photoID uuid.UUID) error
	ProcessImage(ctx context.Context, photoID, userID uuid.UUID, originalKey string) error
	DeletePhoto(ctx context.Context, userID, photoID uuid.UUID) error
	ReorderPhotos(ctx context.Context, userID uuid.UUID, photoIDs []uuid.UUID, acceptHeader string) ([]PhotoResponse, error)
	GetUserPhotos(ctx context.Context, userID uuid.UUID, acceptHeader string) ([]PhotoResponse, error)
	FormatPhoto(photo domain.ProfilePhoto, acceptHeader string) PhotoResponse
}

type mediaService struct {
	profileRepo domain.ProfileRepository
	storage     *storage.Storage
	queue       *queue.Client
	processor   media.ImageProcessor
	moderator   media.ImageModerator
	cdnBaseURL  string
}

func NewMediaService(
	profileRepo domain.ProfileRepository,
	storage *storage.Storage,
	queue *queue.Client,
	processor media.ImageProcessor,
	moderator media.ImageModerator,
	cdnBaseURL string,
) MediaService {
	return &mediaService{
		profileRepo: profileRepo,
		storage:     storage,
		queue:       queue,
		processor:   processor,
		moderator:   moderator,
		cdnBaseURL:  strings.TrimRight(cdnBaseURL, "/"),
	}
}

func (s *mediaService) RequestUploadURL(ctx context.Context, userID uuid.UUID, req UploadURLRequest) (*UploadURLResponse, error) {
	ext, ok := allowedContentTypes[req.ContentType]
	if !ok {
		return nil, apperrors.BadRequest("invalid content_type; allowed: image/jpeg, image/png, image/heic, image/webp")
	}

	if req.FileSize <= 0 || req.FileSize > MaxUploadBytes {
		return nil, apperrors.BadRequest("file_size must be between 1 byte and 8 MB")
	}

	count, err := s.profileRepo.CountPhotos(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to check existing photo count: %w", err)
	}
	if count >= MaxPhotosPerUser {
		return nil, apperrors.BadRequest("maximum 6 photos allowed")
	}

	photoID := uuid.New()
	originalKey := fmt.Sprintf("originals/%s/%s.%s", userID.String(), photoID.String(), ext)

	presignedURL, err := s.storage.PresignedPutOriginal(ctx, originalKey, 15*time.Minute)
	if err != nil {
		return nil, fmt.Errorf("failed to generate presigned upload url: %w", err)
	}

	photo := &domain.ProfilePhoto{
		ID:       photoID,
		UserID:   userID,
		Position: count + 1,
		Status:   domain.PhotoStatusPending,
		Variants: map[string]any{
			"original_key": originalKey,
			"content_type": req.ContentType,
			"file_size":    req.FileSize,
		},
	}

	if err := s.profileRepo.CreatePhoto(ctx, photo); err != nil {
		return nil, fmt.Errorf("failed to save photo metadata: %w", err)
	}

	return &UploadURLResponse{
		PhotoID:   photoID,
		UploadURL: presignedURL.String(),
		ExpiresIn: 900,
	}, nil
}

func (s *mediaService) CompleteUpload(ctx context.Context, userID, photoID uuid.UUID) error {
	photo, err := s.profileRepo.GetPhotoByID(ctx, photoID)
	if err != nil {
		return fmt.Errorf("failed to retrieve photo: %w", err)
	}
	if photo == nil || photo.UserID != userID {
		return apperrors.NotFound("photo not found")
	}

	originalKey, _ := photo.Variants["original_key"].(string)
	if originalKey == "" {
		originalKey = fmt.Sprintf("originals/%s/%s.jpg", userID.String(), photoID.String())
	}

	if s.queue != nil {
		if _, err := s.queue.EnqueueImageProcess(ctx, photoID, userID, originalKey); err != nil {
			return fmt.Errorf("failed to enqueue image processing task: %w", err)
		}
	} else {
		// Fallback: synchronous process if queue client is nil
		go func() {
			bgCtx := context.Background()
			_ = s.ProcessImage(bgCtx, photoID, userID, originalKey)
		}()
	}

	return nil
}

func (s *mediaService) ProcessImage(ctx context.Context, photoID, userID uuid.UUID, originalKey string) error {
	obj, err := s.storage.GetObjectOriginal(ctx, originalKey)
	if err != nil {
		return fmt.Errorf("failed to get original image: %w", err)
	}
	defer obj.Close()

	imgBytes, err := io.ReadAll(obj)
	if err != nil {
		return fmt.Errorf("failed to read original image bytes: %w", err)
	}
	if len(imgBytes) == 0 {
		return fmt.Errorf("image data is empty for key: %s", originalKey)
	}

	processResult, err := s.processor.Process(ctx, imgBytes, userID)
	if err != nil {
		log.Error().Err(err).Str("photo_id", photoID.String()).Msg("Image processor failure")
		_ = s.profileRepo.UpdatePhoto(ctx, &domain.ProfilePhoto{
			ID:     photoID,
			Status: domain.PhotoStatusRejected,
			Variants: map[string]any{
				"error": err.Error(),
			},
		})
		return err
	}

	// Upload variants to public bucket
	for _, v := range processResult.Variants {
		_, err := s.storage.UploadPublic(ctx, v.Path, bytes.NewReader(v.Data), int64(v.Size), v.ContentType)
		if err != nil {
			log.Error().Err(err).Str("path", v.Path).Msg("Failed to upload variant to public bucket")
			return fmt.Errorf("failed to upload variant %s: %w", v.Name, err)
		}
	}

	// Run pluggable moderation hook
	modResult, err := s.moderator.Moderate(ctx, imgBytes)
	if err != nil {
		log.Warn().Err(err).Msg("Image moderation check returned error; setting to pending")
		modResult = media.ModerationResult{
			Status: domain.PhotoStatusPending,
		}
	}

	processResult.VariantsJSON["moderation"] = modResult
	processResult.VariantsJSON["original_key"] = originalKey

	// Update DB record
	photo, err := s.profileRepo.GetPhotoByID(ctx, photoID)
	if err != nil || photo == nil {
		photo = &domain.ProfilePhoto{
			ID:     photoID,
			UserID: userID,
		}
	}

	photo.Width = processResult.OriginalWidth
	photo.Height = processResult.OriginalHeight
	photo.Blurhash = processResult.BlurHash
	photo.Variants = processResult.VariantsJSON
	photo.Status = modResult.Status

	if err := s.profileRepo.UpdatePhoto(ctx, photo); err != nil {
		return fmt.Errorf("failed to update processed photo record: %w", err)
	}

	// Recompute profile completeness score & update discovery state
	p, err := s.profileRepo.GetByUserID(ctx, userID)
	if err == nil && p != nil {
		count, _ := s.profileRepo.CountPhotos(ctx, userID)
		p.CompletenessScore = ethiopia.CalculateCompletenessScore(p, count)
		if count > 0 && photo.Status == domain.PhotoStatusApproved {
			p.ShowMe = true
		}
		_ = s.profileRepo.Upsert(ctx, p)
	}

	log.Info().Str("photo_id", photoID.String()).Str("status", string(photo.Status)).Msg("Image processed successfully")
	return nil
}

func (s *mediaService) DeletePhoto(ctx context.Context, userID, photoID uuid.UUID) error {
	photo, err := s.profileRepo.GetPhotoByID(ctx, photoID)
	if err != nil {
		return fmt.Errorf("failed to query photo: %w", err)
	}
	if photo == nil || photo.UserID != userID {
		return apperrors.NotFound("photo not found")
	}

	if err := s.profileRepo.DeletePhoto(ctx, photoID, userID); err != nil {
		return fmt.Errorf("failed to delete photo from database: %w", err)
	}

	// Best-effort cleanup in MinIO storage
	go func() {
		bgCtx := context.Background()
		if origKey, ok := photo.Variants["original_key"].(string); ok && origKey != "" {
			_ = s.storage.DeleteObject(bgCtx, s.storage.BucketOriginal(), origKey)
		}
		for _, variantName := range []string{"thumb", "card", "full"} {
			if vMap, ok := photo.Variants[variantName].(map[string]any); ok {
				for _, fmtMap := range vMap {
					if info, ok := fmtMap.(map[string]any); ok {
						if pth, ok := info["path"].(string); ok && pth != "" {
							_ = s.storage.DeleteObject(bgCtx, s.storage.BucketPublic(), pth)
						}
					}
				}
			}
		}
	}()

	// Reorder remaining photos 1..N
	remaining, err := s.profileRepo.GetPhotos(ctx, userID)
	if err == nil {
		reorderIDs := make([]uuid.UUID, len(remaining))
		for i, p := range remaining {
			reorderIDs[i] = p.ID
		}
		_ = s.profileRepo.ReorderPhotos(ctx, userID, reorderIDs)
	}

	// Update profile completeness and hide if 0 photos remain
	p, err := s.profileRepo.GetByUserID(ctx, userID)
	if err == nil && p != nil {
		remCount := len(remaining)
		p.CompletenessScore = ethiopia.CalculateCompletenessScore(p, remCount)
		if remCount == 0 {
			p.ShowMe = false
		}
		_ = s.profileRepo.Upsert(ctx, p)
	}

	return nil
}

func (s *mediaService) ReorderPhotos(ctx context.Context, userID uuid.UUID, photoIDs []uuid.UUID, acceptHeader string) ([]PhotoResponse, error) {
	currentPhotos, err := s.profileRepo.GetPhotos(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch user photos: %w", err)
	}

	if len(photoIDs) != len(currentPhotos) {
		return nil, apperrors.BadRequest(fmt.Sprintf("photo_ids count (%d) does not match user photos count (%d)", len(photoIDs), len(currentPhotos)))
	}

	validIDs := make(map[uuid.UUID]bool, len(currentPhotos))
	for _, p := range currentPhotos {
		validIDs[p.ID] = true
	}

	for _, id := range photoIDs {
		if !validIDs[id] {
			return nil, apperrors.BadRequest("invalid photo id in reorder list")
		}
	}

	if err := s.profileRepo.ReorderPhotos(ctx, userID, photoIDs); err != nil {
		return nil, fmt.Errorf("failed to reorder photos: %w", err)
	}

	return s.GetUserPhotos(ctx, userID, acceptHeader)
}

func (s *mediaService) GetUserPhotos(ctx context.Context, userID uuid.UUID, acceptHeader string) ([]PhotoResponse, error) {
	photos, err := s.profileRepo.GetPhotos(ctx, userID)
	if err != nil {
		return nil, err
	}

	res := make([]PhotoResponse, len(photos))
	for i, p := range photos {
		res[i] = s.FormatPhoto(p, acceptHeader)
	}
	return res, nil
}

func (s *mediaService) FormatPhoto(photo domain.ProfilePhoto, acceptHeader string) PhotoResponse {
	var domColor string
	if c, ok := photo.Variants["dominant_color"].(string); ok {
		domColor = c
	}

	variantsMap := make(map[string]map[string]PhotoVariantResponse)

	var cardWebpURL, cardAvifURL, cardJpegURL string
	var thumbWebpURL, fullWebpURL string

	for _, variantName := range []string{"thumb", "card", "full"} {
		vData, ok := photo.Variants[variantName].(map[string]any)
		if !ok {
			continue
		}

		formatsMap := make(map[string]PhotoVariantResponse)
		for fmtKey, fmtVal := range vData {
			info, ok := fmtVal.(map[string]any)
			if !ok {
				continue
			}

			path, _ := info["path"].(string)
			w := getInt(info["width"])
			h := getInt(info["height"])
			sz := getInt(info["size"])

			fullURL := path
			if path != "" && !strings.HasPrefix(path, "http://") && !strings.HasPrefix(path, "https://") {
				fullURL = fmt.Sprintf("%s/%s", s.cdnBaseURL, strings.TrimPrefix(path, "/"))
			}

			formatsMap[fmtKey] = PhotoVariantResponse{
				URL:    fullURL,
				Width:  w,
				Height: h,
				Size:   sz,
			}

			switch {
			case variantName == "card" && fmtKey == "webp":
				cardWebpURL = fullURL
			case variantName == "card" && fmtKey == "avif":
				cardAvifURL = fullURL
			case variantName == "card" && fmtKey == "jpeg":
				cardJpegURL = fullURL
			case variantName == "thumb" && fmtKey == "webp":
				thumbWebpURL = fullURL
			case variantName == "full" && fmtKey == "webp":
				fullWebpURL = fullURL
			}
		}

		if len(formatsMap) > 0 {
			variantsMap[variantName] = formatsMap
		}
	}

	// Choose default primary URL respecting Accept negotiation header
	primaryURL := cardWebpURL
	if strings.Contains(acceptHeader, "image/avif") && cardAvifURL != "" {
		primaryURL = cardAvifURL
	} else if primaryURL == "" {
		if cardJpegURL != "" {
			primaryURL = cardJpegURL
		} else if fullWebpURL != "" {
			primaryURL = fullWebpURL
		} else if thumbWebpURL != "" {
			primaryURL = thumbWebpURL
		}
	}

	return PhotoResponse{
		ID:            photo.ID,
		Position:      photo.Position,
		Status:        photo.Status,
		Blurhash:      photo.Blurhash,
		DominantColor: domColor,
		Width:         photo.Width,
		Height:        photo.Height,
		URL:           primaryURL,
		Variants:      variantsMap,
		CreatedAt:     photo.CreatedAt,
	}
}

func getInt(v any) int {
	switch n := v.(type) {
	case int:
		return n
	case int32:
		return int(n)
	case int64:
		return int(n)
	case float64:
		return int(n)
	default:
		return 0
	}
}
