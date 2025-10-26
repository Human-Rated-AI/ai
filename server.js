import { createAzure } from '@ai-sdk/azure';
import { generateText, streamText } from 'ai';
import express from 'express';
import cors from 'cors';
import { config } from 'dotenv';
import { readdirSync, readFileSync, existsSync } from 'fs';
import { join } from 'path';
import { trackUsage } from './langfuse-tracker.js';

// Load main .env file
config();

let validKeys = [];

function loadApiKeys() {
  const envDir = '.env.d';
  validKeys = [];
  
  if (existsSync(envDir)) {
    try {
      const files = readdirSync(envDir);
      files.forEach(file => {
        const filePath = join(envDir, file);
        const key = readFileSync(filePath, 'utf8').trim();
        if (key && key.length >= 32) {
          validKeys.push(key);
        } else if (key) {
          console.warn(`Key in ${file} is too short (${key.length} chars, minimum 32)`);
        }
      });
      console.log(`Loaded ${validKeys.length} API keys`);
    } catch (error) {
      console.warn('Error loading API keys:', error.message);
    }
  }
}

// Initial load
loadApiKeys();

const app = express();
const port = process.env.PORT || 3000;

// Debug configuration
console.log('=== Azure OpenAI Configuration ===');
console.log('AZURE_API_KEY:', process.env.AZURE_API_KEY ? `${process.env.AZURE_API_KEY.substring(0, 10)}...` : 'NOT SET');
console.log('AZURE_BASE_URL:', process.env.AZURE_BASE_URL || 'NOT SET');
console.log('AZURE_DEPLOYMENT_NAME:', process.env.AZURE_DEPLOYMENT_NAME || 'NOT SET');
console.log('===================================');

// Construct the correct deployment-based URL
const baseUrl = process.env.AZURE_BASE_URL;
const deploymentName = process.env.AZURE_DEPLOYMENT_NAME;
const deploymentUrl = `${baseUrl}/deployments/${deploymentName}`;

console.log('Constructed deployment URL:', deploymentUrl);

// Initialize Azure OpenAI provider
const azure = createAzure({
  baseURL: deploymentUrl,
});
// Use empty string as model ID since deployment is already in the URL
const model = azure('');

app.use(cors());
app.use(express.json({ limit: '50mb' })); // Increased limit for base64-encoded images

// Helper function for concise logging (max 140 chars)
function logRequest(ip, endpoint, prompt, response, extra = '') {
  const timestamp = new Date().toISOString().substring(11, 19); // HH:MM:SS
  const shortPrompt = prompt.substring(0, 25) + (prompt.length > 25 ? '...' : '');
  const shortResponse = response.substring(0, 35) + (response.length > 35 ? '...' : '');
  const extraInfo = extra ? ` ${extra}` : '';
  console.log(`[${timestamp}] ${ip} ${endpoint} | Q:"${shortPrompt}" | A:"${shortResponse}"${extraInfo}`);
}

// API key authentication middleware
app.use('/api', (req, res, next) => {
  if (validKeys.length === 0) {
    return next(); // No auth if no keys configured
  }
  
  const apiKey = req.headers['x-api-key'];
  if (!apiKey || !validKeys.includes(apiKey)) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
});

app.post('/api/generate', async (req, res) => {
  try {
    const { prompt } = req.body;
    const apiKey = req.headers['x-api-key'];
    const ip = req.ip || req.connection.remoteAddress;
    
    const { text } = await generateText({ model, prompt });
    logRequest(ip, 'TXT', prompt, text);
    
    // Track usage in Langfuse
    if (apiKey) {
      trackUsage(apiKey, prompt, text);
    }
    
    res.json({ text });
  } catch (error) {
    console.error(`[ERR] ${req.ip} /generate:`, error.message);
    res.status(500).json({ 
      error: error.message,
      details: error.cause || 'No additional details'
    });
  }
});

app.post('/api/stream', async (req, res) => {
  try {
    const { prompt } = req.body;
    const apiKey = req.headers['x-api-key'];
    const ip = req.ip || req.connection.remoteAddress;
    
    const result = await streamText({ model, prompt });
    
    res.setHeader('Content-Type', 'text/plain');
    res.setHeader('Transfer-Encoding', 'chunked');
    
    let fullResponse = '';
    for await (const delta of result.textStream) {
      fullResponse += delta;
      res.write(delta);
    }
    res.end();
    
    logRequest(ip, 'STR', prompt, fullResponse);
    
    // Track usage in Langfuse
    if (apiKey) {
      trackUsage(apiKey, prompt, fullResponse);
    }
  } catch (error) {
    console.error(`[ERR] ${req.ip} /stream:`, error.message);
    res.status(500).json({ 
      error: error.message,
      details: error.cause || 'No additional details'
    });
  }
});

// Vision endpoint - Generate with images
app.post('/api/generate-with-vision', async (req, res) => {
  try {
    const { prompt, images, imageDetail = 'auto' } = req.body;
    const apiKey = req.headers['x-api-key'];
    const ip = req.ip || req.connection.remoteAddress;
    
    if (!images || !Array.isArray(images) || images.length === 0) {
      return res.status(400).json({ error: 'At least one image is required' });
    }
    
    // Build content array with text and images
    const content = [
      { type: 'text', text: prompt }
    ];
    
    // Track image sources for logging
    const imageUrls = [];
    
    // Add each image to content
    for (const img of images) {
      if (img.type === 'url') {
        // URL-based image
        content.push({
          type: 'image',
          image: img.url,
          providerOptions: {
            openai: { imageDetail }
          }
        });
        imageUrls.push(img.url.substring(0, 30) + '...');
      } else if (img.type === 'base64') {
        // Base64-encoded image
        content.push({
          type: 'image',
          image: img.data,
          providerOptions: {
            openai: { imageDetail }
          }
        });
        imageUrls.push('base64');
      } else {
        return res.status(400).json({ 
          error: `Invalid image type: ${img.type}. Must be 'url' or 'base64'` 
        });
      }
    }
    
    const { text } = await generateText({ 
      model, 
      messages: [
        {
          role: 'user',
          content
        }
      ]
    });
    
    const extra = `[${images.length}img:${imageUrls[0]}]`;
    logRequest(ip, 'VIS', prompt, text, extra);
    
    // Track usage in Langfuse
    if (apiKey) {
      trackUsage(apiKey, `[VISION] ${prompt} (${images.length} images)`, text);
    }
    
    res.json({ text });
  } catch (error) {
    console.error(`[ERR] ${req.ip} /vision:`, error.message);
    res.status(500).json({ 
      error: error.message,
      details: error.cause || 'No additional details'
    });
  }
});

// Vision endpoint - Stream with images
app.post('/api/stream-with-vision', async (req, res) => {
  try {
    const { prompt, images, imageDetail = 'auto' } = req.body;
    const apiKey = req.headers['x-api-key'];
    const ip = req.ip || req.connection.remoteAddress;
    
    if (!images || !Array.isArray(images) || images.length === 0) {
      return res.status(400).json({ error: 'At least one image is required' });
    }
    
    // Build content array with text and images
    const content = [
      { type: 'text', text: prompt }
    ];
    
    // Track image sources for logging
    const imageUrls = [];
    
    // Add each image to content
    for (const img of images) {
      if (img.type === 'url') {
        content.push({
          type: 'image',
          image: img.url,
          providerOptions: {
            openai: { imageDetail }
          }
        });
        imageUrls.push(img.url.substring(0, 30) + '...');
      } else if (img.type === 'base64') {
        content.push({
          type: 'image',
          image: img.data,
          providerOptions: {
            openai: { imageDetail }
          }
        });
        imageUrls.push('base64');
      } else {
        return res.status(400).json({ 
          error: `Invalid image type: ${img.type}. Must be 'url' or 'base64'` 
        });
      }
    }
    
    const result = await streamText({ 
      model, 
      messages: [
        {
          role: 'user',
          content
        }
      ]
    });
    
    res.setHeader('Content-Type', 'text/plain');
    res.setHeader('Transfer-Encoding', 'chunked');
    
    let fullResponse = '';
    for await (const delta of result.textStream) {
      fullResponse += delta;
      res.write(delta);
    }
    res.end();
    
    const extra = `[${images.length}img:${imageUrls[0]}]`;
    logRequest(ip, 'V-S', prompt, fullResponse, extra);
    
    // Track usage in Langfuse
    if (apiKey) {
      trackUsage(apiKey, `[VISION] ${prompt} (${images.length} images)`, fullResponse);
    }
  } catch (error) {
    console.error(`[ERR] ${req.ip} /vision-stream:`, error.message);
    res.status(500).json({ 
      error: error.message,
      details: error.cause || 'No additional details'
    });
  }
});

// Handle SIGUSR1 for reloading keys
process.on('SIGUSR1', () => {
  console.log('Reloading API keys...');
  loadApiKeys();
});

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
  console.log(`Auth: ${validKeys.length > 0 ? 'enabled' : 'disabled'}`);
  console.log(`PID: ${process.pid}`);
  console.log(`Reload API keys: kill -SIGUSR1 ${process.pid}`);
});
