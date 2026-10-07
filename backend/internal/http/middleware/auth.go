package middleware

import (
	"context"
	"net/http"
	"strings"

	"github.com/google/uuid"

	"github.com/abshwabu/fikir/backend/internal/http/response"
	apperrors "github.com/abshwabu/fikir/backend/internal/platform/errors"
)

const (
	UserIDContextKey contextKey = "user_id"
)

// AuthStub is an authentication middleware stub for Prompt 02.
// It parses Authorization: Bearer <token> if present, or accepts an X-User-ID header in dev.
func AuthStub(required bool) func(next http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			var userID string

			authHeader := r.Header.Get("Authorization")
			if strings.HasPrefix(authHeader, "Bearer ") {
				token := strings.TrimPrefix(authHeader, "Bearer ")
				// Stub: if token is a valid UUID, use as user ID; otherwise mock
				if _, err := uuid.Parse(token); err == nil {
					userID = token
				} else {
					userID = "00000000-0000-0000-0000-000000000001"
				}
			} else if devUserID := r.Header.Get("X-User-ID"); devUserID != "" {
				userID = devUserID
			}

			if required && userID == "" {
				response.Error(w, apperrors.Unauthorized("Missing or invalid authorization token"))
				return
			}

			if userID != "" {
				ctx := context.WithValue(r.Context(), UserIDContextKey, userID)
				r = r.WithContext(ctx)
			}

			next.ServeHTTP(w, r)
		})
	}
}

// GetUserID retrieves the authenticated user ID from context
func GetUserID(ctx context.Context) (string, bool) {
	val, ok := ctx.Value(UserIDContextKey).(string)
	return val, ok && val != ""
}
