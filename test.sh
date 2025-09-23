#!/usr/bin/env bash

show_help() {
    echo "Usage: $0 <host:port> <prompt> [api_key]"
    echo "Test the AI SDK API server"
    echo ""
    echo "Arguments:"
    echo "  host:port     Server address (e.g., ai-api.hurated.com)"
    echo "  prompt        Text prompt to send to the API"
    echo "  api_key       Optional API key for authentication"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 ai-api.hurated.com 'Hi'"
    echo "  $0 ai-api.hurated.com 'Hi' a1b2c3d4e5f6789012345678901234ab"
}

if [[ "$1" == "-h" || "$1" == "--help" || $# -lt 2 ]]; then
    show_help
    exit 0
fi

HOST_PORT="$1"
PROMPT="$2"
API_KEY="$3"

# Check if curl is available
if ! command -v curl &> /dev/null; then
    echo "Error: curl is not installed"
    exit 1
fi

echo "Testing API at http://$HOST_PORT/api/generate"
echo "Prompt: $PROMPT"
if [[ -n "$API_KEY" ]]; then
    echo "API Key: $API_KEY"
fi
echo ""

if [[ -n "$API_KEY" ]]; then
    curl -L -X POST "https://$HOST_PORT/api/generate" \
         -H "Content-Type: application/json" \
         -H "x-api-key: $API_KEY" \
         -d "{\"prompt\": \"$PROMPT\"}" \
         -w "\n\nStatus: %{http_code}\n"
else
    curl -L -X POST "https://$HOST_PORT/api/generate" \
         -H "Content-Type: application/json" \
         -d "{\"prompt\": \"$PROMPT\"}" \
         -w "\n\nStatus: %{http_code}\n"
fi
