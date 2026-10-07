package middleware

import (
	"net/http"

	chimw "github.com/go-chi/chi/v5/middleware"
)

// Compress returns gzip compression middleware
func Compress(level int) func(next http.Handler) http.Handler {
	return chimw.Compress(level)
}
