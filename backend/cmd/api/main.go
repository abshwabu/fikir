package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

type HealthResponse struct {
	Status    string    `json:"status"`
	Service   string    `json:"service"`
	Timestamp time.Time `json:"timestamp"`
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(HealthResponse{
		Status:    "ok",
		Service:   "fikir-api",
		Timestamp: time.Now().UTC(),
	}); err != nil {
		log.Printf("Error encoding health response: %v", err)
	}
}

func wsHandler(w http.ResponseWriter, r *http.Request) {
	if r.Header.Get("Upgrade") != "" {
		w.Header().Set("Upgrade", "websocket")
		w.Header().Set("Connection", "Upgrade")
		w.WriteHeader(http.StatusSwitchingProtocols)
		return
	}
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("WebSocket gateway placeholder"))
}

func main() {
	port := os.Getenv("APP_PORT")
	if port == "" {
		port = "8080"
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", healthHandler)
	mux.HandleFunc("/api/healthz", healthHandler)
	mux.HandleFunc("/ws", wsHandler)

	server := &http.Server{
		Addr:         ":" + port,
		Handler:      mux,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)

	go func() {
		log.Printf("Fikir API server starting on port %s...", port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server startup failed: %v", err)
		}
	}()

	<-stop
	log.Println("Shutting down API server gracefully...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("API server stopped")
}
