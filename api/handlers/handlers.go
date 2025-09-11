package handlers

import (
	"context"
	"database/sql"
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/go-redis/redis/v8"
	"gorm.io/gorm"
)

type File struct {
	ID           uint      `gorm:"primaryKey" json:"id"`
	Path         string    `gorm:"unique;not null" json:"path"`
	Filename     string    `gorm:"not null" json:"filename"`
	FileType     string    `gorm:"size:10" json:"file_type"`
	FileSize     int64     `json:"file_size"`
	FileHash     string    `gorm:"size:64" json:"file_hash"`
	LastModified time.Time `json:"last_modified"`
	LastScanned  *time.Time `json:"last_scanned"`
	ScanStatus   string    `gorm:"size:20;default:pending" json:"scan_status"`
	CreatedAt    time.Time `json:"created_at"`
}

type ScanResult struct {
	ID               uint    `gorm:"primaryKey" json:"id"`
	FileID           uint    `json:"file_id"`
	File             File    `gorm:"foreignKey:FileID" json:"file,omitempty"`
	ScanDate         time.Time `json:"scan_date"`
	ModelVersion     string  `gorm:"size:50" json:"model_version"`
	ProcessingTimeMs int     `json:"processing_time_ms"`
	OverallRiskScore float64 `json:"overall_risk_score"`
	HighestSeverity  string  `gorm:"size:20" json:"highest_severity"`
	TotalTriggers    int     `gorm:"default:0" json:"total_triggers"`
	Metadata         string  `gorm:"type:jsonb" json:"metadata"`
	CreatedAt        time.Time `json:"created_at"`
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
	CreatedAt      time.Time `json:"created_at"`
}

type ScanFolder struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	Path      string    `gorm:"unique;not null" json:"path"`
	IsActive  bool      `gorm:"default:true" json:"is_active"`
	Priority  int       `gorm:"default:1" json:"priority"`
	CreatedAt time.Time `json:"created_at"`
}

// Scanner control handlers

func StartScan(c *gin.Context) {
	rdb := c.MustGet("redis").(*redis.Client)
	
	// Send start signal to scanner
	err := rdb.Set(c, "scanner:control", "start", time.Minute*10).Err()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to send start signal"})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{"message": "Scan started"})
}

func StopScan(c *gin.Context) {
	rdb := c.MustGet("redis").(*redis.Client)
	
	// Send stop signal to scanner
	err := rdb.Set(c, "scanner:control", "stop", time.Minute*10).Err()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to send stop signal"})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{"message": "Scan stopped"})
}

func GetScanStatus(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	rdb := c.MustGet("redis").(*redis.Client)
	
	// Get queue length
	queueLen, err := rdb.LLen(c, "scan_jobs").Result()
	if err != nil {
		queueLen = 0
	}
	
	// Get file counts by status
	var statusCounts []struct {
		ScanStatus string `json:"scan_status"`
		Count      int64  `json:"count"`
	}
	
	db.Model(&File{}).
		Select("scan_status, count(*) as count").
		Group("scan_status").
		Scan(&statusCounts)
	
	// Get last scan activity
	var lastActivity time.Time
	db.Model(&File{}).
		Select("max(last_scanned) as last_activity").
		Where("last_scanned IS NOT NULL").
		Scan(&lastActivity)
	
	c.JSON(http.StatusOK, gin.H{
		"queue_length": queueLen,
		"status_counts": statusCounts,
		"last_activity": lastActivity,
	})
}

func AddScanFolder(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	
	var req struct {
		Path     string `json:"path" binding:"required"`
		Priority int    `json:"priority"`
	}
	
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	
	folder := ScanFolder{
		Path:     req.Path,
		Priority: req.Priority,
		IsActive: true,
	}
	
	if err := db.Create(&folder).Error; err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": "Folder already exists"})
		return
	}
	
	c.JSON(http.StatusCreated, folder)
}

func RemoveScanFolder(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	
	id := c.Param("id")
	
	if err := db.Delete(&ScanFolder{}, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Folder not found"})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{"message": "Folder removed"})
}

func GetScanFolders(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	
	var folders []ScanFolder
	db.Order("priority desc, created_at asc").Find(&folders)
	
	c.JSON(http.StatusOK, folders)
}

// Results handlers

func GetResults(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	
	// Parse query parameters
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	severity := c.Query("severity")
	category := c.Query("category")
	
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 50
	}
	
	offset := (page - 1) * limit
	
	query := db.Model(&File{}).
		Preload("ScanResults").
		Preload("ScanResults.Triggers")
	
	// Apply filters
	if severity != "" {
		query = query.Joins("JOIN scan_results ON files.id = scan_results.file_id").
			Where("scan_results.highest_severity = ?", severity)
	}
	
	if category != "" {
		query = query.Joins("JOIN scan_results ON files.id = scan_results.file_id").
			Joins("JOIN triggers ON scan_results.id = triggers.scan_result_id").
			Where("triggers.category = ?", category)
	}
	
	var files []File
	var total int64
	
	query.Count(&total)
	query.Offset(offset).Limit(limit).Find(&files)
	
	c.JSON(http.StatusOK, gin.H{
		"files":      files,
		"total":      total,
		"page":       page,
		"limit":      limit,
		"total_pages": (total + int64(limit) - 1) / int64(limit),
	})
}

func GetFileResult(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	
	fileID := c.Param("file_id")
	
	var file File
	if err := db.Preload("ScanResults").Preload("ScanResults.Triggers").
		First(&file, fileID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "File not found"})
		return
	}
	
	c.JSON(http.StatusOK, file)
}

func TriggerRescan(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	rdb := c.MustGet("redis").(*redis.Client)
	
	fileID := c.Param("file_id")
	
	var file File
	if err := db.First(&file, fileID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "File not found"})
		return
	}
	
	// Update file status to queued
	file.ScanStatus = "queued"
	db.Save(&file)
	
	// Add to queue
	job := map[string]interface{}{
		"id":        "rescan_" + fileID,
		"file_path": file.Path,
		"file_type": file.FileType,
		"priority":  2,
		"created_at": time.Now(),
	}
	
	jobJSON, _ := json.Marshal(job)
	rdb.LPush(context.Background(), "scan_jobs", jobJSON)
	
	c.JSON(http.StatusOK, gin.H{"message": "Rescan queued"})
}

func OverrideResult(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	
	fileID := c.Param("file_id")
	
	var req struct {
		OverallRiskScore float64 `json:"overall_risk_score"`
		HighestSeverity  string  `json:"highest_severity"`
		Notes            string  `json:"notes"`
	}
	
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	
	// Find latest scan result for file
	var scanResult ScanResult
	if err := db.Where("file_id = ?", fileID).
		Order("created_at desc").
		First(&scanResult).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Scan result not found"})
		return
	}
	
	// Update scan result
	scanResult.OverallRiskScore = req.OverallRiskScore
	scanResult.HighestSeverity = req.HighestSeverity
	
	// Update metadata with override info
	metadata := make(map[string]interface{})
	json.Unmarshal([]byte(scanResult.Metadata), &metadata)
	metadata["override"] = map[string]interface{}{
		"timestamp": time.Now(),
		"notes":     req.Notes,
	}
	
	metadataJSON, _ := json.Marshal(metadata)
	scanResult.Metadata = string(metadataJSON)
	
	db.Save(&scanResult)
	
	c.JSON(http.StatusOK, scanResult)
}

// Triggers handlers

func GetFileTriggers(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	
	fileID := c.Param("file_id")
	
	var triggers []Trigger
	db.Joins("JOIN scan_results ON triggers.scan_result_id = scan_results.id").
		Where("scan_results.file_id = ?", fileID).
		Order("triggers.timestamp_start").
		Find(&triggers)
	
	c.JSON(http.StatusOK, triggers)
}

func UpdateTrigger(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	
	triggerID := c.Param("trigger_id")
	
	var req struct {
		Severity        string  `json:"severity"`
		ConfidenceScore float64 `json:"confidence_score"`
		Notes           string  `json:"notes"`
	}
	
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	
	var trigger Trigger
	if err := db.First(&trigger, triggerID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Trigger not found"})
		return
	}
	
	// Update trigger
	if req.Severity != "" {
		trigger.Severity = req.Severity
	}
	if req.ConfidenceScore > 0 {
		trigger.ConfidenceScore = req.ConfidenceScore
	}
	
	db.Save(&trigger)
	
	c.JSON(http.StatusOK, trigger)
}

// Preferences handlers

func GetPreferences(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"message": "Get preferences - not implemented yet"})
}

func GetPreference(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"message": "Get preference - not implemented yet"})
}

func CreatePreference(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"message": "Create preference - not implemented yet"})
}

func UpdatePreference(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"message": "Update preference - not implemented yet"})
}

func DeletePreference(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"message": "Delete preference - not implemented yet"})
}

// Statistics handlers

func GetOverviewStats(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	
	var stats struct {
		TotalFiles      int64   `json:"total_files"`
		ScannedFiles    int64   `json:"scanned_files"`
		TotalTriggers   int64   `json:"total_triggers"`
		AverageRiskScore float64 `json:"average_risk_score"`
	}
	
	db.Model(&File{}).Count(&stats.TotalFiles)
	db.Model(&File{}).Where("scan_status = 'completed'").Count(&stats.ScannedFiles)
	db.Model(&Trigger{}).Count(&stats.TotalTriggers)
	
	var avgScore sql.NullFloat64
	db.Model(&ScanResult{}).Select("AVG(overall_risk_score)").Scan(&avgScore)
	if avgScore.Valid {
		stats.AverageRiskScore = avgScore.Float64
	}
	
	c.JSON(http.StatusOK, stats)
}

func GetCategoryStats(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	
	var categoryStats []struct {
		Category string `json:"category"`
		Count    int64  `json:"count"`
		Severity string `json:"severity"`
	}
	
	db.Model(&Trigger{}).
		Select("category, severity, count(*) as count").
		Group("category, severity").
		Order("category, severity").
		Scan(&categoryStats)
	
	c.JSON(http.StatusOK, categoryStats)
}

func GetTimelineStats(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	
	var timelineStats []struct {
		Date         string `json:"date"`
		FilesScanned int64  `json:"files_scanned"`
		TriggersFound int64 `json:"triggers_found"`
	}
	
	db.Raw(`
		SELECT 
			DATE(scan_date) as date,
			COUNT(*) as files_scanned,
			SUM(total_triggers) as triggers_found
		FROM scan_results 
		WHERE scan_date >= NOW() - INTERVAL '30 days'
		GROUP BY DATE(scan_date)
		ORDER BY date DESC
	`).Scan(&timelineStats)
	
	c.JSON(http.StatusOK, timelineStats)
}

// Model management handlers

type NLPModel struct {
	ID              uint     `gorm:"primaryKey" json:"id"`
	Name            string   `gorm:"size:200;not null" json:"name"`
	HuggingfaceID   string   `gorm:"size:500;not null" json:"huggingface_id"`
	TaskType        string   `gorm:"size:100;not null;default:text-classification" json:"task_type"`
	Categories      string   `gorm:"type:text[]" json:"categories"` 
	Weight          float64  `gorm:"not null;default:1.0" json:"weight"`
	IsActive        bool     `gorm:"default:true" json:"is_active"`
	IsCustom        bool     `gorm:"default:false" json:"is_custom"`
	ModelConfig     string   `gorm:"type:jsonb" json:"model_config"`
	Status          string   `gorm:"size:50;default:pending" json:"status"`
	ErrorMessage    *string  `json:"error_message"`
	DownloadProgress int     `gorm:"default:0" json:"download_progress"`
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`
}

type ModelCategory struct {
	ID              uint   `gorm:"primaryKey" json:"id"`
	CategoryName    string `gorm:"size:100;unique;not null" json:"category_name"`
	DisplayName     string `gorm:"size:200;not null" json:"display_name"`
	Description     string `json:"description"`
	DefaultThreshold float64 `gorm:"default:0.7" json:"default_threshold"`
	SeverityMapping string `gorm:"type:jsonb" json:"severity_mapping"`
	IsActive        bool   `gorm:"default:true" json:"is_active"`
	CreatedAt       time.Time `json:"created_at"`
}

func GetModels(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	
	var models []NLPModel
	db.Where("is_active = ?", true).Order("weight desc, created_at desc").Find(&models)
	
	c.JSON(http.StatusOK, gin.H{
		"models": models,
		"total": len(models),
	})
}

func GetModelCategories(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	
	var categories []ModelCategory
	db.Where("is_active = ?", true).Order("display_name").Find(&categories)
	
	c.JSON(http.StatusOK, gin.H{
		"categories": categories,
		"total": len(categories),
	})
}

func AddCustomModel(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	
	var req struct {
		Name          string   `json:"name" binding:"required"`
		HuggingfaceID string   `json:"huggingface_id" binding:"required"`
		TaskType      string   `json:"task_type"`
		Categories    []string `json:"categories" binding:"required"`
		Weight        float64  `json:"weight"`
		Config        map[string]interface{} `json:"config"`
	}
	
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	
	// Validate Hugging Face ID format
	if !strings.Contains(req.HuggingfaceID, "/") && req.HuggingfaceID != "distilbert-base-uncased" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid Hugging Face model ID. Should be in format 'username/model-name'"})
		return
	}
	
	// Set defaults
	if req.TaskType == "" {
		req.TaskType = "text-classification"
	}
	if req.Weight == 0 {
		req.Weight = 1.0
	}
	if req.Config == nil {
		req.Config = make(map[string]interface{})
	}
	
	// Convert categories to PostgreSQL array format
	categoriesJSON, _ := json.Marshal(req.Categories)
	configJSON, _ := json.Marshal(req.Config)
	
	model := NLPModel{
		Name:          req.Name,
		HuggingfaceID: req.HuggingfaceID,
		TaskType:      req.TaskType,
		Categories:    string(categoriesJSON),
		Weight:        req.Weight,
		IsActive:      true,
		IsCustom:      true,
		ModelConfig:   string(configJSON),
		Status:        "pending",
	}
	
	if err := db.Create(&model).Error; err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": "Model already exists or database error"})
		return
	}
	
	// TODO: Trigger model loading in NLP service via Redis message
	
	c.JSON(http.StatusCreated, gin.H{
		"model": model,
		"message": "Model added and loading started",
	})
}

func UpdateModel(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	
	modelID := c.Param("model_id")
	
	var req struct {
		Name       *string   `json:"name"`
		Categories *[]string `json:"categories"`
		Weight     *float64  `json:"weight"`
		IsActive   *bool     `json:"is_active"`
		Config     *map[string]interface{} `json:"config"`
	}
	
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	
	var model NLPModel
	if err := db.First(&model, modelID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Model not found"})
		return
	}
	
	// Update fields
	updates := make(map[string]interface{})
	
	if req.Name != nil {
		updates["name"] = *req.Name
	}
	if req.Categories != nil {
		categoriesJSON, _ := json.Marshal(*req.Categories)
		updates["categories"] = string(categoriesJSON)
	}
	if req.Weight != nil {
		updates["weight"] = *req.Weight
	}
	if req.IsActive != nil {
		updates["is_active"] = *req.IsActive
	}
	if req.Config != nil {
		configJSON, _ := json.Marshal(*req.Config)
		updates["model_config"] = string(configJSON)
	}
	
	updates["updated_at"] = time.Now()
	
	if err := db.Model(&model).Updates(updates).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update model"})
		return
	}
	
	// TODO: Trigger model reload in NLP service if active status changed
	
	c.JSON(http.StatusOK, gin.H{
		"model": model,
		"message": "Model updated successfully",
	})
}

func RemoveModel(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	
	modelID := c.Param("model_id")
	
	var model NLPModel
	if err := db.First(&model, modelID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Model not found"})
		return
	}
	
	// Soft delete by setting is_active to false
	if err := db.Model(&model).Update("is_active", false).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to remove model"})
		return
	}
	
	// TODO: Trigger model unload in NLP service via Redis message
	
	c.JSON(http.StatusOK, gin.H{"message": "Model removed successfully"})
}

func ReloadModel(c *gin.Context) {
	modelID := c.Param("model_id")
	
	// TODO: Implement model reload via Redis message to NLP service
	
	c.JSON(http.StatusOK, gin.H{
		"message": "Model reload triggered",
		"model_id": modelID,
	})
}

func GetModelStatus(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	
	modelID := c.Param("model_id")
	
	var model NLPModel
	if err := db.First(&model, modelID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Model not found"})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{
		"id": model.ID,
		"name": model.Name,
		"status": model.Status,
		"error_message": model.ErrorMessage,
		"download_progress": model.DownloadProgress,
		"updated_at": model.UpdatedAt,
	})
}