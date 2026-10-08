package cache

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	// CacheHitsTotal tracks the count of successful cache hits
	CacheHitsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Namespace: "fikir",
			Subsystem: "cache",
			Name:      "hits_total",
			Help:      "Total number of cache hits by cache type",
		},
		[]string{"type"},
	)

	// CacheMissesTotal tracks the count of cache misses
	CacheMissesTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Namespace: "fikir",
			Subsystem: "cache",
			Name:      "misses_total",
			Help:      "Total number of cache misses by cache type",
		},
		[]string{"type"},
	)

	// DeckPopsTotal tracks candidate deck pops
	DeckPopsTotal = promauto.NewCounter(
		prometheus.CounterOpts{
			Namespace: "fikir",
			Subsystem: "discovery",
			Name:      "deck_pops_total",
			Help:      "Total number of discovery deck pop operations",
		},
	)

	// DeckRefillsTotal tracks how many times discovery decks were refilled
	DeckRefillsTotal = promauto.NewCounter(
		prometheus.CounterOpts{
			Namespace: "fikir",
			Subsystem: "discovery",
			Name:      "deck_refills_total",
			Help:      "Total number of candidate deck refill operations",
		},
	)

	// SwipesProcessedTotal tracks swipe operations by direction
	SwipesProcessedTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Namespace: "fikir",
			Subsystem: "swipes",
			Name:      "processed_total",
			Help:      "Total number of swipe actions processed",
		},
		[]string{"direction"},
	)

	// MatchesCreatedTotal tracks successful mutual matches
	MatchesCreatedTotal = promauto.NewCounter(
		prometheus.CounterOpts{
			Namespace: "fikir",
			Subsystem: "matches",
			Name:      "created_total",
			Help:      "Total number of mutual matches formed",
		},
	)
)

func RecordCacheHit(cacheType string) {
	CacheHitsTotal.WithLabelValues(cacheType).Inc()
}

func RecordCacheMiss(cacheType string) {
	CacheMissesTotal.WithLabelValues(cacheType).Inc()
}
