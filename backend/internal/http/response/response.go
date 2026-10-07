package response

import (
	"encoding/json"
	"errors"
	"net/http"

	apperrors "github.com/abshwabu/fikir/backend/internal/platform/errors"
)

// JSON writes a JSON response with status code
func JSON(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if data != nil {
		if err := json.NewEncoder(w).Encode(data); err != nil {
			http.Error(w, `{"error":{"code":"INTERNAL_SERVER_ERROR","message":"Failed to encode response"}}`, http.StatusInternalServerError)
		}
	}
}

// OK writes an HTTP 200 JSON response
func OK(w http.ResponseWriter, data any) {
	JSON(w, http.StatusOK, data)
}

// Created writes an HTTP 201 JSON response
func Created(w http.ResponseWriter, data any) {
	JSON(w, http.StatusCreated, data)
}

// NoContent writes an HTTP 204 response
func NoContent(w http.ResponseWriter) {
	w.WriteHeader(http.StatusNoContent)
}

// Error writes a standardized JSON error envelope response:
// { "error": { "code": "...", "message": "...", "details": [...] } }
func Error(w http.ResponseWriter, err error) {
	var appErr *apperrors.AppError
	if errors.As(err, &appErr) {
		JSON(w, appErr.StatusCode, apperrors.ErrorResponse{
			Error: apperrors.ErrorBody{
				Code:    appErr.Code,
				Message: appErr.Message,
				Details: appErr.Details,
			},
		})
		return
	}

	// Default unhandled error to 500 internal server error
	JSON(w, http.StatusInternalServerError, apperrors.ErrorResponse{
		Error: apperrors.ErrorBody{
			Code:    apperrors.CodeInternalServer,
			Message: "An internal server error occurred",
		},
	})
}
