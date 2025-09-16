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
	Log = Log.WithField("service", "mediawarn-api").Logger

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

// WithRequestID creates a logger with request ID for tracing
func WithRequestID(requestID string) *logrus.Entry {
	return Log.WithField("request_id", requestID)
}

// LogRequest logs HTTP request details
func LogRequest(method, path, userAgent, clientIP string, statusCode int, duration time.Duration) {
	Log.WithFields(logrus.Fields{
		"method":      method,
		"path":        path,
		"user_agent":  userAgent,
		"client_ip":   clientIP,
		"status_code": statusCode,
		"duration_ms": duration.Milliseconds(),
		"type":        "http_request",
	}).Info("HTTP request completed")
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

// LogRedis logs Redis operation details
func LogRedis(operation, key string, duration time.Duration, err error) {
	fields := logrus.Fields{
		"operation":   operation,
		"key":         key,
		"duration_ms": duration.Milliseconds(),
		"type":        "redis",
	}

	if err != nil {
		Log.WithFields(fields).WithError(err).Error("Redis operation failed")
	} else {
		Log.WithFields(fields).Debug("Redis operation completed")
	}
}

// LogStartup logs application startup information
func LogStartup(component, version, port string, config map[string]interface{}) {
	Log.WithFields(logrus.Fields{
		"component": component,
		"version":   version,
		"port":      port,
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