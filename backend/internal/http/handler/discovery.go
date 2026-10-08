package handler

import (
	"net/http"
	"strconv"

	"github.com/abshwabu/fikir/backend/internal/http/middleware"
	"github.com/abshwabu/fikir/backend/internal/http/response"
	apperrors "github.com/abshwabu/fikir/backend/internal/platform/errors"
	"github.com/abshwabu/fikir/backend/internal/service"
)

type DiscoveryHandler struct {
	discoveryService service.DiscoveryService
}

func NewDiscoveryHandler(discoveryService service.DiscoveryService) *DiscoveryHandler {
	return &DiscoveryHandler{
		discoveryService: discoveryService,
	}
}

// GetDiscoveryDeck handles GET /v1/discovery?limit=15
func (h *DiscoveryHandler) GetDiscoveryDeck(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("Authentication required"))
		return
	}

	limit := 15
	if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
		if parsed, err := strconv.Atoi(limitStr); err == nil && parsed > 0 {
			limit = parsed
		}
	}

	deck, err := h.discoveryService.GetDeck(r.Context(), userID, limit, r.Header.Get("Accept"))
	if err != nil {
		response.Error(w, err)
		return
	}

	response.JSON(w, http.StatusOK, map[string]any{
		"deck": deck,
	})
}
