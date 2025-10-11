#!/usr/bin/env bash

show_help() {
    echo "Usage: $0 <service>"
    echo "Deploy services using Docker Compose"
    echo ""
    echo "Services:"
    echo "  ai        Deploy AI API server only"
    echo "  langfuse  Deploy Langfuse only"
    echo "  all       Deploy both AI API server and Langfuse"
    echo ""
    echo "Examples:"
    echo "  $0 ai"
    echo "  $0 langfuse"
    echo "  $0 all"
}

if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
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

case "$1" in
    "ai")
        echo "Deploying AI API server..."
        docker compose up -d --build ai-sdk
        if [[ $? -eq 0 ]]; then
            echo "AI API server deployed successfully!"
            echo "Available at: http://localhost:$(grep EXTERNAL_PORT .env | cut -d= -f2)"
        else
            echo "AI API deployment failed!"
            exit 1
        fi
        ;;
    "langfuse")
        echo "Deploying Langfuse..."
        docker compose up -d langfuse-db langfuse-server
        if [[ $? -eq 0 ]]; then
            echo "Langfuse deployed successfully!"
            echo "Available at: http://localhost:$(grep LANGFUSE_PORT .env | cut -d= -f2)"
        else
            echo "Langfuse deployment failed!"
            exit 1
        fi
        ;;
    "all")
        echo "Deploying all services..."
        docker compose up -d --build
        if [[ $? -eq 0 ]]; then
            echo "All services deployed successfully!"
            echo "Langfuse: http://localhost:$(grep LANGFUSE_PORT .env | cut -d= -f2)"
            echo "AI API: http://localhost:$(grep EXTERNAL_PORT .env | cut -d= -f2)"
        else
            echo "Deployment failed!"
            exit 1
        fi
        ;;
    *)
        echo "Error: Unknown service '$1'"
        echo ""
        show_help
        exit 1
        ;;
esac
