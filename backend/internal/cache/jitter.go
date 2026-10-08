package cache

import (
	"math/rand/v2"
	"time"
)

// Jitter returns a duration with a random jitter between -percent and +percent.
// For example, base=10m, percent=0.2 returns between 8m and 12m.
func Jitter(base time.Duration, percent float64) time.Duration {
	if percent <= 0 || percent >= 1.0 {
		percent = 0.15 // default 15% jitter
	}
	// Factor in [-percent, +percent]
	delta := (rand.Float64()*2.0 - 1.0) * percent
	jittered := float64(base) * (1.0 + delta)
	return time.Duration(jittered)
}
