#!/bin/bash

# Script para executar o ambiente local de desenvolvimento
# Simula o ambiente de deploy usando Docker Compose

set -e

echo "Starting local development environment..."

cd "$(dirname "$0")/.."

echo "Building Docker images..."

echo "  Building rennan-tech:latest..."
docker build -t rennan-tech:latest --target static rennan-tech-landing/

echo "  Building engineer-lab:latest..."
docker build -t engineer-lab:latest engineer-lab/

echo "Starting services with Docker Compose..."
cd infra-rennan-tech

docker compose down --remove-orphans > /dev/null 2>&1 || true

docker compose up -d

echo "Waiting for services to be ready..."
sleep 3

echo "Checking services..."

if curl -s -f http://localhost > /dev/null; then
    echo "  rennan-tech: http://localhost - OK"
else
    echo "  rennan-tech: FAILED"
fi

if curl -s -f http://localhost/engineer > /dev/null; then
    echo "  engineer-lab: http://localhost/engineer - OK"
else
    echo "  engineer-lab: FAILED"
fi

echo ""
echo "Local environment ready!"
echo "Available URLs:"
echo "   Landing Page: http://localhost"
echo "   Engineer Lab: http://localhost/engineer"
echo ""
echo "To view logs: docker compose logs -f"
echo "To stop: docker compose down" 