# Content Warning Scanner

A privacy-focused, locally-deployable application that scans video and subtitle files for potentially triggering content, providing personalized content warnings based on user-defined sensitivity thresholds.

## Features

- **Complete Privacy**: All processing happens locally - no data leaves your system
- **Customizable Sensitivity**: Personalized trigger thresholds per category
- **Batch Processing**: Efficiently scan entire media libraries
- **Multiple File Types**: Support for .srt, .vtt, .mp4, .mkv, .avi files
- **Real-time Dashboard**: Monitor scanning progress and view results
- **Detailed Analysis**: Contextual analysis with confidence scores and timestamps

## Supported Trigger Categories

- Sexual assault/abuse
- Domestic violence  
- Self-harm/suicide
- Substance abuse
- Graphic violence
- Child abuse
- Eating disorders
- Death/grief
- Medical content
- Discrimination/hate speech
- Animal cruelty
- Body horror

## Architecture

```
[Go Scanner Service] → [Redis Queue] → [Python NLP Workers] → [PostgreSQL]
                                    ↓
                              [React Frontend] ← [REST API]
```

## Quick Start

### Prerequisites

- Docker and Docker Compose
- At least 4GB RAM available
- Media files with subtitles or subtitle files

### Installation Options

#### Option 1: Full Stack (Recommended)
Includes PostgreSQL and Redis containers:

```bash
git clone https://github.com/your-username/content-warning-scanner.git
cd content-warning-scanner
cp .env.example .env
# Edit docker-compose.yml to mount your media directories
docker-compose up -d
```

#### Option 2: External Database Services
Use your existing PostgreSQL and Redis instances:

```bash
git clone https://github.com/your-username/content-warning-scanner.git
cd content-warning-scanner
cp .env.external.example .env
# Edit .env with your database connection details
# Edit docker-compose.external.yml to mount your media directories
docker-compose -f docker-compose.external.yml up -d
```

#### Option 3: Development Setup
Mix of containers and external services:

```bash
git clone https://github.com/your-username/content-warning-scanner.git
cd content-warning-scanner
cp .env.external.example .env
# Edit .env with your database connection details
# Edit docker-compose.dev.yml to mount your media directories
docker-compose -f docker-compose.dev.yml up -d
```

### Media Directory Setup

**Mount your media directories** by editing the appropriate docker-compose file:

```yaml
# In docker-compose.yml (or external/dev variants)
services:
  scanner:
    volumes:
      - /path/to/your/movies:/movies:ro
      - /path/to/your/tv:/tv:ro
      - /path/to/your/subtitles:/subtitles:ro
```

### Database Setup

**If using external PostgreSQL**, ensure your database exists and run the initialization:

```bash
# Create database (if it doesn't exist)
createdb your_database_name

# Initialize schema
psql -d your_database_name -f init.sql
```

**Connection Requirements:**
- PostgreSQL 15+ recommended
- Redis 7+ recommended
- Network access from containers to your database services

### Configuration

**Database Configuration Examples:**
```bash
# Local PostgreSQL
DATABASE_URL=postgresql://username:password@localhost:5432/cws

# Remote PostgreSQL with SSL
DATABASE_URL=postgresql://username:password@db.example.com:5432/cws?sslmode=require

# Redis with authentication
REDIS_URL=redis://:password@localhost:6379
```

**Media Folder Management:**
1. Mount your media directories in Docker volumes
2. Access the web interface at `http://localhost:7219`
3. Go to **Settings > Scan Folders**
4. Add the mounted paths (e.g., `/movies`, `/tv`, `/subtitles`)
5. Set priorities and enable/disable folders as needed
6. Start scanning!

Access the application at `http://localhost:7219`

## Usage

### Web Interface

1. **Dashboard**: View scanning statistics and activity
2. **Media Library**: Browse files and their analysis results  
3. **File Details**: Examine specific triggers with timestamps and context
4. **Settings**: Configure scan folders and sensitivity preferences

### API Endpoints

The REST API is available at `http://localhost:8000/api`:

- `GET /api/scan/status` - Get current scan status
- `POST /api/scan/start` - Start scanning
- `GET /api/results` - List scan results with filtering
- `GET /api/results/{id}` - Get detailed file results
- `GET /api/stats/overview` - Get overview statistics

See the [API Documentation](docs/api.md) for complete endpoint details.

## Development

### Local Development Setup

1. **Database**: Start PostgreSQL and Redis
```bash
docker-compose up postgres redis
```

2. **Backend Services**: 
```bash
# Scanner service
cd scanner && go run cmd/main.go

# NLP service  
cd nlp && python -m app.main

# API service
cd api && go run main.go
```

3. **Frontend**:
```bash
cd frontend && npm start
```

### Project Structure

```
content-warning-scanner/
├── scanner/          # Go file discovery service
├── nlp/              # Python NLP processing service  
├── api/              # Go REST API service
├── frontend/         # React web application
├── docker/           # Dockerfiles and configs
├── docs/             # Documentation
├── config/           # Default configurations
└── docker-compose.yml
```

## Performance

### Benchmarks

- **Throughput**: ~100 files/minute on standard hardware
- **Memory Usage**: <2GB for normal operation
- **Storage**: ~1MB per 1000 processed files (metadata only)

### Optimization Tips

- Use SSD storage for database
- Increase worker threads for faster processing
- Enable GPU support for NLP processing (optional)

## Privacy & Security

- **No External Connections**: All processing happens locally
- **No Telemetry**: No usage data is collected or transmitted
- **Secure by Default**: No external API keys required
- **Open Source**: Full transparency of processing algorithms

## Troubleshooting

### Common Issues

**Scanner not finding files:**
- Verify media path is accessible from container
- Check file permissions 
- Ensure supported file extensions

**High memory usage:**
- Reduce number of NLP workers
- Increase scan interval
- Process smaller batches

**Performance issues:**
- Check available disk space
- Monitor database size
- Consider hardware upgrades

### Logs

View service logs:
```bash
docker-compose logs scanner
docker-compose logs nlp-worker  
docker-compose logs api
```

## Contributing

We welcome contributions! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Workflow

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by [unconsentingmedia.com](https://unconsentingmedia.com) for trigger categories
- Built with modern open-source technologies
- Community feedback and contributions

## Support

- **Documentation**: Check the [docs/](docs/) directory
- **Issues**: Report bugs or request features on GitHub
- **Discussions**: Join community discussions for support

---

⚠️ **Important**: This tool is designed to assist with content warnings but may not catch all potentially triggering content. Always use your own judgment and consider professional resources for mental health support.