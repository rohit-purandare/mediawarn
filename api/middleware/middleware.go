package middleware

import (
	"api/logger"

	"github.com/gin-gonic/gin"
	"github.com/go-redis/redis/v8"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

func Database(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Set("db", db)
		c.Next()
	}
}

func Redis(rdb *redis.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Set("redis", rdb)
		c.Next()
	}
}

// RequestLogging provides structured HTTP request logging
func RequestLogging() gin.HandlerFunc {
	return gin.LoggerWithFormatter(func(param gin.LogFormatterParams) string {
		// Generate request ID for tracing
		requestID := uuid.New().String()

		// Log structured request info
		logger.LogRequest(
			param.Method,
			param.Path,
			param.Request.UserAgent(),
			param.ClientIP,
			param.StatusCode,
			param.Latency,
		)

		// Store request ID in context for downstream handlers
		param.Keys["request_id"] = requestID

		return "" // Return empty string to prevent default Gin logging
	})
}

// RequestID middleware adds request ID to context
func RequestID() gin.HandlerFunc {
	return func(c *gin.Context) {
		requestID := uuid.New().String()
		c.Set("request_id", requestID)
		c.Header("X-Request-ID", requestID)
		c.Next()
	}
}

// ErrorLogging middleware logs errors with structured format
func ErrorLogging() gin.HandlerFunc {
	return gin.CustomRecovery(func(c *gin.Context, recovered interface{}) {
		requestID, _ := c.Get("request_id")

		logger.WithFields(logger.WithField("request_id", requestID).Data).
			WithField("panic", recovered).
			WithField("path", c.Request.URL.Path).
			WithField("method", c.Request.Method).
			Error("Panic recovered")

		c.AbortWithStatus(500)
	})
}