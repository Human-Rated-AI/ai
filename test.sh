#!/usr/bin/env bash

show_help() {
    echo "Usage: $0 <host:port> <prompt> [options]"
    echo "Test the AI SDK API server"
    echo ""
    echo "Arguments:"
    echo "  prompt        Text prompt to send to the API"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -k, --api-key KEY       API key for authentication (place keys in .env.d/ directory)"
    echo "  -i, --image FILE        Image file to analyze (base64, max ~10MB recommended)"
    echo "  --image-url URL         Image URL to analyze (recommended for large images)"
    echo "  --image-detail LEVEL    Image detail level: low, high, auto (default: auto)"
    echo "  -s, --stream            Use streaming endpoint"
    echo ""
    echo "API Keys:"
    echo "  Store keys in .env.d/ directory (one key per file, 32+ characters)."
    echo "  Example: echo 'test-api-key-for-local-development-min-32-chars' > .env.d/mykey"
    echo ""
    echo "Image Size:"
    echo "  Local files (-i): Up to 50MB supported (uses temp file for large payloads)"
    echo "  URLs (--image-url): No size limit, fetched directly by Azure"
    echo "  Recommended: Keep images under 10MB for faster uploads and lower costs"
    echo ""
    echo "Examples:"
    echo "  # Simple text prompt (local dev)"
    echo "  $0 localhost:3000 'Hello, world!' -k test-api-key-for-local-development-min-32-chars"
    echo ""
    echo "  # With API key (Docker)"
    echo "  $0 localhost:8000 'Hello!' -k test-api-key-for-local-development-min-32-chars"
    echo ""
    echo "  # Analyze local image"
    echo "  $0 localhost:3000 'Describe this image' -i photo.jpg -k test-api-key-for-local-development-min-32-chars"
    echo ""
    echo "  # Analyze image from URL"
    echo "  $0 localhost:3000 'What is in this image?' --image-url https://example.com/image.jpg"
    echo ""
    echo "  # Multiple images with high detail"
    echo "  $0 localhost:3000 'Compare these images' -i img1.jpg --image-url https://example.com/img2.jpg --image-detail high"
}
# Parse arguments
HOST_PORT=""
PROMPT=""
API_KEY=""
IMAGE_FILES=()
IMAGE_URLS=()
IMAGE_DETAIL="auto"
USE_STREAM=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -k|--api-key)
            API_KEY="$2"
            shift 2
            ;;
        -i|--image)
            IMAGE_FILES+=("$2")
            shift 2
            ;;
        --image-url)
            IMAGE_URLS+=("$2")
            shift 2
            ;;
        --image-detail)
            IMAGE_DETAIL="$2"
            shift 2
            ;;
        -s|--stream)
            USE_STREAM=true
            shift
            ;;
        *)
            if [[ -z "$HOST_PORT" ]]; then
                HOST_PORT="$1"
            elif [[ -z "$PROMPT" ]]; then
                PROMPT="$1"
            else
                echo "Error: Unknown argument '$1'"
                echo ""
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [[ -z "$HOST_PORT" || -z "$PROMPT" ]]; then
    echo "Error: host:port and prompt are required"
    echo ""
    show_help
    exit 1
fi

# Check if curl is available
if ! command -v curl &> /dev/null; then
    echo "Error: curl is not installed"
    exit 1
fi

# Check if base64 is available (needed for image encoding)
if [[ ${#IMAGE_FILES[@]} -gt 0 ]] && ! command -v base64 &> /dev/null; then
    echo "Error: base64 is not installed (required for image files)"
    exit 1
fi

# Determine if we're using vision API
USE_VISION=false
if [[ ${#IMAGE_FILES[@]} -gt 0 || ${#IMAGE_URLS[@]} -gt 0 ]]; then
    USE_VISION=true
fi

# Build endpoint URL
if [[ "$USE_VISION" == "true" ]]; then
    if [[ "$USE_STREAM" == "true" ]]; then
        ENDPOINT="/api/stream-with-vision"
    else
        ENDPOINT="/api/generate-with-vision"
    fi
else
    if [[ "$USE_STREAM" == "true" ]]; then
        ENDPOINT="/api/stream"
    else
        ENDPOINT="/api/generate"
    fi
fi

echo "=== AI SDK API Test ==="
echo "Endpoint: http://$HOST_PORT$ENDPOINT"
echo "Prompt: $PROMPT"
if [[ -n "$API_KEY" ]]; then
    echo "API Key: ${API_KEY:0:8}..."
fi
if [[ "$USE_VISION" == "true" ]]; then
    echo "Image files: ${#IMAGE_FILES[@]}"
    echo "Image URLs: ${#IMAGE_URLS[@]}"
    echo "Image detail: $IMAGE_DETAIL"
fi
echo ""

# Build JSON payload
if [[ "$USE_VISION" == "true" ]]; then
    # Start building images array
    IMAGES_JSON="[]"
    
    # Add image files (base64 encoded)
    for img_file in "${IMAGE_FILES[@]}"; do
        if [[ ! -f "$img_file" ]]; then
            echo "Error: Image file not found: $img_file"
            exit 1
        fi
        
        # Detect MIME type
        MIME_TYPE="image/jpeg"
        case "${img_file##*.}" in
            jpg|jpeg) MIME_TYPE="image/jpeg" ;;
            png) MIME_TYPE="image/png" ;;
            gif) MIME_TYPE="image/gif" ;;
            webp) MIME_TYPE="image/webp" ;;
            *) echo "Warning: Unknown image type, assuming JPEG" ;;
        esac
        
        echo "Encoding image: $img_file ($MIME_TYPE)"
        IMG_BASE64=$(base64 < "$img_file" | tr -d '\n')
        
        # Add to images array
        if [[ "$IMAGES_JSON" == "[]" ]]; then
            IMAGES_JSON="[{\"type\":\"base64\",\"data\":\"$IMG_BASE64\",\"mimeType\":\"$MIME_TYPE\"}]"
        else
            IMAGES_JSON="${IMAGES_JSON%]},{\"type\":\"base64\",\"data\":\"$IMG_BASE64\",\"mimeType\":\"$MIME_TYPE\"}]"
        fi
    done
    
    # Add image URLs
    for img_url in "${IMAGE_URLS[@]}"; do
        echo "Adding image URL: $img_url"
        if [[ "$IMAGES_JSON" == "[]" ]]; then
            IMAGES_JSON="[{\"type\":\"url\",\"url\":\"$img_url\"}]"
        else
            IMAGES_JSON="${IMAGES_JSON%]},{\"type\":\"url\",\"url\":\"$img_url\"}]"
        fi
    done
    
    JSON_PAYLOAD="{\"prompt\":\"$PROMPT\",\"images\":$IMAGES_JSON,\"imageDetail\":\"$IMAGE_DETAIL\"}"
else
    JSON_PAYLOAD="{\"prompt\":\"$PROMPT\"}"
fi

echo "Sending request..."
echo ""

# Use temp file for payload to avoid "Argument list too long" error with large images
TEMP_FILE=$(mktemp)
echo "$JSON_PAYLOAD" > "$TEMP_FILE"

# Build curl command
CURL_CMD=(curl -L -X POST "http://$HOST_PORT$ENDPOINT")
CURL_CMD+=(-H "Content-Type: application/json")
if [[ -n "$API_KEY" ]]; then
    CURL_CMD+=(-H "x-api-key: $API_KEY")
fi
CURL_CMD+=(--data-binary "@$TEMP_FILE")
CURL_CMD+=(-w "\n\nStatus: %{http_code}\n")

# Execute request
"${CURL_CMD[@]}"

# Cleanup
rm -f "$TEMP_FILE"

echo ""
echo "Request complete."
