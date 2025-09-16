FROM node:20-alpine

WORKDIR /app

# Install pnpm
RUN npm install -g pnpm@10.11.0

# Copy server files
COPY server.js server-package.json ./
COPY .env* ./
COPY .env.d/ ./.env.d/

# Install server dependencies
RUN cp server-package.json package.json && pnpm install --prod

EXPOSE $PORT

CMD ["node", "server.js"]
