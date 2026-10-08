package metrics

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	// HTTPRequestsTotal tracks total incoming HTTP requests
	HTTPRequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Namespace: "fikir",
			Subsystem: "http",
			Name:      "requests_total",
			Help:      "Total number of HTTP requests processed",
		},
		[]string{"method", "path", "status"},
	)

	// HTTPRequestDuration tracks HTTP latency distributions
	HTTPRequestDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Namespace: "fikir",
			Subsystem: "http",
			Name:      "request_duration_seconds",
			Help:      "Duration of HTTP requests in seconds",
			Buckets:   []float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10},
		},
		[]string{"method", "path", "status"},
	)

	// DB Pool Metrics
	DBPoolTotalConns = promauto.NewGauge(
		prometheus.GaugeOpts{
			Namespace: "fikir",
			Subsystem: "db",
			Name:      "pool_total_connections",
			Help:      "Total connections currently in the database pool",
		},
	)

	DBPoolIdleConns = promauto.NewGauge(
		prometheus.GaugeOpts{
			Namespace: "fikir",
			Subsystem: "db",
			Name:      "pool_idle_connections",
			Help:      "Number of idle connections currently in the database pool",
		},
	)

	DBPoolAcquiredConns = promauto.NewGauge(
		prometheus.GaugeOpts{
			Namespace: "fikir",
			Subsystem: "db",
			Name:      "pool_acquired_connections",
			Help:      "Number of currently acquired connections in the database pool",
		},
	)

	DBPoolWaitDuration = promauto.NewCounter(
		prometheus.CounterOpts{
			Namespace: "fikir",
			Subsystem: "db",
			Name:      "pool_wait_duration_seconds_total",
			Help:      "Total time waited for a free connection in the database pool",
		},
	)

	// WebSocket Metrics
	WSActiveConnections = promauto.NewGauge(
		prometheus.GaugeOpts{
			Namespace: "fikir",
			Subsystem: "ws",
			Name:      "active_connections",
			Help:      "Number of currently active WebSocket client connections",
		},
	)

	// Queue Metrics
	QueueDepth = promauto.NewGaugeVec(
		prometheus.GaugeOpts{
			Namespace: "fikir",
			Subsystem: "queue",
			Name:      "depth",
			Help:      "Current depth of asynchronous task queue",
		},
		[]string{"queue"},
	)

	// Media Processing Metrics
	MediaProcessingDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Namespace: "fikir",
			Subsystem: "media",
			Name:      "processing_duration_seconds",
			Help:      "Duration of media processing and thumbnail generation in seconds",
			Buckets:   []float64{0.05, 0.1, 0.25, 0.5, 1, 2, 5, 10},
		},
		[]string{"operation"},
	)

	// Payment Metrics
	PaymentsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Namespace: "fikir",
			Subsystem: "payments",
			Name:      "processed_total",
			Help:      "Total payments initiated and processed",
		},
		[]string{"provider", "status"},
	)
)

// StartDBPoolMetricsCollector periodically samples pgx pool statistics
func StartDBPoolMetricsCollector(ctx context.Context, pool *pgxpool.Pool, interval time.Duration) {
	if pool == nil {
		return
	}

	ticker := time.NewTicker(interval)
	go func() {
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				stat := pool.Stat()
				DBPoolTotalConns.Set(float64(stat.TotalConns()))
				DBPoolIdleConns.Set(float64(stat.IdleConns()))
				DBPoolAcquiredConns.Set(float64(stat.AcquiredConns()))
				DBPoolWaitDuration.Add(stat.AcquireDuration().Seconds())
			}
		}
	}()
}
