package middleware

import (
	"fmt"
	"net/http"
	"runtime/debug"

	"github.com/rs/zerolog"

	"github.com/abshwabu/fikir/backend/internal/http/response"
	apperrors "github.com/abshwabu/fikir/backend/internal/platform/errors"
)

// Recoverer recovers from panics, logs stack trace, and writes standardized 500 error envelope
func Recoverer(log zerolog.Logger) func(next http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				if rvr := recover(); rvr != nil {
					reqID := GetRequestID(r.Context())
					stack := string(debug.Stack())

					log.Error().
						Str("request_id", reqID).
						Str("panic", fmt.Sprintf("%v", rvr)).
						Str("stack", stack).
						Msg("Unhandled panic recovered")

					response.Error(w, apperrors.New(
						http.StatusInternalServerError,
						apperrors.CodeInternalServer,
						"An internal server error occurred",
					))
				}
			}()

			next.ServeHTTP(w, r)
		})
	}
}
