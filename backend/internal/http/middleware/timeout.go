package middleware

import (
	"net/http"
	"time"

	chimw "github.com/go-chi/chi/v5/middleware"
)

// Timeout returns request timeout middleware
func Timeout(d time.Duration) func(next http.Handler) http.Handler {
	return chimw.Timeout(d)
}
