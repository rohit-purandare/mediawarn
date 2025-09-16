# MediaWarn Setup

## Quick Start

1. **Download the compose file:**
   ```bash
   curl -o docker-compose.yml https://raw.githubusercontent.com/rohit-purandare/mediawarn/master/docker-compose.yml
   ```

2. **Run MediaWarn:**
   ```bash
   docker-compose up -d
   ```

3. **Access the application:**
   - Frontend: http://localhost:7219
   - API: http://localhost:8000
   - NLP Service: http://localhost:8001

## What Gets Created

Docker Compose will automatically create:
- `./data/` - Application data directory
- `./config/` - Configuration directory (initially empty)
- Named volumes for database and models

## Configuration

### Environment Variables
Edit the docker-compose.yml to customize:
```yaml
environment:
  - SCAN_INTERVAL=300        # Scan interval in seconds
  - WORKERS=4                # Number of workers
  - NLP_WORKERS=2           # NLP processing workers
```

### Media Directories
To scan your media, add volume mounts:
```yaml
volumes:
  - /path/to/your/media:/media:ro
  - /path/to/movies:/movies:ro
  - /path/to/tv:/tv:ro
```

### Scanner Configuration
Create `./config/scanner.yaml`:
```yaml
scanner:
  media_paths:
    - /media
    - /movies
    - /tv
  file_extensions:
    - .mkv
    - .mp4
    - .avi
```

## Commands

```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Update to latest version
docker-compose pull
docker-compose up -d

# Clean reset (removes all data)
docker-compose down -v
```

## Troubleshooting

### Check service health
```bash
docker-compose ps
```

### View service logs
```bash
docker-compose logs mediawarn
docker-compose logs postgres
```

### Reset database
```bash
docker-compose down
docker volume rm $(docker volume ls -q | grep postgres)
docker-compose up -d
```