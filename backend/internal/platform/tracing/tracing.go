package tracing

import (
	"context"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/propagation"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/trace"
)

const TracerName = "github.com/abshwabu/fikir/backend"

// Tracer returns the named tracer for the application.
func Tracer() trace.Tracer {
	return otel.GetTracerProvider().Tracer(TracerName)
}

// StartSpan starts a new span from the given context.
func StartSpan(ctx context.Context, spanName string, opts ...trace.SpanStartOption) (context.Context, trace.Span) {
	return Tracer().Start(ctx, spanName, opts...)
}

// InitTracer initializes an in-memory/noop tracer provider with standard propagators
func InitTracer(serviceName string) (*sdktrace.TracerProvider, func(context.Context) error) {
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithSampler(sdktrace.AlwaysSample()),
	)

	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	))

	cleanup := func(ctx context.Context) error {
		return tp.Shutdown(ctx)
	}

	return tp, cleanup
}
