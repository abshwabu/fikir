package handler

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/google/uuid"

	"github.com/abshwabu/fikir/backend/internal/domain"
	"github.com/abshwabu/fikir/backend/internal/http/middleware"
	"github.com/abshwabu/fikir/backend/internal/http/response"
	apperrors "github.com/abshwabu/fikir/backend/internal/platform/errors"
	"github.com/abshwabu/fikir/backend/internal/service"
)

type ProfileHandler struct {
	profileService service.ProfileService
	mediaService   service.MediaService
}

func NewProfileHandler(profileService service.ProfileService, mediaService service.MediaService) *ProfileHandler {
	return &ProfileHandler{
		profileService: profileService,
		mediaService:   mediaService,
	}
}

type ProfileResponse struct {
	UserID            uuid.UUID              `json:"user_id"`
	DisplayName       string                 `json:"display_name"`
	Birthdate         string                 `json:"birthdate"`
	Gender            string                 `json:"gender"`
	InterestedIn      []string               `json:"interested_in"`
	Bio               string                 `json:"bio,omitempty"`
	JobTitle          string                 `json:"job_title,omitempty"`
	Education         string                 `json:"education,omitempty"`
	HeightCm          *int                   `json:"height_cm,omitempty"`
	Religion          string                 `json:"religion,omitempty"`
	Languages         []string               `json:"languages"`
	City              string                 `json:"city,omitempty"`
	Region            string                 `json:"region,omitempty"`
	Location          *domain.Coordinates   `json:"location,omitempty"`
	ShowMe            bool                   `json:"show_me"`
	DistancePrefKm    int                    `json:"distance_pref_km"`
	AgeMin            int                    `json:"age_min"`
	AgeMax            int                    `json:"age_max"`
	Verified          bool                   `json:"verified"`
	CompletenessScore int                    `json:"completeness_score"`
	Interests         []string               `json:"interests"`
	Photos            []service.PhotoResponse `json:"photos"`
	CreatedAt         time.Time              `json:"created_at"`
	UpdatedAt         time.Time              `json:"updated_at"`
}

type UpdateInterestsRequest struct {
	Interests []string `json:"interests"`
}

type VerificationRequest struct {
	PhotoURL string `json:"photo_url"`
	Pose     string `json:"pose"`
}

// GetProfile handles GET /v1/me/profile
func (h *ProfileHandler) GetProfile(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("Authentication required"))
		return
	}

	p, err := h.profileService.GetProfile(r.Context(), userID)
	if err != nil {
		response.Error(w, err)
		return
	}

	response.JSON(w, http.StatusOK, h.mapProfileToResponse(p, r.Header.Get("Accept")))
}

// UpdateProfile handles PATCH /v1/me/profile
func (h *ProfileHandler) UpdateProfile(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("Authentication required"))
		return
	}

	var req service.UpdateProfileRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, apperrors.BadRequest("Invalid JSON request body"))
		return
	}

	p, err := h.profileService.UpdateProfile(r.Context(), userID, req)
	if err != nil {
		response.Error(w, err)
		return
	}

	response.JSON(w, http.StatusOK, h.mapProfileToResponse(p, r.Header.Get("Accept")))
}

// UpdateInterests handles PUT /v1/me/interests
func (h *ProfileHandler) UpdateInterests(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("Authentication required"))
		return
	}

	var req UpdateInterestsRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, apperrors.BadRequest("Invalid JSON request body"))
		return
	}

	interests, err := h.profileService.UpdateInterests(r.Context(), userID, req.Interests)
	if err != nil {
		response.Error(w, err)
		return
	}

	response.JSON(w, http.StatusOK, map[string]any{
		"interests": interests,
	})
}

// UpdateLocation handles PUT /v1/me/location
func (h *ProfileHandler) UpdateLocation(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("Authentication required"))
		return
	}

	var req service.UpdateLocationRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, apperrors.BadRequest("Invalid JSON request body"))
		return
	}

	p, err := h.profileService.UpdateLocation(r.Context(), userID, req)
	if err != nil {
		response.Error(w, err)
		return
	}

	response.JSON(w, http.StatusOK, h.mapProfileToResponse(p, r.Header.Get("Accept")))
}

// SubmitVerification handles POST /v1/me/verification
func (h *ProfileHandler) SubmitVerification(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("Authentication required"))
		return
	}

	var req VerificationRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, apperrors.BadRequest("Invalid JSON request body"))
		return
	}

	v, err := h.profileService.SubmitVerification(r.Context(), userID, req.PhotoURL, req.Pose)
	if err != nil {
		response.Error(w, err)
		return
	}

	response.JSON(w, http.StatusCreated, v)
}

func (h *ProfileHandler) mapProfileToResponse(p *domain.Profile, acceptHeader string) ProfileResponse {
	var birthdateStr string
	if !p.Birthdate.IsZero() {
		birthdateStr = p.Birthdate.Format("2006-01-02")
	}

	formattedPhotos := make([]service.PhotoResponse, len(p.Photos))
	for i, ph := range p.Photos {
		formattedPhotos[i] = h.mediaService.FormatPhoto(ph, acceptHeader)
	}

	interests := p.Interests
	if interests == nil {
		interests = []string{}
	}
	languages := p.Languages
	if languages == nil {
		languages = []string{}
	}
	interestedIn := p.InterestedIn
	if interestedIn == nil {
		interestedIn = []string{}
	}

	return ProfileResponse{
		UserID:            p.UserID,
		DisplayName:       p.DisplayName,
		Birthdate:         birthdateStr,
		Gender:            p.Gender,
		InterestedIn:      interestedIn,
		Bio:               p.Bio,
		JobTitle:          p.JobTitle,
		Education:         p.Education,
		HeightCm:          p.HeightCm,
		Religion:          p.Religion,
		Languages:         languages,
		City:              p.City,
		Region:            p.Region,
		Location:          p.Location,
		ShowMe:            p.ShowMe,
		DistancePrefKm:    p.DistancePrefKm,
		AgeMin:            p.AgeMin,
		AgeMax:            p.AgeMax,
		Verified:          p.Verified,
		CompletenessScore: p.CompletenessScore,
		Interests:         interests,
		Photos:            formattedPhotos,
		CreatedAt:         p.CreatedAt,
		UpdatedAt:         p.UpdatedAt,
	}
}
