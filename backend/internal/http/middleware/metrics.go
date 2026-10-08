package middleware

import (
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"

	"github.com/abshwabu/fikir/backend/internal/platform/metrics"
)

// PrometheusMetrics returns a middleware that records HTTP duration and request counts
func PrometheusMetrics() func(next http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Don't track /metrics or /healthz to avoid noise
			if r.URL.Path == "/metrics" || r.URL.Path == "/healthz" || r.URL.Path == "/readyz" {
				next.ServeHTTP(w, r)
				return
			}

			start := time.Now()
			ww := chimw.NewWrapResponseWriter(w, r.ProtoMajor)

			next.ServeHTTP(ww, r)

			duration := time.Since(start).Seconds()
			statusStr := strconv.Itoa(ww.Status())

			// Resolve route pattern to prevent high-cardinality metric explosion
			path := r.URL.Path
			if routeCtx := chi.RouteContext(r.Context()); routeCtx != nil {
				pattern := routeCtx.RoutePattern()
				if pattern != "" {
					path = pattern
				}
			}

			metrics.HTTPRequestsTotal.WithLabelValues(r.Method, path, statusStr).Inc()
			metrics.HTTPRequestDuration.WithLabelValues(r.Method, path, statusStr).Observe(duration)
		})
	}
}
