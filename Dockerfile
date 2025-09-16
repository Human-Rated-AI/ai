FROM node:20-alpine

WORKDIR /app

# Install pnpm
RUN npm install -g pnpm@10.11.0

# Copy package files
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY packages ./packages
COPY server.js server-package.json ./

# Install dependencies
RUN pnpm install --frozen-lockfile

# Build the project
RUN pnpm build

# Install server dependencies
RUN cp server-package.json package.json && pnpm install --prod

EXPOSE $PORT

CMD ["node", "server.js"]
