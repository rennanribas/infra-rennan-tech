# Rennan Tech Infrastructure

This directory contains the infrastructure configuration to run Rennan Tech projects in production and local development environments.

## Local Development

### Prerequisites

- Docker
- Docker Compose
- curl (for verification)

### Quick Start

```bash
./run-local.sh
```

### Manual Setup

1. **Build Docker images:**

```bash
cd ..

docker build -t rennan-tech:latest --target static rennan-tech-landing/

docker build -t engineer-lab:latest engineer-lab/
```

2. **Run docker-compose:**

```bash
cd infra-rennan-tech
docker compose up -d
```

3. **Verify services:**

```bash
docker compose ps

docker compose logs -f

curl http://localhost
curl http://localhost/engineer
```

## Local URLs

- **Landing Page**: http://localhost
- **Engineer Lab**: http://localhost/engineer

## File Structure

- `docker-compose.yml` - Services configuration
- `Caddyfile` - Proxy configuration for production
- `Caddyfile.local` - Proxy configuration for local development
- `run-local.sh` - Automated script for local execution

## Troubleshooting

### Container restarting

```bash
docker compose logs [container-name]

docker compose logs rennan-tech
docker compose logs engineer-lab
docker compose logs caddy
```

### Ports in use

```bash
docker compose down

lsof -i :80
lsof -i :443
```

### Rebuild images

```bash
docker compose down
docker rmi rennan-tech:latest engineer-lab:latest
./run-local.sh
```

## Production Deployment

For production deployment, use the original `Caddyfile` and configure appropriate environment variables:

```bash
export RENNAN_TECH_IMAGE=your-registry/rennan-tech:latest
export ENGINEER_LAB_IMAGE=your-registry/engineer-lab:latest

docker compose up -d
```

## Notes

- Local environment uses `Caddyfile.local` to avoid SSL issues
- Images are built locally to simulate the pipeline
- Caddy acts as reverse proxy for both services
- Dockerfiles were fixed to use correct package managers (pnpm/npm)
