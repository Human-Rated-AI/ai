#!/usr/bin/env bash

set -e

show_help() {
    echo "Usage: $0 [options] <service>"
    echo "Deploy services using Docker Compose (locally or remotely)"
    echo ""
    echo "Services:"
    echo "  ai        Deploy AI API server only"
    echo "  langfuse  Deploy Langfuse only"
    echo "  all       Deploy both AI API server and Langfuse"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -f, --force             Force deployment (skip checks, auto-fix issues)"
    echo "  -m, --message MSG       Commit staged/unstaged changes with message"
    echo "  --remote-host HOST      Remote server hostname (or use REMOTE_HOST in .env)"
    echo "  --remote-user USER      Remote SSH user (or use REMOTE_USER in .env)"
    echo "  --remote-dir DIR        Remote directory (or use REMOTE_DIR in .env)"
    echo ""
    echo "Local deployment examples:"
    echo "  $0 ai"
    echo "  $0 all"
    echo ""
    echo "Remote deployment examples:"
    echo "  $0 --remote-host ai-api.hurated.com ai"
    echo "  $0 -m 'Fix bug' --remote-host ai-api.hurated.com all"
    echo "  $0 -f ai  # Force local deployment"
    echo ""
    echo "Note: Remote deployment requires REMOTE_HOST, REMOTE_USER, and REMOTE_DIR"
    echo "      to be set via command line or in .env file"
}

# Parse arguments
FORCE=false
COMMIT_MSG=""
REMOTE_HOST=""
REMOTE_USER=""
REMOTE_DIR=""
SERVICE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -m|--message)
            COMMIT_MSG="$2"
            shift 2
            ;;
        --remote-host)
            REMOTE_HOST="$2"
            shift 2
            ;;
        --remote-user)
            REMOTE_USER="$2"
            shift 2
            ;;
        --remote-dir)
            REMOTE_DIR="$2"
            shift 2
            ;;
        ai|langfuse|all)
            SERVICE="$1"
            shift
            ;;
        *)
            echo "Error: Unknown argument '$1'"
            echo ""
            show_help
            exit 1
            ;;
    esac
done

if [[ -z "$SERVICE" ]]; then
    echo "Error: Service not specified"
    echo ""
    show_help
    exit 1
fi

# Load .env if exists
if [[ -f .env ]]; then
    set -a
    source .env
    set +a
fi

# Use .env values if not provided via command line
REMOTE_HOST="${REMOTE_HOST:-${REMOTE_HOST:-}}"
REMOTE_USER="${REMOTE_USER:-${REMOTE_USER:-}}"
REMOTE_DIR="${REMOTE_DIR:-${REMOTE_DIR:-}}"

# Determine if this is a remote deployment
IS_REMOTE=false
if [[ -n "$REMOTE_HOST" ]]; then
    IS_REMOTE=true
    
    if [[ -z "$REMOTE_USER" || -z "$REMOTE_DIR" ]]; then
        echo "Error: Remote deployment requires REMOTE_HOST, REMOTE_USER, and REMOTE_DIR"
        exit 1
    fi
    
    echo "=== Remote Deployment ==="
    echo "Host: $REMOTE_HOST"
    echo "User: $REMOTE_USER"
    echo "Dir: $REMOTE_DIR"
    echo "Service: $SERVICE"
    echo ""
fi

# Function to deploy locally
deploy_local() {
    local service=$1
    
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
    
    case "$service" in
        "ai")
            echo "Deploying AI API server..."
            docker compose up -d --build ai-sdk
            if [[ $? -eq 0 ]]; then
                echo "AI API server deployed successfully!"
                echo "Available at: http://localhost:${EXTERNAL_PORT:-9000}"
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
                echo "Available at: http://localhost:${LANGFUSE_PORT:-4000}"
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
                echo "Langfuse: http://localhost:${LANGFUSE_PORT:-4000}"
                echo "AI API: http://localhost:${EXTERNAL_PORT:-9000}"
            else
                echo "Deployment failed!"
                exit 1
            fi
            ;;
    esac
}

# Function to deploy remotely
deploy_remote() {
    local service=$1
    
    echo "Step 1: Checking local git status..."
    
    # Check for uncommitted changes
    if [[ -n "$(git status --porcelain)" ]]; then
        if [[ -n "$COMMIT_MSG" ]]; then
            echo "Committing changes: $COMMIT_MSG"
            git add -A
            git commit -m "$COMMIT_MSG"
        elif [[ "$FORCE" == "true" ]]; then
            echo "Warning: Uncommitted changes detected, but --force flag is set"
            echo "Committing with auto-generated message..."
            git add -A
            git commit -m "Auto-commit before deployment at $(date)"
        else
            echo "Error: Uncommitted changes detected. Use -m to commit or -f to force"
            git status --short
            exit 1
        fi
    fi
    
    echo "Step 2: Pushing to remote repository..."
    
    # Get current repo, branch, and commit
    # Try hurated-origin first, fall back to origin
    if git remote | grep -q "^hurated-origin$"; then
        REMOTE_NAME="hurated-origin"
    else
        REMOTE_NAME="origin"
    fi
    
    LOCAL_REPO=$(git config --get remote.$REMOTE_NAME.url)
    LOCAL_BRANCH=$(git branch --show-current)
    
    git push "$REMOTE_NAME" "$LOCAL_BRANCH"
    LOCAL_COMMIT=$(git rev-parse HEAD)
    
    echo "Pushed commit: $LOCAL_COMMIT"
    echo "Branch: $LOCAL_BRANCH"
    
    echo "Step 3: Checking remote server..."
    
    # Check if remote directory exists
    if ! ssh "$REMOTE_USER@$REMOTE_HOST" "test -d $REMOTE_DIR" 2>/dev/null; then
        if [[ "$FORCE" == "true" ]]; then
            echo "Remote directory does not exist, creating..."
            ssh "$REMOTE_USER@$REMOTE_HOST" "mkdir -p $REMOTE_DIR && cd $REMOTE_DIR && git clone $LOCAL_REPO ."
        else
            echo "Error: Remote directory $REMOTE_DIR does not exist. Use -f to create"
            exit 1
        fi
    fi
    
    # Check remote repo
    REMOTE_REPO=$(ssh "$REMOTE_USER@$REMOTE_HOST" "cd $REMOTE_DIR && git config --get remote.origin.url" 2>/dev/null || echo "")
    
    if [[ "$REMOTE_REPO" != "$LOCAL_REPO" ]]; then
        echo "Error: Remote repository mismatch"
        echo "Local: $LOCAL_REPO"
        echo "Remote: $REMOTE_REPO"
        exit 1
    fi
    
    # Check remote branch
    REMOTE_BRANCH=$(ssh "$REMOTE_USER@$REMOTE_HOST" "cd $REMOTE_DIR && git branch --show-current" 2>/dev/null || echo "")
    
    if [[ "$REMOTE_BRANCH" != "$LOCAL_BRANCH" ]]; then
        if [[ "$FORCE" == "true" ]]; then
            echo "Switching remote branch from $REMOTE_BRANCH to $LOCAL_BRANCH..."
            ssh "$REMOTE_USER@$REMOTE_HOST" "cd $REMOTE_DIR && git checkout $LOCAL_BRANCH"
        else
            echo "Error: Remote branch mismatch (local: $LOCAL_BRANCH, remote: $REMOTE_BRANCH)"
            echo "Use -f to force branch switch"
            exit 1
        fi
    fi
    
    echo "Step 4: Pulling changes on remote server..."
    
    ssh "$REMOTE_USER@$REMOTE_HOST" "cd $REMOTE_DIR && git pull"
    
    REMOTE_COMMIT=$(ssh "$REMOTE_USER@$REMOTE_HOST" "cd $REMOTE_DIR && git rev-parse HEAD")
    
    if [[ "$REMOTE_COMMIT" != "$LOCAL_COMMIT" ]]; then
        echo "Error: Remote commit mismatch after pull"
        echo "Local: $LOCAL_COMMIT"
        echo "Remote: $REMOTE_COMMIT"
        exit 1
    fi
    
    echo "Step 5: Checking .env file..."
    
    # Compare local and remote .env
    LOCAL_ENV_MD5=$(md5sum .env | awk '{print $1}')
    REMOTE_ENV_MD5=$(ssh "$REMOTE_USER@$REMOTE_HOST" "cd $REMOTE_DIR && md5sum .env 2>/dev/null | awk '{print \$1}'" || echo "")
    
    if [[ "$LOCAL_ENV_MD5" != "$REMOTE_ENV_MD5" ]]; then
        if [[ "$FORCE" == "true" ]]; then
            echo "Copying .env to remote server..."
            scp .env "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/.env"
        else
            echo "Error: .env file mismatch. Use -f to copy local .env to remote"
            exit 1
        fi
    fi
    
    echo "Step 6: Deploying on remote server..."
    
    # Deploy based on service
    case "$service" in
        "ai")
            ssh "$REMOTE_USER@$REMOTE_HOST" "cd $REMOTE_DIR && docker compose up -d --build ai-sdk"
            ;;
        "langfuse")
            ssh "$REMOTE_USER@$REMOTE_HOST" "cd $REMOTE_DIR && docker compose up -d langfuse-db langfuse-server"
            ;;
        "all")
            ssh "$REMOTE_USER@$REMOTE_HOST" "cd $REMOTE_DIR && docker compose up -d --build"
            ;;
    esac
    
    echo ""
    echo "=== Remote Deployment Complete ==="
    echo "Service: $service"
    echo "Commit: $LOCAL_COMMIT"
}

# Execute deployment
if [[ "$IS_REMOTE" == "true" ]]; then
    deploy_remote "$SERVICE"
else
    deploy_local "$SERVICE"
fi
