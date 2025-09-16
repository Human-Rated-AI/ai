#!/usr/bin/env bash

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Deploy the AI SDK API server using Docker Compose"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "Example:"
    echo "  $0"
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Check if docker is available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH"
    exit 1
fi

# Check if docker compose is available
if ! docker compose version &> /dev/null; then
    echo "Error: Docker Compose is not available"
    exit 1
fi

# Check if .env file exists
if [[ ! -f .env ]]; then
    echo "Error: .env file not found"
    exit 1
fi

echo "Deploying AI SDK API server..."
docker compose up -d

if [[ $? -eq 0 ]]; then
    echo "Deployment successful!"
    echo "API server is running at http://localhost:$(grep EXTERNAL_PORT .env | cut -d= -f2)"
else
    echo "Deployment failed!"
    exit 1
fi
