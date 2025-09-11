# Content Warning Scanner - Makefile

.PHONY: help build up up-external up-dev down logs clean dev test

# Default target
help:
	@echo "Content Warning Scanner - Available Commands:"
	@echo ""
	@echo "  Deployment Options:"
	@echo "  make up         - Start full stack (with PostgreSQL & Redis)"
	@echo "  make up-external - Start with external databases"
	@echo "  make up-dev     - Start development environment"
	@echo ""
	@echo "  Management:"
	@echo "  make build      - Build all Docker images"
	@echo "  make down       - Stop all services"
	@echo "  make logs       - View logs from all services"
	@echo "  make clean      - Clean up containers and volumes"
	@echo ""
	@echo "  Development:"
	@echo "  make dev        - Start local development environment"
	@echo "  make test       - Run tests"
	@echo ""
	@echo "  Database:"
	@echo "  make init-db    - Initialize external database schema"
	@echo ""

# Build all Docker images
build:
	docker-compose build

# Start all services (full stack)
up:
	docker-compose up -d
	@echo ""
	@echo "✅ Content Warning Scanner (Full Stack) is starting up..."
	@echo "🌐 Web interface: http://localhost:7219"
	@echo "🔧 API endpoint: http://localhost:8000"
	@echo "📊 Database: localhost:5432"
	@echo "🔄 Redis: localhost:6379"
	@echo ""
	@echo "Use 'make logs' to view startup progress"

# Start with external databases
up-external:
	@echo "Starting Content Warning Scanner with external databases..."
	@echo "⚠️  Ensure your DATABASE_URL and REDIS_URL are configured in .env"
	docker-compose -f docker-compose.external.yml up -d
	@echo ""
	@echo "✅ Content Warning Scanner (External DB) is starting up..."
	@echo "🌐 Web interface: http://localhost:7219"
	@echo "🔧 API endpoint: http://localhost:8000"
	@echo "📊 Using external PostgreSQL"
	@echo "🔄 Using external Redis"
	@echo ""
	@echo "Use 'make logs' to view startup progress"

# Start development environment
up-dev:
	@echo "Starting Content Warning Scanner development environment..."
	docker-compose -f docker-compose.dev.yml up -d
	@echo ""
	@echo "✅ Content Warning Scanner (Development) is starting up..."
	@echo "🌐 Web interface: http://localhost:7219"
	@echo "🔧 API endpoint: http://localhost:8000"
	@echo "📊 Database: via host.docker.internal"
	@echo "🔄 Redis: via host.docker.internal"
	@echo ""
	@echo "Use 'make logs' to view startup progress"

# Stop all services
down:
	docker-compose down
	docker-compose -f docker-compose.external.yml down
	docker-compose -f docker-compose.dev.yml down

# View logs
logs:
	docker-compose logs -f

# Clean up everything
clean:
	docker-compose down -v
	docker system prune -f
	@echo "✅ Cleanup complete"

# Development environment
dev:
	@echo "Starting development environment..."
	docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d postgres redis
	@echo ""
	@echo "🗄️  Database and Redis are running"
	@echo "💡 Start individual services with:"
	@echo "   cd scanner && go run cmd/main.go"
	@echo "   cd nlp && python -m app.main" 
	@echo "   cd api && go run main.go"
	@echo "   cd frontend && npm start"

# Run tests
test:
	@echo "Running tests..."
	cd scanner && go test ./...
	cd nlp && python -m pytest tests/
	cd frontend && npm test -- --watchAll=false

# Database migration
migrate:
	docker-compose exec postgres psql -U cws -d cws -f /docker-entrypoint-initdb.d/init.sql

# Check service health
health:
	@echo "Checking service health..."
	@curl -s http://localhost:8000/health && echo " - API: ✅"
	@curl -s http://localhost:8001/health && echo " - NLP: ✅"  
	@curl -s http://localhost:7219 >/dev/null && echo " - Frontend: ✅"

# View service status
status:
	docker-compose ps

# Backup database
backup:
	@mkdir -p backups
	docker-compose exec postgres pg_dump -U cws cws > backups/backup_$(shell date +%Y%m%d_%H%M%S).sql
	@echo "Database backed up to backups/"

# Restore database
restore:
	@echo "Available backups:"
	@ls -la backups/
	@echo ""
	@read -p "Enter backup filename: " backup; \
	docker-compose exec -T postgres psql -U cws cws < backups/$$backup

# Initialize external database schema
init-db:
	@echo "Initializing database schema..."
	@if [ -z "$$DATABASE_URL" ]; then \
		echo "❌ DATABASE_URL not set. Please configure your .env file."; \
		exit 1; \
	fi
	@echo "Creating database schema..."
	psql "$$DATABASE_URL" -f init.sql
	@echo "✅ Database schema initialized"

# Update all services
update:
	git pull
	docker-compose build
	docker-compose up -d
	@echo "✅ Update complete"