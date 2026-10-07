package main

import (
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	log.Println("Starting Fikir async worker service...")
	log.Println("Worker ready for background tasks (image processing, notifications, etc.).")

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)

	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			log.Println("Worker heartbeat - waiting for queue jobs...")
		case sig := <-stop:
			log.Printf("Received signal %s, shutting down worker gracefully...", sig)
			return
		}
	}
}
