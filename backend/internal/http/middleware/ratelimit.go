package middleware

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"github.com/rs/zerolog"

	"github.com/abshwabu/fikir/backend/internal/http/response"
	apperrors "github.com/abshwabu/fikir/backend/internal/platform/errors"
)

// RateLimiter implements a Redis sliding window rate limiter
type RateLimiter struct {
	rdb    *redis.Client
	log    zerolog.Logger
	window time.Duration
	limit  int
}

// NewRateLimiter creates a new RateLimiter instance
func NewRateLimiter(rdb *redis.Client, log zerolog.Logger, requestsPerMinute int) *RateLimiter {
	return &RateLimiter{
		rdb:    rdb,
		log:    log,
		window: time.Minute,
		limit:  requestsPerMinute,
	}
}

// Handler returns the HTTP rate limiting middleware
func (rl *RateLimiter) Handler() func(next http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if rl.rdb == nil || rl.limit <= 0 {
				next.ServeHTTP(w, r)
				return
			}

			// Determine identifier: authenticated User ID or client IP
			var key string
			if userID, ok := GetUserID(r.Context()); ok && userID != uuid.Nil {
				key = fmt.Sprintf("ratelimit:user:%s", userID.String())
			} else {
				ip := getClientIP(r)
				key = fmt.Sprintf("ratelimit:ip:%s", ip)
			}

			allowed, remaining, err := rl.allow(r.Context(), key)
			if err != nil {
				// Log Redis error and fail-open to avoid service disruption
				rl.log.Warn().Err(err).Str("key", key).Msg("Rate limiter Redis failure, allowing request")
				next.ServeHTTP(w, r)
				return
			}

			w.Header().Set("X-RateLimit-Limit", strconv.Itoa(rl.limit))
			w.Header().Set("X-RateLimit-Remaining", strconv.Itoa(remaining))

			if !allowed {
				w.Header().Set("Retry-After", "60")
				response.Error(w, apperrors.TooManyRequests("Rate limit exceeded. Please try again later."))
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

// allow checks and updates the sliding window in Redis
func (rl *RateLimiter) allow(ctx context.Context, key string) (bool, int, error) {
	now := time.Now().UnixNano()
	windowStart := now - rl.window.Nanoseconds()

	pipe := rl.rdb.TxPipeline()
	// Remove events outside current sliding window
	pipe.ZRemRangeByScore(ctx, key, "-inf", strconv.FormatInt(windowStart, 10))
	// Count events in current window
	countCmd := pipe.ZCard(ctx, key)
	// Add current event
	pipe.ZAdd(ctx, key, redis.Z{Score: float64(now), Member: strconv.FormatInt(now, 10)})
	// Refresh TTL
	pipe.Expire(ctx, key, rl.window)

	_, err := pipe.Exec(ctx)
	if err != nil {
		return true, rl.limit, err
	}

	count := int(countCmd.Val())
	if count >= rl.limit {
		return false, 0, nil
	}

	remaining := rl.limit - (count + 1)
	if remaining < 0 {
		remaining = 0
	}

	return true, remaining, nil
}

func getClientIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		parts := strings.Split(xff, ",")
		return strings.TrimSpace(parts[0])
	}
	if xrip := r.Header.Get("X-Real-IP"); xrip != "" {
		return strings.TrimSpace(xrip)
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err == nil {
		return host
	}
	return r.RemoteAddr
}
