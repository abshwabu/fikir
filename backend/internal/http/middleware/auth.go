package middleware

import (
	"context"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"github.com/rs/zerolog/log"

	"github.com/abshwabu/fikir/backend/internal/domain"
	"github.com/abshwabu/fikir/backend/internal/http/response"
	apperrors "github.com/abshwabu/fikir/backend/internal/platform/errors"
	"github.com/abshwabu/fikir/backend/internal/platform/token"
)

const (
	UserIDContextKey            contextKey = "user_id"
	DeviceFingerprintContextKey contextKey = "device_fingerprint"
)

// Auth creates an authentication middleware validating EdDSA JWTs.
// It also records throttled last_active_at updates (at most once every 5 minutes per user).
func Auth(tm *token.Manager, userRepo domain.UserRepository, rdb redis.UniversalClient) func(next http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			authHeader := r.Header.Get("Authorization")
			if !strings.HasPrefix(authHeader, "Bearer ") {
				response.Error(w, apperrors.Unauthorized("Missing or invalid authorization header"))
				return
			}

			tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
			claims, err := tm.ValidateAccessToken(tokenStr)
			if err != nil {
				response.Error(w, apperrors.Unauthorized("Invalid or expired token"))
				return
			}

			userID, err := uuid.Parse(claims.UserID)
			if err != nil {
				response.Error(w, apperrors.Unauthorized("Invalid user identity in token"))
				return
			}

			// Throttled last_active_at update via Redis (once per 5 minutes)
			if rdb != nil && userRepo != nil {
				throttleKey := "user:last_active_throttle:" + userID.String()
				// SETNX with 5-minute TTL
				ok, err := rdb.SetNX(r.Context(), throttleKey, "1", 5*time.Minute).Result()
				if err == nil && ok {
					go func(uid uuid.UUID) {
						updateCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
						defer cancel()
						if err := userRepo.UpdateLastActive(updateCtx, uid); err != nil {
							log.Warn().Err(err).Str("user_id", uid.String()).Msg("Failed to update last_active_at")
						}
					}(userID)
				}
			}

			// Extract device fingerprint hook header
			fingerprint := r.Header.Get("X-Device-Fingerprint")

			ctx := context.WithValue(r.Context(), UserIDContextKey, userID)
			if fingerprint != "" {
				ctx = context.WithValue(ctx, DeviceFingerprintContextKey, fingerprint)
			}

			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// GetUserID retrieves the authenticated user UUID from context
func GetUserID(ctx context.Context) (uuid.UUID, bool) {
	val, ok := ctx.Value(UserIDContextKey).(uuid.UUID)
	return val, ok && val != uuid.Nil
}

// GetDeviceFingerprint retrieves the device fingerprint from request or context
func GetDeviceFingerprint(r *http.Request) string {
	if fp, ok := r.Context().Value(DeviceFingerprintContextKey).(string); ok && fp != "" {
		return fp
	}
	return r.Header.Get("X-Device-Fingerprint")
}
