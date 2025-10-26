# AI SDK - Hurated Branch

This is a containerized API server built on top of Vercel's AI SDK, configured for Azure OpenAI integration.

> **Original AI SDK Documentation**: See [packages/ai/README.md](packages/ai/README.md) for the complete Vercel AI SDK documentation.

## Quick Start

### Local Development (Testing Before Deployment)

**Requirements:** Node.js 18+ (Node 20+ recommended)

**Switch to latest Node version** (if using nvm):
```bash
nvm use node
```

1. **Configure environment**:
   ```bash
   cp .env.example .env
   # Edit .env with your Azure OpenAI credentials
   ```

2. **Install dependencies**:
   ```bash
   # Use server-package.json directly (avoids workspace dependencies)
   cp server-package.json package.json
   
   # Remove pnpm configs to avoid npm warnings (local only, not committed)
   echo "# Local npm config for server development" > .npmrc
   
   npm install
   
   # NOTE: Do NOT run 'npm audit fix --force'
   # It will upgrade to AI SDK v5, which breaks Azure provider compatibility.
   # The jsondiffpatch XSS vulnerability is low-risk for backend APIs (no HTML rendering).
   ```

3. **Create API keys directory** (REQUIRED for authentication):
   ```bash
   mkdir -p .env.d
   echo "your-secret-api-key-min-32-chars-long" > .env.d/client1
   ```
   
   **Note:** Each file in `.env.d/` contains one API key (32+ characters). File names don't matter.
   - Server loads all keys from `.env.d/` on startup
   - If directory is empty/missing, authentication is disabled
   - Reload keys without restart: `kill -SIGUSR1 <pid>`

4. **Run locally with auto-reload**:
   ```bash
   npm run dev
   ```
   
   Server will start on **`http://localhost:3000`** (or your configured `PORT`).
   The `--watch` flag automatically restarts when you modify `server.js`.

5. **Test locally**:
   ```bash
   # In another terminal
   # Basic text generation
   ./test.sh localhost:3000 "Hello, world!" -k your-secret-api-key-min-32-chars-long
   
   # Test with image
   ./test.sh localhost:3000 "What is this?" -i photo.jpg -k your-secret-api-key-min-32-chars-long
   
   # If you didn't create .env.d (no auth), omit -k flag:
   # ./test.sh localhost:3000 "Hello, world!"
   ```

### Production Deployment

#### Local Deployment

1. **Deploy with Docker**:
   ```bash
   ./deploy.sh all
   ```
   
   Docker exposes server on port **8000** by default (set `EXTERNAL_PORT` in `.env` to change).

2. **Test deployed server**:
   ```bash
   # Docker uses port 8000 (EXTERNAL_PORT in .env)
   ./test.sh localhost:8000 'Hello, world!' -k your-secret-api-key-min-32-chars-long
   ```

#### Remote Deployment

Deploy to a remote server via SSH:

1. **Configure remote settings in `.env`**:
   ```bash
   REMOTE_HOST=ai-api.hurated.com
   REMOTE_USER=your_ssh_username
   REMOTE_DIR=ai
   ```

2. **Deploy to remote server**:
   ```bash
   # Deploy AI API only
   ./deploy.sh --remote-host ai-api.hurated.com ai
   
   # Or use .env configuration
   ./deploy.sh ai  # Uses REMOTE_HOST from .env if set
   
   # Commit changes and deploy
   ./deploy.sh -m "Update feature" ai
   
   # Force deployment (auto-fix issues)
   ./deploy.sh -f ai
   ```

3. **Test remote server**:
   ```bash
   ./test.sh ai-api.hurated.com 'Hello, world!' -k your-api-key
   ```

**Remote deployment features:**
- Checks for uncommitted changes (use `-m` to commit or `-f` to force)
- Verifies remote repository and branch match
- Syncs `.env` file if different (with `-f` flag)
- Pulls latest changes before deploying
- Validates commit hash matches after pull

## Configuration

### Environment Variables (.env)
- `AZURE_API_KEY` - Your Azure OpenAI API key
- `AZURE_BASE_URL` - Azure OpenAI endpoint (e.g., `https://your-resource.openai.azure.com/openai`)
- `AZURE_DEPLOYMENT_NAME` - Your model deployment name
- `PORT` - Internal container port (default: 3000)
- `EXTERNAL_PORT` - External host port (default: 8000)

**Note for Vision Features**: To use `/api/generate-with-vision` and `/api/stream-with-vision`, your Azure deployment must use a vision-capable model such as **GPT-4o**, **GPT-4.1 with vision**, or **GPT-4-vision**. Standard GPT-3.5 or GPT-4 (non-vision) deployments do not support image analysis.

### API Keys (.env.d/)

**Where keys are stored:** Each file in the `.env.d/` directory contains one API key (32+ characters minimum).

Create individual key files:
```bash
mkdir -p .env.d
echo "your-secret-api-key-min-32-chars-long" > .env.d/client1
echo "another-secret-key-at-least-32-chars" > .env.d/client2
```

**Authentication behavior:**
- If `.env.d/` exists with valid keys → **Authentication required** (401 without valid key)
- If `.env.d/` is empty or missing → **No authentication** (all requests allowed)

**File names don't matter** - the server reads all files in `.env.d/` and treats their contents as valid keys.

Reload keys without restart:
```bash
# Local development
kill -SIGUSR1 <process-id>

# Docker
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

### POST /api/generate-with-vision
Generate text response with image analysis (requires GPT-4o or GPT-4-vision deployment).

**Request**:
```json
{
  "prompt": "Describe this image in detail",
  "images": [
    {
      "type": "url",
      "url": "https://example.com/image.jpg"
    },
    {
      "type": "base64",
      "data": "base64-encoded-image-data",
      "mimeType": "image/jpeg"
    }
  ],
  "imageDetail": "high"
}
```

**Parameters**:
- `prompt` (required): Text prompt/question about the images
- `images` (required): Array of image objects
  - `type`: Either `"url"` or `"base64"`
  - `url`: Image URL (if type is "url")
  - `data`: Base64-encoded image data (if type is "base64")
  - `mimeType`: MIME type like "image/jpeg", "image/png", etc. (for base64)
- `imageDetail` (optional): Image detail level - `"low"`, `"high"`, or `"auto"` (default: "auto")
  - `low`: Faster and cheaper, suitable for general understanding
  - `high`: More detailed analysis, higher cost
  - `auto`: Let the model decide based on image size

**Supported Image Formats**:
- JPEG (.jpg, .jpeg)
- PNG (.png)
- GIF (.gif)
- WebP (.webp)

**Image Size Limits:**
- **Local files (base64)**: Up to 50MB server limit (test.sh uses temp file for large payloads)
- **URLs**: No limit (fetched directly by Azure) - **recommended for very large images**
- **Recommended**: Keep images under 10MB for faster uploads and lower costs

**Headers**:
```
Content-Type: application/json
x-api-key: your-32-char-api-key
```

**Example with curl**:
```bash
# Using image URL
curl -X POST "http://localhost:8000/api/generate-with-vision" \
  -H "Content-Type: application/json" \
  -H "x-api-key: your-api-key" \
  -d '{
    "prompt": "What is in this image?",
    "images": [{
      "type": "url",
      "url": "https://example.com/photo.jpg"
    }],
    "imageDetail": "high"
  }'
```

### POST /api/stream-with-vision
Stream text response with image analysis in real-time.

Same request format as `/api/generate-with-vision`, returns streaming text.

---

## Vision Examples

### Using test.sh

**Analyze a local image:**
```bash
./test.sh localhost:3000 "Describe this image in detail" -i photo.jpg
```

**Analyze image from URL:**
```bash
./test.sh localhost:3000 "What objects are in this image?" \
  --image-url "https://example.com/photo.jpg"
```

**Compare multiple images:**
```bash
./test.sh localhost:3000 "What are the differences?" \
  -i image1.jpg -i image2.jpg --image-detail high
```

**OCR / Extract text:**
```bash
./test.sh localhost:3000 "Extract all text from this image" \
  -i document.jpg --image-detail high
```

**Streaming response:**
```bash
./test.sh localhost:3000 "Describe this scene" -i photo.jpg -s
```

### Using JavaScript

```javascript
import fs from 'fs';

// Analyze local image
const imageBuffer = fs.readFileSync('./photo.jpg');
const imageBase64 = imageBuffer.toString('base64');

const response = await fetch('http://localhost:3000/api/generate-with-vision', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'x-api-key': process.env.API_KEY
  },
  body: JSON.stringify({
    prompt: 'What is in this image?',
    images: [{
      type: 'base64',
      data: imageBase64,
      mimeType: 'image/jpeg'
    }],
    imageDetail: 'auto'
  })
});

const result = await response.json();
console.log(result.text);
```

### Using Python

```python
import base64
import requests

# Read and encode image
with open('photo.jpg', 'rb') as f:
    image_data = base64.b64encode(f.read()).decode('utf-8')

# Send request
response = requests.post(
    'http://localhost:3000/api/generate-with-vision',
    headers={
        'Content-Type': 'application/json',
        'x-api-key': 'your-api-key'
    },
    json={
        'prompt': 'Describe this image',
        'images': [{
            'type': 'base64',
            'data': image_data,
            'mimeType': 'image/jpeg'
        }],
        'imageDetail': 'high'
    }
)

print(response.json()['text'])
```

### Image Detail Levels

- **`low`**: Fast & economical (~85 tokens/image). Good for general understanding.
- **`high`**: Detailed analysis (170-765 tokens/image). Best for OCR and fine details.
- **`auto`**: Model decides based on image size (default). Balanced approach.

## Scripts

### deploy.sh
Deploy with Docker Compose:
```bash
./deploy.sh all        # Deploy all services
./deploy.sh ai         # Deploy API server only
./deploy.sh langfuse   # Deploy analytics only
```

### test.sh
Test API endpoints with various features:

**Basic text generation**:
```bash
./test.sh localhost:8000 "Hello, world!"
./test.sh localhost:8000 "Hello!" -k a1b2c3d4e5f6789012345678901234ab
```

**Image analysis**:
```bash
# Analyze local image file
./test.sh localhost:8000 "Describe this image" -i photo.jpg

# Analyze image from URL
./test.sh localhost:8000 "What is in this image?" --image-url https://example.com/image.jpg

# Multiple images with high detail
./test.sh localhost:8000 "Compare these images" \
  -i img1.jpg \
  --image-url https://example.com/img2.jpg \
  --image-detail high
```

**Streaming responses**:
```bash
./test.sh localhost:8000 "Tell me a story" -s
./test.sh localhost:8000 "Describe this" -i photo.jpg -s
```

**Options**:
- `-k, --api-key KEY` - API key for authentication
- `-i, --image FILE` - Image file to analyze (base64 encoded)
- `--image-url URL` - Image URL to analyze
- `--image-detail LEVEL` - Image detail: low, high, auto (default: auto)
- `-s, --stream` - Use streaming endpoint
- `-h, --help` - Show help message

## Docker

The service runs on configurable ports and includes:
- Azure OpenAI integration
- API key authentication
- Hot-reload for API keys
- CORS enabled
- Health monitoring

Access at: `http://localhost:8000` (or your configured `EXTERNAL_PORT`)
