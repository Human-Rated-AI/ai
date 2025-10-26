# AI SDK Multi-Modal Features - Implementation TODO

**Project Goal:** Add image recognition, document processing, MCP tools, and URL parsing to the Azure OpenAI API server.

**Target Deployment:** Azure OpenAI with GPT-4.1 (vision-enabled)

**Documentation:** All examples and instructions are in README.md

---

## Phase 1: Core Multi-Modal Support

### ✅ Step 1: Image Recognition
**Status:** ✅ COMPLETE & TESTED  
**Completed:** 2025-10-11  
**Time Spent:** ~2 hours

**Tasks:**
- [x] Add `/api/generate-with-vision` endpoint supporting images
- [x] Add `/api/stream-with-vision` endpoint for streaming with images
- [x] Support base64 encoded images in request body
- [x] Support image URLs in request body
- [x] Support multiple images in single request
- [x] Add image detail level parameter (`low`, `high`, `auto`)
- [x] Update Langfuse tracking for image requests
- [x] Add MIME type validation (JPEG, PNG, GIF, WebP)
- [x] Update `test.sh` with `-i/--image` flag for image file path
- [x] Update `test.sh` with `--image-url` flag for image URLs
- [x] Update `test.sh` with `-s/--stream` flag for streaming
- [x] Update `test.sh` with `--image-detail` flag
- [x] Add example curl commands to README
- [x] Add comprehensive documentation for vision endpoints
- [x] Add local development instructions with `npm run dev`
- [x] Add vision examples to README.md (JavaScript, Python, bash)
- [x] Increase Express body size limit to 50MB for base64 images
- [x] Add enhanced logging with timestamps, IP, request/response preview
- [x] Test with Azure OpenAI GPT-4.1 with vision deployment - ✅ WORKING

**Implementation Notes:**
- Both endpoints accept arrays of images for multi-image analysis
- Images can be provided as URLs or base64-encoded data
- Image detail parameter controls cost/quality tradeoff
- Langfuse tracking includes "[VISION]" prefix for easy filtering
- test.sh automatically detects vision mode when images are provided
- Backward compatible: existing endpoints unchanged
- **Target Model:** Azure GPT-4.1 with vision support ✅ TESTED & WORKING
- **Local Testing:** Use `npm run dev` for development with auto-reload
- **Logging:** Concise format `[HH:MM:SS] IP CODE | Q:"..." | A:"..." [extra]`
- **Body Limit:** 50MB for base64-encoded images (~10MB recommended)
- **Image Size:** Local files ~10MB recommended, URLs no limit (fetched by Azure)

**API Design:**
```json
POST /api/generate-with-vision
{
  "prompt": "Describe this image",
  "images": [
    {
      "type": "url",
      "url": "https://example.com/image.jpg"
    },
    {
      "type": "base64",
      "data": "base64-encoded-string",
      "mimeType": "image/jpeg"
    }
  ],
  "imageDetail": "high"
}
```

---

### Step 2: Document/PDF Recognition
**Status:** ⏳ Pending  
**Estimated Time:** 1-2 hours

**Tasks:**
- [ ] Add document support to vision endpoints (or create separate endpoints)
- [ ] Support PDF files (.pdf)
- [ ] Support Word documents (.docx, .doc)
- [ ] Support PowerPoint (.pptx, .ppt)
- [ ] Support text files (.txt, .md, .rtf)
- [ ] Support spreadsheets (.xlsx, .csv) - limited
- [ ] Add file size validation (max 100MB)
- [ ] Add document MIME type detection
- [ ] Update Langfuse tracking for document requests
- [ ] Update `test.sh` with `-d/--document` flag for document file path
- [ ] Update `test.sh` with `--doc-url` flag for document URLs
- [ ] Add example curl commands to README
- [ ] Verify Azure OpenAI deployment supports document understanding

**Supported Formats:**
- ✅ PDF (.pdf)
- ✅ Word (.docx, .doc)
- ✅ PowerPoint (.pptx, .ppt)
- ✅ Text (.txt, .md, .rtf)
- ⚠️ Spreadsheets (.xlsx, .csv) - limited support

**API Design:**
```json
POST /api/generate-with-vision
{
  "prompt": "Summarize this document",
  "documents": [
    {
      "type": "file",
      "data": "base64-encoded-pdf",
      "mimeType": "application/pdf",
      "filename": "document.pdf"
    }
  ]
}
```

---

## Phase 2: Tool Enhancement

### Step 3: URL Fetching Tool (Server-Side)
**Status:** ⏳ Pending  
**Estimated Time:** 2-3 hours

**Tasks:**
- [ ] Create `fetchUrl` tool using AI SDK tool system
- [ ] Add URL validation and sanitization
- [ ] Implement HTML to text extraction
- [ ] Add timeout handling (30s default)
- [ ] Add error handling for failed fetches
- [ ] Support custom headers (User-Agent, etc.)
- [ ] Add content type detection
- [ ] Limit response size (max 1MB text)
- [ ] Update Langfuse tracking for tool usage
- [ ] Add `/api/generate-with-tools` endpoint
- [ ] Add `/api/stream-with-tools` endpoint
- [ ] Update `test.sh` with `--enable-tools` flag
- [ ] Add example usage to README
- [ ] Test with various websites

**Tool Definition:**
```javascript
{
  fetchUrl: tool({
    description: 'Fetch and parse content from a URL',
    parameters: z.object({
      url: z.string().url().describe('The URL to fetch'),
      includeHtml: z.boolean().optional().describe('Include raw HTML')
    }),
    execute: async ({ url, includeHtml }) => {
      // Implementation
    }
  })
}
```

**Use Cases:**
- "Summarize this article: https://example.com/article"
- "What's the main topic of this webpage?"
- "Compare these two articles"

---

## Phase 3: Advanced Tools (Optional)

### Step 4: MCP Server Integration
**Status:** ⏳ Pending  
**Estimated Time:** 4-6 hours

**Tasks:**
- [ ] Add MCP client dependencies to `server-package.json`
- [ ] Create MCP client initialization function
- [ ] Add MCP transport configuration (stdio/SSE)
- [ ] Implement tool discovery from MCP servers
- [ ] Add MCP server lifecycle management
- [ ] Support multiple MCP servers simultaneously
- [ ] Add environment variable configuration for MCP servers
- [ ] Update Langfuse tracking for MCP tool usage
- [ ] Add `/api/mcp/servers` endpoint to list available servers
- [ ] Add `/api/mcp/tools` endpoint to list available tools
- [ ] Update `test.sh` with `--mcp-server` flag
- [ ] Create example MCP server configurations
- [ ] Add documentation for MCP setup
- [ ] Test with stdio transport
- [ ] Test with SSE transport

**Environment Variables:**
```bash
# MCP Server Configuration (comma-separated)
MCP_SERVERS=filesystem,fetch,database
MCP_FILESYSTEM_COMMAND=node
MCP_FILESYSTEM_ARGS=./mcp-servers/filesystem/index.js
MCP_FETCH_COMMAND=node
MCP_FETCH_ARGS=./mcp-servers/fetch/index.js
```

**API Design:**
```json
POST /api/generate-with-mcp
{
  "prompt": "List files in /tmp and summarize the largest one",
  "mcpServers": ["filesystem"],
  "maxSteps": 10
}
```

**MCP Servers to Consider:**
- `@modelcontextprotocol/server-filesystem` - File operations
- `@modelcontextprotocol/server-fetch` - Web scraping
- `@modelcontextprotocol/server-postgres` - Database queries
- Custom servers for specific use cases

---

## Additional Enhancements

### Step 5: File Upload Endpoint (Nice to Have)
**Status:** ⏳ Pending  
**Estimated Time:** 1-2 hours

**Tasks:**
- [ ] Add `POST /api/upload` endpoint using multer or similar
- [ ] Store uploaded files temporarily
- [ ] Return file ID or base64 data
- [ ] Add file cleanup/expiration (1 hour TTL)
- [ ] Add file size limits per environment variables
- [ ] Support multipart/form-data
- [ ] Update test.sh to use upload endpoint
- [ ] Add authentication for uploads

---

## Testing & Documentation

### Step 6: Comprehensive Testing
**Status:** ⏳ Pending  
**Estimated Time:** 2-3 hours

**Tasks:**
- [ ] Test image recognition with various formats
- [ ] Test PDF recognition with multi-page documents
- [ ] Test URL fetching with different websites
- [ ] Test error handling (invalid files, timeouts, etc.)
- [ ] Test with and without API keys
- [ ] Test concurrent requests
- [ ] Test file size limits
- [ ] Load testing with docker compose
- [ ] Test Langfuse tracking integration
- [ ] Test hot-reload of API keys with new endpoints

### Step 7: Documentation Updates
**Status:** 🚧 Partial (Step 1 complete)  
**Estimated Time:** 1 hour

**Tasks:**
- [x] Update main README.md with vision endpoints (Step 1)
- [x] Add example curl commands for vision (Step 1)
- [x] Add vision examples in multiple languages (Step 1)
- [x] Document local development workflow (Step 1)
- [x] Document required Azure deployment configuration (Step 1)
- [ ] Add troubleshooting section (defer to when issues arise)
- [ ] Update .env.example with new variables (if needed for Steps 2-4)
- [ ] Add documentation for Steps 2-4 as they're implemented

---

## Technical Considerations

### Azure OpenAI Requirements
- **Target Model:** GPT-4.1 with vision support
- **Vision/Document Support:** Requires vision-capable model (GPT-4o, GPT-4.1 with vision, or GPT-4-vision)
- **Regions:** Not all Azure regions support vision features
- **API Version:** Ensure using compatible API version (2024-02-15-preview or later)
- **Rate Limits:** Vision requests may have different rate limits

### Local Development
- **Install:** `cp server-package.json package.json && npm install` (uses standalone package.json, not workspace)
- **Run Dev:** `npm run dev` (auto-reload with --watch flag)
- **Test Local:** `./test.sh localhost:3000 "prompt" -i image.jpg`
- **Port:** Default is 3000 (or set `PORT` in .env)
- **Note:** Don't use the root package.json (it has pnpm workspace dependencies)

### Performance Optimization
- [ ] Add response caching for identical requests
- [ ] Implement request queuing for rate limit management
- [ ] Add compression for base64 image transfer
- [ ] Consider CDN for frequently accessed images

### Security Considerations
- [ ] Add file type validation (magic number checking)
- [ ] Sanitize URLs before fetching
- [ ] Add SSRF protection for URL fetching
- [ ] Limit file sizes to prevent DoS
- [ ] Add rate limiting per API key
- [ ] Scan uploaded files for malware (optional)

### Cost Management
- [ ] Track token usage separately for vision requests
- [ ] Add cost estimation per request type
- [ ] Implement budget alerts via Langfuse
- [ ] Add image detail level defaults to reduce costs

---

## Progress Tracking

**Last Updated:** 2025-10-11 06:35 PST

**Overall Progress:** 1/7 major steps complete (14%) - Step 1 fully tested with Azure GPT-4.1

| Step | Feature | Status | Priority | Blocked By |
|------|---------|--------|----------|------------|
| 1 | Image Recognition | ✅ Complete | High | - |
| 2 | Document Recognition | ⏳ Pending | High | - |
| 3 | URL Fetching Tool | ⏳ Pending | Medium | - |
| 4 | MCP Integration | ⏳ Pending | Low | - |
| 5 | File Upload Endpoint | ⏳ Pending | Low | Steps 1-2 |
| 6 | Comprehensive Testing | ⏳ Pending | High | Steps 1-4 |
| 7 | Documentation | 🚧 Partial | Medium | Steps 1-4 |

**Note:** Step 2 (Document Recognition) can now proceed as it builds on the same patterns as Step 1.

---

## Notes & Decisions

### Security Vulnerability: jsondiffpatch XSS
**Status:** Acknowledged, not fixing
- **Vulnerability:** XSS in jsondiffpatch <0.7.2 (used by ai@4.x)
- **Severity:** Moderate (affects HtmlFormatter class)
- **Decision:** Do NOT run `npm audit fix --force`
- **Reason:** 
  - Fix requires upgrading to ai@5.x (breaking changes, incompatible with Azure provider)
  - Backend API doesn't use HTML rendering (HtmlFormatter not used)
  - Risk is negligible for this use case
- **Future:** Will be resolved when AI SDK v5 adds Azure provider support

### URL Parsing Approach
**Decision:** Implement server-side URL fetching tool (Step 3) before MCP integration.
- **Reason:** Simpler, no external dependencies, faster to implement
- **Migration Path:** Can later add MCP-based fetch tool alongside built-in tool

### Endpoint Design
**Decision:** Create separate endpoints for different features vs. unified endpoint.
- **Option A:** Separate endpoints (`/api/generate-with-vision`, `/api/generate-with-tools`)
- **Option B:** Unified endpoint with feature flags (`/api/generate?features=vision,tools`)
- **Current:** Using separate endpoints for clarity (can consolidate later)

### Backward Compatibility
**Decision:** Keep existing `/api/generate` and `/api/stream` endpoints unchanged.
- New endpoints are additive
- Existing integrations continue to work
- Migration guide for new features

---

## Future Enhancements (Out of Scope)

- [ ] Audio transcription (Whisper integration)
- [ ] Text-to-speech (TTS integration)
- [ ] Image generation (DALL-E integration)
- [ ] Video analysis (when supported by providers)
- [ ] Embedding generation endpoint
- [ ] Fine-tuning management
- [ ] Model comparison endpoint
- [ ] Batch processing support
- [ ] WebSocket support for real-time streaming
- [ ] GraphQL API alternative

---

## Success Criteria

### Phase 1 Complete When:
- ✅ Users can send images with prompts
- ✅ Users can send PDFs with prompts
- ✅ test.sh supports both image and document testing
- ✅ All features tracked in Langfuse
- ✅ Documentation updated

### Phase 2 Complete When:
- ✅ Users can ask model to fetch URLs
- ✅ Model can access web content during conversation
- ✅ test.sh supports tool-enabled prompts

### Phase 3 Complete When:
- ✅ MCP servers can be configured and used
- ✅ Multiple tool sources work together
- ✅ Production-ready with error handling

---

**Project Start Date:** 2025-10-11  
**Target Completion:** TBD based on priority
