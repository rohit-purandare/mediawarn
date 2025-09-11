package middleware

import (
	"github.com/gin-gonic/gin"
	"github.com/go-redis/redis/v8"
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