package config

import (
	"os"
	"strconv"
	"strings"

	"github.com/spf13/viper"
)

type Config struct {
	DatabaseURL   string   `mapstructure:"database_url"`
	RedisURL      string   `mapstructure:"redis_url"`
	ScanInterval  int      `mapstructure:"scan_interval"`
	MediaPaths    []string `mapstructure:"media_paths"`
	Extensions    []string `mapstructure:"extensions"`
	IgnorePatterns []string `mapstructure:"ignore_patterns"`
	Workers       int      `mapstructure:"workers"`
}

func Load() (*Config, error) {
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath("/config")
	viper.AddConfigPath("./config")
	viper.AddConfigPath(".")

	// Set defaults
	viper.SetDefault("database_url", "postgresql://cws:password@localhost:5432/cws")
	viper.SetDefault("redis_url", "redis://localhost:6379")
	viper.SetDefault("scan_interval", 300)
	// Media paths are managed through the web interface (scan_folders table)
	// No default paths - users must configure via frontend
	viper.SetDefault("media_paths", []string{})
	viper.SetDefault("extensions", []string{".srt", ".vtt", ".mp4", ".mkv", ".avi"})
	viper.SetDefault("ignore_patterns", []string{"*sample*", "*.tmp"})
	viper.SetDefault("workers", 4)

	// Read config file if it exists
	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			return nil, err
		}
	}

	// Override with environment variables
	viper.AutomaticEnv()
	viper.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))

	// Handle environment variable overrides
	if dbURL := os.Getenv("DATABASE_URL"); dbURL != "" {
		viper.Set("database_url", dbURL)
	}
	if redisURL := os.Getenv("REDIS_URL"); redisURL != "" {
		viper.Set("redis_url", redisURL)
	}
	if scanInterval := os.Getenv("SCAN_INTERVAL"); scanInterval != "" {
		if interval, err := strconv.Atoi(scanInterval); err == nil {
			viper.Set("scan_interval", interval)
		}
	}
	if workers := os.Getenv("WORKERS"); workers != "" {
		if w, err := strconv.Atoi(workers); err == nil {
			viper.Set("workers", w)
		}
	}

	var config Config
	if err := viper.Unmarshal(&config); err != nil {
		return nil, err
	}

	return &config, nil
}