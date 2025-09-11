package database

import (
	"os"
	"time"

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
	LastModified time.Time `json:"last_modified"`
	LastScanned  *time.Time `json:"last_scanned"`
	ScanStatus   string    `gorm:"size:20;default:pending" json:"scan_status"`
	CreatedAt    time.Time `json:"created_at"`
}

type ScanResult struct {
	ID               uint    `gorm:"primaryKey" json:"id"`
	FileID           uint    `json:"file_id"`
	File             File    `gorm:"foreignKey:FileID" json:"file,omitempty"`
	ScanDate         time.Time `gorm:"default:CURRENT_TIMESTAMP" json:"scan_date"`
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
	ID             uint      `gorm:"primaryKey" json:"id"`
	ScanResultID   uint      `json:"scan_result_id"`
	Category       string    `gorm:"size:50" json:"category"`
	Severity       string    `gorm:"size:20" json:"severity"`
	ConfidenceScore float64  `json:"confidence_score"`
	TimestampStart string    `gorm:"type:time" json:"timestamp_start"`
	TimestampEnd   string    `gorm:"type:time" json:"timestamp_end"`
	SubtitleText   string    `json:"subtitle_text"`
	ContextBefore  string    `json:"context_before"`
	ContextAfter   string    `json:"context_after"`
	CreatedAt      time.Time `json:"created_at"`
}

type UserPreference struct {
	ID          uint      `gorm:"primaryKey" json:"id"`
	ProfileName string    `gorm:"size:100;unique" json:"profile_name"`
	Settings    string    `gorm:"type:jsonb" json:"settings"`
	IsActive    bool      `gorm:"default:false" json:"is_active"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type ScanFolder struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	Path      string    `gorm:"unique;not null" json:"path"`
	IsActive  bool      `gorm:"default:true" json:"is_active"`
	Priority  int       `gorm:"default:1" json:"priority"`
	CreatedAt time.Time `json:"created_at"`
}

func Initialize(databaseURL string) (*gorm.DB, error) {
	db, err := gorm.Open(postgres.Open(databaseURL), &gorm.Config{})
	if err != nil {
		return nil, err
	}

	// Auto migrate the schema
	err = db.AutoMigrate(&File{}, &ScanResult{}, &Trigger{}, &UserPreference{}, &ScanFolder{})
	if err != nil {
		return nil, err
	}

	// Scan folders are managed entirely through the web interface
	// No automatic initialization - users must add folders via frontend

	return db, nil
}