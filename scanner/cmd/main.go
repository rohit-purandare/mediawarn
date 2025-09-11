package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"scanner/internal/config"
	"scanner/internal/database"
	"scanner/internal/queue"
	"scanner/internal/scanner"
)

func main() {
	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Initialize database
	db, err := database.Initialize(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}

	// Initialize Redis queue
	redisClient, err := queue.Initialize(cfg.RedisURL)
	if err != nil {
		log.Fatalf("Failed to initialize Redis: %v", err)
	}

	// Initialize scanner
	scannerService := scanner.NewService(db, redisClient, cfg)

	// Create context for graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Start scanner in a goroutine
	go func() {
		if err := scannerService.Start(ctx); err != nil {
			log.Printf("Scanner error: %v", err)
		}
	}()

	// Wait for interrupt signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	log.Println("Scanner service started. Press Ctrl+C to exit.")
	<-sigChan

	log.Println("Shutting down scanner service...")
	cancel()

	// Give some time for cleanup
	time.Sleep(2 * time.Second)
	log.Println("Scanner service stopped.")
}