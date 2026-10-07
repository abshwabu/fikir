package middleware

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5/middleware"
	"github.com/rs/zerolog"
)

// StructuredLogger logs HTTP requests using zerolog
func StructuredLogger(log zerolog.Logger) func(next http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			ww := middleware.NewWrapResponseWriter(w, r.ProtoMajor)

			reqID := GetRequestID(r.Context())

			defer func() {
				latency := time.Since(start)
				status := ww.Status()

				event := log.Info()
				if status >= 500 {
					event = log.Error()
				} else if status >= 400 {
					event = log.Warn()
				}

				event.
					Str("request_id", reqID).
					Str("method", r.Method).
					Str("path", r.URL.Path).
					Str("remote_ip", r.RemoteAddr).
					Str("user_agent", r.UserAgent()).
					Int("status", status).
					Int("bytes", ww.BytesWritten()).
					Dur("latency_ms", latency).
					Msg("HTTP request completed")
			}()

			next.ServeHTTP(ww, r)
		})
	}
}
