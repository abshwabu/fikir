package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/abshwabu/fikir/backend/internal/http/middleware"
	"github.com/abshwabu/fikir/backend/internal/http/response"
	apperrors "github.com/abshwabu/fikir/backend/internal/platform/errors"
	"github.com/abshwabu/fikir/backend/internal/service"
)

type MediaHandler struct {
	mediaService service.MediaService
}

func NewMediaHandler(mediaService service.MediaService) *MediaHandler {
	return &MediaHandler{
		mediaService: mediaService,
	}
}

// RequestUploadURL handles POST /v1/me/photos/upload-url
func (h *MediaHandler) RequestUploadURL(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("Authentication required"))
		return
	}

	var req service.UploadURLRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, apperrors.BadRequest("Invalid JSON request body"))
		return
	}

	res, err := h.mediaService.RequestUploadURL(r.Context(), userID, req)
	if err != nil {
		response.Error(w, err)
		return
	}

	response.JSON(w, http.StatusOK, res)
}

// CompleteUpload handles POST /v1/me/photos/{id}/complete
func (h *MediaHandler) CompleteUpload(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("Authentication required"))
		return
	}

	idStr := chi.URLParam(r, "id")
	photoID, err := uuid.Parse(idStr)
	if err != nil {
		response.Error(w, apperrors.BadRequest("Invalid photo ID"))
		return
	}

	if err := h.mediaService.CompleteUpload(r.Context(), userID, photoID); err != nil {
		response.Error(w, err)
		return
	}

	response.JSON(w, http.StatusAccepted, map[string]any{
		"message":  "image processing enqueued",
		"photo_id": photoID,
	})
}

// DeletePhoto handles DELETE /v1/me/photos/{id}
func (h *MediaHandler) DeletePhoto(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("Authentication required"))
		return
	}

	idStr := chi.URLParam(r, "id")
	photoID, err := uuid.Parse(idStr)
	if err != nil {
		response.Error(w, apperrors.BadRequest("Invalid photo ID"))
		return
	}

	if err := h.mediaService.DeletePhoto(r.Context(), userID, photoID); err != nil {
		response.Error(w, err)
		return
	}

	response.JSON(w, http.StatusOK, map[string]string{
		"message": "photo deleted successfully",
	})
}

// ReorderPhotos handles PUT /v1/me/photos/reorder
func (h *MediaHandler) ReorderPhotos(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("Authentication required"))
		return
	}

	var req service.ReorderPhotosRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, apperrors.BadRequest("Invalid JSON request body"))
		return
	}

	photos, err := h.mediaService.ReorderPhotos(r.Context(), userID, req.PhotoIDs, r.Header.Get("Accept"))
	if err != nil {
		response.Error(w, err)
		return
	}

	response.JSON(w, http.StatusOK, map[string]any{
		"photos": photos,
	})
}
