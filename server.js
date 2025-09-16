import { createAzure } from '@ai-sdk/azure';
import { generateText, streamText } from 'ai';
import express from 'express';
import cors from 'cors';
import { config } from 'dotenv';
import { readdirSync, readFileSync, existsSync } from 'fs';
import { join } from 'path';

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

// Initialize Azure OpenAI provider
const azure = createAzure({
  baseURL: process.env.AZURE_BASE_URL,
});
const model = azure(process.env.AZURE_DEPLOYMENT_NAME);

app.use(cors());
app.use(express.json());

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
    console.log(`Generating text for prompt: "${prompt}"`);
    console.log(`Using deployment: ${process.env.AZURE_DEPLOYMENT_NAME}`);
    console.log(`Base URL: ${process.env.AZURE_BASE_URL}`);
    
    const { text } = await generateText({ model, prompt });
    console.log('Text generated successfully');
    res.json({ text });
  } catch (error) {
    console.error('Error generating text:');
    console.error('Error message:', error.message);
    console.error('Error stack:', error.stack);
    console.error('Error details:', JSON.stringify(error, null, 2));
    res.status(500).json({ 
      error: error.message,
      details: error.cause || 'No additional details'
    });
  }
});

app.post('/api/stream', async (req, res) => {
  try {
    const { prompt } = req.body;
    console.log(`Streaming text for prompt: "${prompt}"`);
    
    const result = await streamText({ model, prompt });
    
    res.setHeader('Content-Type', 'text/plain');
    res.setHeader('Transfer-Encoding', 'chunked');
    
    for await (const delta of result.textStream) {
      res.write(delta);
    }
    res.end();
  } catch (error) {
    console.error('Error streaming text:', error.message);
    console.error('Error stack:', error.stack);
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
  console.log('Send SIGUSR1 to reload API keys');
});
