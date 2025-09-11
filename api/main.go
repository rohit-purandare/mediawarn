package main

import (
	"log"
	"os"

	"api/handlers"
	"api/middleware"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/go-redis/redis/v8"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

type File struct {
	ID           uint      `gorm:"primaryKey" json:"id"`
	Path         string    `gorm:"unique;not null" json:"path"`
	Filename     string    `gorm:"not null" json:"filename"`
	FileType     string    `gorm:"size:10" json:"file_type"`
	FileSize     int64     `json:"file_size"`
	FileHash     string    `gorm:"size:64" json:"file_hash"`
	LastModified string    `json:"last_modified"`
	LastScanned  *string   `json:"last_scanned"`
	ScanStatus   string    `gorm:"size:20;default:pending" json:"scan_status"`
	CreatedAt    string    `json:"created_at"`
}

type ScanResult struct {
	ID               uint    `gorm:"primaryKey" json:"id"`
	FileID           uint    `json:"file_id"`
	File             File    `gorm:"foreignKey:FileID" json:"file,omitempty"`
	ScanDate         string  `json:"scan_date"`
	ModelVersion     string  `gorm:"size:50" json:"model_version"`
	ProcessingTimeMs int     `json:"processing_time_ms"`
	OverallRiskScore float64 `json:"overall_risk_score"`
	HighestSeverity  string  `gorm:"size:20" json:"highest_severity"`
	TotalTriggers    int     `gorm:"default:0" json:"total_triggers"`
	Metadata         string  `gorm:"type:jsonb" json:"metadata"`
	CreatedAt        string  `json:"created_at"`
	Triggers         []Trigger `gorm:"foreignKey:ScanResultID" json:"triggers,omitempty"`
}

type Trigger struct {
	ID             uint    `gorm:"primaryKey" json:"id"`
	ScanResultID   uint    `json:"scan_result_id"`
	Category       string  `gorm:"size:50" json:"category"`
	Severity       string  `gorm:"size:20" json:"severity"`
	ConfidenceScore float64 `json:"confidence_score"`
	TimestampStart string  `gorm:"type:time" json:"timestamp_start"`
	TimestampEnd   string  `gorm:"type:time" json:"timestamp_end"`
	SubtitleText   string  `json:"subtitle_text"`
	ContextBefore  string  `json:"context_before"`
	ContextAfter   string  `json:"context_after"`
	CreatedAt      string  `json:"created_at"`
}

type UserPreference struct {
	ID          uint   `gorm:"primaryKey" json:"id"`
	ProfileName string `gorm:"size:100;unique" json:"profile_name"`
	Settings    string `gorm:"type:jsonb" json:"settings"`
	IsActive    bool   `gorm:"default:false" json:"is_active"`
	CreatedAt   string `json:"created_at"`
	UpdatedAt   string `json:"updated_at"`
}

type ScanFolder struct {
	ID        uint   `gorm:"primaryKey" json:"id"`
	Path      string `gorm:"unique;not null" json:"path"`
	IsActive  bool   `gorm:"default:true" json:"is_active"`
	Priority  int    `gorm:"default:1" json:"priority"`
	CreatedAt string `json:"created_at"`
}

type NLPModel struct {
	ID              uint     `gorm:"primaryKey" json:"id"`
	Name            string   `gorm:"size:200;not null" json:"name"`
	HuggingfaceID   string   `gorm:"size:500;not null" json:"huggingface_id"`
	TaskType        string   `gorm:"size:100;not null;default:text-classification" json:"task_type"`
	Categories      string   `gorm:"type:text[]" json:"categories"` // PostgreSQL array as string
	Weight          float64  `gorm:"not null;default:1.0" json:"weight"`
	IsActive        bool     `gorm:"default:true" json:"is_active"`
	IsCustom        bool     `gorm:"default:false" json:"is_custom"`
	ModelConfig     string   `gorm:"type:jsonb" json:"model_config"`
	Status          string   `gorm:"size:50;default:pending" json:"status"`
	ErrorMessage    *string  `json:"error_message"`
	DownloadProgress int     `gorm:"default:0" json:"download_progress"`
	CreatedAt       string   `json:"created_at"`
	UpdatedAt       string   `json:"updated_at"`
}

type ModelCategory struct {
	ID              uint   `gorm:"primaryKey" json:"id"`
	CategoryName    string `gorm:"size:100;unique;not null" json:"category_name"`
	DisplayName     string `gorm:"size:200;not null" json:"display_name"`
	Description     string `json:"description"`
	DefaultThreshold float64 `gorm:"default:0.7" json:"default_threshold"`
	SeverityMapping string `gorm:"type:jsonb" json:"severity_mapping"`
	IsActive        bool   `gorm:"default:true" json:"is_active"`
	CreatedAt       string `json:"created_at"`
}

func main() {
	// Get database and Redis URLs from environment
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		databaseURL = "postgresql://cws:password@localhost:5432/cws"
	}

	redisURL := os.Getenv("REDIS_URL")
	if redisURL == "" {
		redisURL = "redis://localhost:6379"
	}

	// Initialize database connection
	db, err := gorm.Open(postgres.Open(databaseURL), &gorm.Config{})
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	// Auto migrate the schema
	db.AutoMigrate(&File{}, &ScanResult{}, &Trigger{}, &UserPreference{}, &ScanFolder{}, &NLPModel{}, &ModelCategory{})

	// Initialize Redis connection
	opt, err := redis.ParseURL(redisURL)
	if err != nil {
		log.Fatalf("Failed to parse Redis URL: %v", err)
	}
	rdb := redis.NewClient(opt)

	// Test Redis connection
	if err := rdb.Ping(rdb.Context()).Err(); err != nil {
		log.Fatalf("Failed to connect to Redis: %v", err)
	}

	// Set up Gin
	if os.Getenv("GIN_MODE") == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	r := gin.Default()

	// Configure CORS
	config := cors.DefaultConfig()
	config.AllowOrigins = []string{"http://localhost:7219", "http://frontend:7219"}
	config.AllowMethods = []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"}
	config.AllowHeaders = []string{"Origin", "Content-Type", "Authorization"}
	r.Use(cors.New(config))

	// Add middleware
	r.Use(middleware.Database(db))
	r.Use(middleware.Redis(rdb))

	// Health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "healthy", "service": "api"})
	})

	// API routes
	api := r.Group("/api")
	{
		// Scanner control
		scan := api.Group("/scan")
		{
			scan.POST("/start", handlers.StartScan)
			scan.POST("/stop", handlers.StopScan)
			scan.GET("/status", handlers.GetScanStatus)
			scan.POST("/folder", handlers.AddScanFolder)
			scan.DELETE("/folder/:id", handlers.RemoveScanFolder)
			scan.GET("/folders", handlers.GetScanFolders)
		}

		// Results
		results := api.Group("/results")
		{
			results.GET("", handlers.GetResults)
			results.GET("/:file_id", handlers.GetFileResult)
			results.POST("/:file_id/rescan", handlers.TriggerRescan)
			results.PUT("/:file_id/override", handlers.OverrideResult)
		}

		// Triggers
		triggers := api.Group("/triggers")
		{
			triggers.GET("/:file_id", handlers.GetFileTriggers)
			triggers.PUT("/:trigger_id", handlers.UpdateTrigger)
		}

		// Preferences
		preferences := api.Group("/preferences")
		{
			preferences.GET("", handlers.GetPreferences)
			preferences.GET("/:profile", handlers.GetPreference)
			preferences.POST("", handlers.CreatePreference)
			preferences.PUT("/:profile", handlers.UpdatePreference)
			preferences.DELETE("/:profile", handlers.DeletePreference)
		}

		// Statistics
		stats := api.Group("/stats")
		{
			stats.GET("/overview", handlers.GetOverviewStats)
			stats.GET("/categories", handlers.GetCategoryStats)
			stats.GET("/timeline", handlers.GetTimelineStats)
		}

		// Model Management
		models := api.Group("/models")
		{
			models.GET("", handlers.GetModels)
			models.GET("/categories", handlers.GetModelCategories)
			models.POST("", handlers.AddCustomModel)
			models.PUT("/:model_id", handlers.UpdateModel)
			models.DELETE("/:model_id", handlers.RemoveModel)
			models.POST("/:model_id/reload", handlers.ReloadModel)
			models.GET("/:model_id/status", handlers.GetModelStatus)
		}
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8000"
	}

	log.Printf("Starting API server on port %s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}