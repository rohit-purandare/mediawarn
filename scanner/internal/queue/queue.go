package queue

import (
	"context"
	"encoding/json"
	"time"

	"github.com/go-redis/redis/v8"
)

type Client struct {
	rdb *redis.Client
}

type ScanJob struct {
	ID        string    `json:"id"`
	FilePath  string    `json:"file_path"`
	FileType  string    `json:"file_type"`
	Priority  int       `json:"priority"`
	CreatedAt time.Time `json:"created_at"`
}

const (
	ScanJobQueue = "scan_jobs"
	ResultQueue  = "scan_results"
)

func Initialize(redisURL string) (*Client, error) {
	opts, err := redis.ParseURL(redisURL)
	if err != nil {
		return nil, err
	}

	rdb := redis.NewClient(opts)
	
	// Test connection
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	
	if err := rdb.Ping(ctx).Err(); err != nil {
		return nil, err
	}

	return &Client{rdb: rdb}, nil
}

func (c *Client) PushScanJob(ctx context.Context, job ScanJob) error {
	jobData, err := json.Marshal(job)
	if err != nil {
		return err
	}

	return c.rdb.LPush(ctx, ScanJobQueue, jobData).Err()
}

func (c *Client) PopScanJob(ctx context.Context, timeout time.Duration) (*ScanJob, error) {
	result, err := c.rdb.BRPop(ctx, timeout, ScanJobQueue).Result()
	if err != nil {
		if err == redis.Nil {
			return nil, nil // No jobs available
		}
		return nil, err
	}

	if len(result) < 2 {
		return nil, nil
	}

	var job ScanJob
	if err := json.Unmarshal([]byte(result[1]), &job); err != nil {
		return nil, err
	}

	return &job, nil
}

func (c *Client) GetQueueLength(ctx context.Context, queue string) (int64, error) {
	return c.rdb.LLen(ctx, queue).Result()
}

func (c *Client) Close() error {
	return c.rdb.Close()
}