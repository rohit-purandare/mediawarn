package scanner

import (
	"context"
	"crypto/md5"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"

	"scanner/internal/config"
	"scanner/internal/database"
	"scanner/internal/queue"

	"gorm.io/gorm"
)

type Service struct {
	db     *gorm.DB
	queue  *queue.Client
	config *config.Config
}

func NewService(db *gorm.DB, queueClient *queue.Client, cfg *config.Config) *Service {
	return &Service{
		db:     db,
		queue:  queueClient,
		config: cfg,
	}
}

func (s *Service) Start(ctx context.Context) error {
	log.Println("Starting scanner service...")
	
	ticker := time.NewTicker(time.Duration(s.config.ScanInterval) * time.Second)
	defer ticker.Stop()

	// Initial scan
	if err := s.scanDirectories(ctx); err != nil {
		log.Printf("Initial scan error: %v", err)
	}

	for {
		select {
		case <-ctx.Done():
			log.Println("Scanner service shutting down...")
			return nil
		case <-ticker.C:
			if err := s.scanDirectories(ctx); err != nil {
				log.Printf("Scan error: %v", err)
			}
		}
	}
}

func (s *Service) scanDirectories(ctx context.Context) error {
	log.Println("Starting directory scan...")
	startTime := time.Now()
	fileCount := 0
	newFiles := 0

	// Get scan paths from database first, fallback to config
	scanPaths := s.getScanPaths()
	
	for _, scanPath := range scanPaths {
		if _, err := os.Stat(scanPath); os.IsNotExist(err) {
			log.Printf("Scan path does not exist: %s", scanPath)
			continue
		}

		err := filepath.Walk(scanPath, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}

			select {
			case <-ctx.Done():
				return ctx.Err()
			default:
			}

			if info.IsDir() {
				return nil
			}

			fileCount++

			// Check if file matches our extensions
			ext := strings.ToLower(filepath.Ext(path))
			if !s.isValidExtension(ext) {
				return nil
			}

			// Check ignore patterns
			filename := info.Name()
			if s.shouldIgnoreFile(filename) {
				return nil
			}

			// Check if file exists in database and if it needs rescanning
			if shouldProcess, err := s.shouldProcessFile(path, info); err != nil {
				log.Printf("Error checking file %s: %v", path, err)
				return nil
			} else if !shouldProcess {
				return nil
			}

			// Add/update file in database
			file, err := s.upsertFile(path, info)
			if err != nil {
				log.Printf("Error upserting file %s: %v", path, err)
				return nil
			}

			// Queue for processing
			job := queue.ScanJob{
				ID:        fmt.Sprintf("file_%d", file.ID),
				FilePath:  path,
				FileType:  ext,
				Priority:  1,
				CreatedAt: time.Now(),
			}

			if err := s.queue.PushScanJob(ctx, job); err != nil {
				log.Printf("Error queueing file %s: %v", path, err)
				return nil
			}

			newFiles++
			return nil
		})

		if err != nil {
			log.Printf("Error walking directory %s: %v", scanPath, err)
		}
	}

	duration := time.Since(startTime)
	log.Printf("Directory scan completed. Scanned %d files, queued %d files for processing (took %v)",
		fileCount, newFiles, duration)

	return nil
}

func (s *Service) isValidExtension(ext string) bool {
	for _, validExt := range s.config.Extensions {
		if ext == validExt {
			return true
		}
	}
	return false
}

func (s *Service) shouldIgnoreFile(filename string) bool {
	for _, pattern := range s.config.IgnorePatterns {
		// Simple pattern matching (could be enhanced with proper glob matching)
		if strings.Contains(filename, strings.Trim(pattern, "*")) {
			return true
		}
	}
	return false
}

func (s *Service) shouldProcessFile(path string, info os.FileInfo) (bool, error) {
	var existingFile database.File
	result := s.db.Where("path = ?", path).First(&existingFile)
	
	if result.Error != nil {
		if result.Error == gorm.ErrRecordNotFound {
			// File doesn't exist in database, should process
			return true, nil
		}
		return false, result.Error
	}

	// Check if file has been modified since last scan
	if info.ModTime().After(existingFile.LastModified) {
		return true, nil
	}

	// Check if file hasn't been scanned yet
	if existingFile.LastScanned == nil {
		return true, nil
	}

	// File exists and hasn't been modified, skip
	return false, nil
}

func (s *Service) upsertFile(path string, info os.FileInfo) (*database.File, error) {
	// Calculate file hash
	hash, err := s.calculateFileHash(path)
	if err != nil {
		log.Printf("Warning: Could not calculate hash for %s: %v", path, err)
		hash = ""
	}

	file := database.File{
		Path:         path,
		Filename:     info.Name(),
		FileType:     strings.ToLower(filepath.Ext(path)),
		FileSize:     info.Size(),
		FileHash:     hash,
		LastModified: info.ModTime(),
		ScanStatus:   "queued",
	}

	// Use GORM's upsert functionality
	result := s.db.Where("path = ?", path).Assign(file).FirstOrCreate(&file)
	if result.Error != nil {
		return nil, result.Error
	}

	return &file, nil
}

func (s *Service) calculateFileHash(path string) (string, error) {
	file, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer file.Close()

	hash := md5.New()
	
	// For large files, only hash the first 1MB to speed up processing
	_, err = io.CopyN(hash, file, 1024*1024)
	if err != nil && err != io.EOF {
		return "", err
	}

	return fmt.Sprintf("%x", hash.Sum(nil)), nil
}

func (s *Service) getScanPaths() []string {
	// Get active scan folders from database
	var scanFolders []database.ScanFolder
	if err := s.db.Where("is_active = ?", true).Order("priority desc").Find(&scanFolders).Error; err != nil {
		log.Printf("Failed to load scan folders from database: %v", err)
		return []string{}
	}

	if len(scanFolders) == 0 {
		log.Println("No scan folders configured. Please add folders via the web interface.")
		return []string{}
	}

	paths := make([]string, len(scanFolders))
	for i, folder := range scanFolders {
		paths[i] = folder.Path
	}
	return paths
}