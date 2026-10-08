package handler

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/abshwabu/fikir/backend/internal/domain"
	"github.com/abshwabu/fikir/backend/internal/http/middleware"
	"github.com/abshwabu/fikir/backend/internal/http/response"
	apperrors "github.com/abshwabu/fikir/backend/internal/platform/errors"
	"github.com/abshwabu/fikir/backend/internal/service"
)

type SwipeHandler struct {
	swipeService service.SwipeService
}

func NewSwipeHandler(swipeService service.SwipeService) *SwipeHandler {
	return &SwipeHandler{
		swipeService: swipeService,
	}
}

type SwipeRequest struct {
	TargetID  uuid.UUID             `json:"target_id"`
	Direction domain.SwipeDirection `json:"direction"`
}

type BlockRequest struct {
	TargetID uuid.UUID `json:"target_id"`
	Reason   string    `json:"reason"`
}

type ReportRequest struct {
	TargetID uuid.UUID `json:"target_id"`
	Reason   string    `json:"reason"`
	Details  string    `json:"details"`
}

// Swipe handles POST /v1/swipes
func (h *SwipeHandler) Swipe(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("Authentication required"))
		return
	}

	var req SwipeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, apperrors.BadRequest("Invalid JSON request body"))
		return
	}

	if req.TargetID == uuid.Nil {
		response.Error(w, apperrors.BadRequest("target_id is required"))
		return
	}

	res, err := h.swipeService.Swipe(r.Context(), userID, req.TargetID, req.Direction)
	if err != nil {
		response.Error(w, err)
		return
	}

	response.JSON(w, http.StatusOK, res)
}

// Rewind handles POST /v1/swipes/rewind
func (h *SwipeHandler) Rewind(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("Authentication required"))
		return
	}

	res, err := h.swipeService.Rewind(r.Context(), userID)
	if err != nil {
		response.Error(w, err)
		return
	}

	response.JSON(w, http.StatusOK, res)
}

// GetLikesYou handles GET /v1/likes-you
func (h *SwipeHandler) GetLikesYou(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("Authentication required"))
		return
	}

	limit := 20
	if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
		if parsed, err := strconv.Atoi(limitStr); err == nil && parsed > 0 {
			limit = parsed
		}
	}

	// In test/dev, allow query param override ?is_premium=true or check user status
	isPremium := r.URL.Query().Get("is_premium") == "true"

	res, err := h.swipeService.GetLikesYou(r.Context(), userID, isPremium, limit, r.Header.Get("Accept"))
	if err != nil {
		response.Error(w, err)
		return
	}

	response.JSON(w, http.StatusOK, res)
}

// GetMatches handles GET /v1/matches
func (h *SwipeHandler) GetMatches(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("Authentication required"))
		return
	}

	limit := 20
	if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
		if parsed, err := strconv.Atoi(limitStr); err == nil && parsed > 0 {
			limit = parsed
		}
	}
	cursor := r.URL.Query().Get("cursor")

	matches, nextCursor, err := h.swipeService.GetMatches(r.Context(), userID, limit, cursor)
	if err != nil {
		response.Error(w, err)
		return
	}

	response.JSON(w, http.StatusOK, map[string]any{
		"matches":     matches,
		"next_cursor": nextCursor,
	})
}

// Unmatch handles DELETE /v1/matches/{id}
func (h *SwipeHandler) Unmatch(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("Authentication required"))
		return
	}

	idStr := chi.URLParam(r, "id")
	matchID, err := uuid.Parse(idStr)
	if err != nil {
		response.Error(w, apperrors.BadRequest("invalid match id"))
		return
	}

	if err := h.swipeService.Unmatch(r.Context(), matchID, userID); err != nil {
		response.Error(w, err)
		return
	}

	response.JSON(w, http.StatusOK, map[string]any{
		"unmatched": true,
	})
}

// Block handles POST /v1/blocks
func (h *SwipeHandler) Block(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("Authentication required"))
		return
	}

	var req BlockRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, apperrors.BadRequest("Invalid JSON request body"))
		return
	}

	if req.TargetID == uuid.Nil {
		response.Error(w, apperrors.BadRequest("target_id is required"))
		return
	}

	if err := h.swipeService.Block(r.Context(), userID, req.TargetID, req.Reason); err != nil {
		response.Error(w, err)
		return
	}

	response.JSON(w, http.StatusOK, map[string]any{
		"blocked": true,
	})
}

// Report handles POST /v1/reports
func (h *SwipeHandler) Report(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("Authentication required"))
		return
	}

	var req ReportRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, apperrors.BadRequest("Invalid JSON request body"))
		return
	}

	if req.TargetID == uuid.Nil {
		response.Error(w, apperrors.BadRequest("target_id is required"))
		return
	}

	if err := h.swipeService.Report(r.Context(), userID, req.TargetID, req.Reason, req.Details); err != nil {
		response.Error(w, err)
		return
	}

	response.JSON(w, http.StatusCreated, map[string]any{
		"reported": true,
	})
}
