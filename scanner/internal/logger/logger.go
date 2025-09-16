package logger

import (
	"os"
	"time"

	"github.com/sirupsen/logrus"
)

var Log *logrus.Logger

func init() {
	Log = logrus.New()

	// Set JSON formatter for structured logging (industry standard)
	Log.SetFormatter(&logrus.JSONFormatter{
		TimestampFormat: time.RFC3339,
		FieldMap: logrus.FieldMap{
			logrus.FieldKeyTime:  "timestamp",
			logrus.FieldKeyLevel: "level",
			logrus.FieldKeyMsg:   "message",
			logrus.FieldKeyFunc:  "caller",
		},
	})

	// Output to stdout (industry standard for containerized apps)
	Log.SetOutput(os.Stdout)

	// Set log level based on environment
	logLevel := os.Getenv("LOG_LEVEL")
	switch logLevel {
	case "debug", "DEBUG":
		Log.SetLevel(logrus.DebugLevel)
	case "info", "INFO":
		Log.SetLevel(logrus.InfoLevel)
	case "warn", "WARN", "warning", "WARNING":
		Log.SetLevel(logrus.WarnLevel)
	case "error", "ERROR":
		Log.SetLevel(logrus.ErrorLevel)
	default:
		Log.SetLevel(logrus.InfoLevel)
	}

	// Add service identifier
	Log = Log.WithField("service", "mediawarn-scanner").Logger

	// Report caller information for debugging
	Log.SetReportCaller(true)
}

// WithFields creates a logger with additional fields
func WithFields(fields logrus.Fields) *logrus.Entry {
	return Log.WithFields(fields)
}

// WithField creates a logger with a single additional field
func WithField(key string, value interface{}) *logrus.Entry {
	return Log.WithField(key, value)
}

// WithError creates a logger with error field
func WithError(err error) *logrus.Entry {
	return Log.WithError(err)
}

// LogStartup logs application startup information
func LogStartup(component, version string, config map[string]interface{}) {
	Log.WithFields(logrus.Fields{
		"component": component,
		"version":   version,
		"config":    config,
		"type":      "startup",
	}).Info("Service starting up")
}

// LogShutdown logs application shutdown
func LogShutdown(component string, reason string) {
	Log.WithFields(logrus.Fields{
		"component": component,
		"reason":    reason,
		"type":      "shutdown",
	}).Info("Service shutting down")
}

// LogScanOperation logs file scanning operations
func LogScanOperation(operation, filePath string, duration time.Duration, fileSize int64, err error) {
	fields := logrus.Fields{
		"operation":   operation,
		"file_path":   filePath,
		"file_size":   fileSize,
		"duration_ms": duration.Milliseconds(),
		"type":        "scan_operation",
	}

	if err != nil {
		Log.WithFields(fields).WithError(err).Error("Scan operation failed")
	} else {
		Log.WithFields(fields).Info("Scan operation completed")
	}
}

// LogQueueOperation logs queue operations (Redis)
func LogQueueOperation(operation, queueName string, count int, err error) {
	fields := logrus.Fields{
		"operation":  operation,
		"queue_name": queueName,
		"count":      count,
		"type":       "queue_operation",
	}

	if err != nil {
		Log.WithFields(fields).WithError(err).Error("Queue operation failed")
	} else {
		Log.WithFields(fields).Debug("Queue operation completed")
	}
}

// LogDatabase logs database operation details
func LogDatabase(operation, table string, duration time.Duration, rowsAffected int64, err error) {
	fields := logrus.Fields{
		"operation":     operation,
		"table":         table,
		"duration_ms":   duration.Milliseconds(),
		"rows_affected": rowsAffected,
		"type":          "database",
	}

	if err != nil {
		Log.WithFields(fields).WithError(err).Error("Database operation failed")
	} else {
		Log.WithFields(fields).Debug("Database operation completed")
	}
}

// LogFileSystemOperation logs filesystem operations
func LogFileSystemOperation(operation, path string, duration time.Duration, itemCount int, err error) {
	fields := logrus.Fields{
		"operation":   operation,
		"path":        path,
		"duration_ms": duration.Milliseconds(),
		"item_count":  itemCount,
		"type":        "filesystem",
	}

	if err != nil {
		Log.WithFields(fields).WithError(err).Error("Filesystem operation failed")
	} else {
		Log.WithFields(fields).Debug("Filesystem operation completed")
	}
}