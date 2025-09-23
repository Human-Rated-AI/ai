const { Langfuse } = require('langfuse');

const langfuse = new Langfuse({
  secretKey: process.env.LANGFUSE_SECRET_KEY,
  publicKey: process.env.LANGFUSE_PUBLIC_KEY,
  baseUrl: process.env.LANGFUSE_BASE_URL || 'https://cloud.langfuse.com'
});

function trackUsage(apiKey, prompt, response, tokens = null) {
  const trace = langfuse.trace({
    name: 'ai-api-request',
    userId: apiKey.substring(0, 8), // First 8 chars as user ID
    tags: ['api-usage'],
    metadata: { apiKey: apiKey.substring(0, 8) }
  });

  trace.generation({
    name: 'azure-openai-generation',
    input: prompt,
    output: response,
    usage: tokens ? {
      promptTokens: tokens.prompt,
      completionTokens: tokens.completion,
      totalTokens: tokens.total
    } : undefined
  });
}

module.exports = { trackUsage };
