package middleware

import (
	"fmt"
	"net/http"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/propagation"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
	"go.opentelemetry.io/otel/trace"

	"github.com/abshwabu/fikir/backend/internal/platform/tracing"
)

// OpenTelemetryTracing creates spans for all HTTP requests and propagates trace headers
func OpenTelemetryTracing() func(next http.Handler) http.Handler {
	propagator := otel.GetTextMapPropagator()

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.URL.Path == "/metrics" || r.URL.Path == "/healthz" || r.URL.Path == "/readyz" {
				next.ServeHTTP(w, r)
				return
			}

			ctx := propagator.Extract(r.Context(), propagation.HeaderCarrier(r.Header))
			spanName := fmt.Sprintf("%s %s", r.Method, r.URL.Path)

			ctx, span := tracing.Tracer().Start(
				ctx,
				spanName,
				trace.WithSpanKind(trace.SpanKindServer),
				trace.WithAttributes(
					semconv.HTTPRequestMethodKey.String(r.Method),
					semconv.URLPath(r.URL.Path),
					attribute.String("http.client_ip", r.RemoteAddr),
					attribute.String("http.user_agent", r.UserAgent()),
				),
			)
			defer span.End()

			// Add trace id to response header
			if span.SpanContext().HasTraceID() {
				w.Header().Set("X-Trace-ID", span.SpanContext().TraceID().String())
			}

			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}
