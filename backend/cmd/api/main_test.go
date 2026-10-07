package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHealthHandler(t *testing.T) {
	endpoints := []string{"/healthz", "/api/healthz"}

	for _, ep := range endpoints {
		t.Run(ep, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, ep, nil)
			rr := httptest.NewRecorder()

			healthHandler(rr, req)

			if rr.Code != http.StatusOK {
				t.Fatalf("expected status %d, got %d", http.StatusOK, rr.Code)
			}

			var resp HealthResponse
			if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
				t.Fatalf("failed to decode response: %v", err)
			}

			if resp.Status != "ok" {
				t.Errorf("expected status ok, got %s", resp.Status)
			}

			if resp.Service != "fikir-api" {
				t.Errorf("expected service fikir-api, got %s", resp.Service)
			}
		})
	}
}
