package main

import (
	"context"
	"os"
	"os/signal"
	"syscall"
	"time"

	"scanner/internal/config"
	"scanner/internal/database"
	"scanner/internal/logger"
	"scanner/internal/queue"
	"scanner/internal/scanner"
)

func main() {
	// Log startup
	version := os.Getenv("APP_VERSION")
	if version == "" {
		version = "dev"
	}

	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		logger.WithError(err).Fatal("Failed to load configuration")
	}

	// Log startup configuration (without sensitive data)
	configLog := map[string]interface{}{
		"database_host": extractHost(cfg.DatabaseURL),
		"redis_host":    extractHost(cfg.RedisURL),
		"scan_interval": cfg.ScanInterval,
		"workers":       cfg.Workers,
		"log_level":     os.Getenv("LOG_LEVEL"),
	}
	logger.LogStartup("scanner", version, configLog)

	// Initialize database
	start := time.Now()
	db, err := database.Initialize(cfg.DatabaseURL)
	if err != nil {
		logger.WithError(err).Fatal("Failed to initialize database")
	}
	logger.WithField("duration_ms", time.Since(start).Milliseconds()).Info("Database connection established")

	// Initialize Redis queue
	start = time.Now()
	redisClient, err := queue.Initialize(cfg.RedisURL)
	if err != nil {
		logger.WithError(err).Fatal("Failed to initialize Redis")
	}
	logger.WithField("duration_ms", time.Since(start).Milliseconds()).Info("Redis connection established")

	// Initialize scanner
	scannerService := scanner.NewService(db, redisClient, cfg)

	// Create context for graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Start scanner in a goroutine
	go func() {
		if err := scannerService.Start(ctx); err != nil {
			logger.WithError(err).Error("Scanner service error")
		}
	}()

	// Wait for interrupt signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	logger.WithField("service", "scanner").Info("Scanner service started successfully")
	<-sigChan

	logger.LogShutdown("scanner", "user_interrupt")
	cancel()

	// Give some time for cleanup
	time.Sleep(2 * time.Second)
	logger.WithField("service", "scanner").Info("Scanner service stopped")
}

// extractHost extracts host from connection string for logging (removes credentials)
func extractHost(connStr string) string {
	// Simple extraction for logging - remove credentials
	if len(connStr) > 20 {
		return connStr[len(connStr)-20:]
	}
	return "localhost"
}