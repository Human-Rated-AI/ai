# AI SDK - Hurated Branch

This is a containerized API server built on top of Vercel's AI SDK, configured for Azure OpenAI integration.

> **Original AI SDK Documentation**: See [packages/ai/README.md](packages/ai/README.md) for the complete Vercel AI SDK documentation.

## Quick Start

1. **Configure environment**:
   ```bash
   cp .env.example .env
   # Edit .env with your Azure OpenAI credentials
   ```

2. **Deploy**:
   ```bash
   ./deploy.sh
   ```

3. **Test**:
   ```bash
   ./test.sh localhost:8000 'Hello, world!' a1b2c3d4e5f6789012345678901234ab
   ```

## Configuration

### Environment Variables (.env)
- `AZURE_API_KEY` - Your Azure OpenAI API key
- `AZURE_BASE_URL` - Azure OpenAI endpoint (e.g., `https://your-resource.openai.azure.com/openai`)
- `AZURE_DEPLOYMENT_NAME` - Your model deployment name
- `PORT` - Internal container port (default: 3000)
- `EXTERNAL_PORT` - External host port (default: 8000)

### API Keys (.env.d/)
Create individual files in `.env.d/` directory, each containing a 32+ character API key:
```bash
echo "a1b2c3d4e5f6789012345678901234ab" > .env.d/client1
echo "9f8e7d6c5b4a321098765432109876cd" > .env.d/client2
```

Reload keys without restart:
```bash
docker compose kill -s SIGUSR1 ai-sdk
```

## API Endpoints

### POST /api/generate
Generate complete text response.

**Request**:
```json
{
  "prompt": "Your prompt here"
}
```

**Headers**:
```
Content-Type: application/json
x-api-key: your-32-char-api-key
```

### POST /api/stream
Stream text response in real-time.

Same request format as `/api/generate`, returns streaming text.

## Scripts

- `./deploy.sh` - Deploy with Docker Compose
- `./test.sh <host:port> <prompt> [api_key]` - Test API endpoints

## Docker

The service runs on configurable ports and includes:
- Azure OpenAI integration
- API key authentication
- Hot-reload for API keys
- CORS enabled
- Health monitoring

Access at: `http://localhost:8000` (or your configured `EXTERNAL_PORT`)
