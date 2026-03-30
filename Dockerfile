FROM node:22-slim AS builder
WORKDIR /app

# Install bun
RUN npm install -g bun

# Install all dependencies (including devDeps for build)
COPY package.json bun.lock ./
COPY patches ./patches
RUN bun install --ignore-scripts

# Copy source
COPY . .

# Build renderer (no Electron needed) and server bundle
RUN bun run build:renderer:web
RUN node scripts/build-server.mjs

# ---- Runtime image ----
FROM node:22-slim AS runtime
WORKDIR /app

# Install native dependencies (libssl is required by some pre-compiled ACP agents)
RUN apt-get update && apt-get install -y openssl ca-certificates && rm -rf /var/lib/apt/lists/*

# Install bun since our CMD uses it
RUN npm install -g bun

# Copy only build artifacts and production deps
COPY --from=builder /app/dist-server ./dist-server
COPY --from=builder /app/out/renderer ./out/renderer
COPY package.json bun.lock ./
COPY patches ./patches
RUN bun install --production --ignore-scripts
RUN npm install -g codex

ENV PORT=3000
ENV NODE_ENV=production
ENV ALLOW_REMOTE=true
ENV DATA_DIR=/data

# SQLite data volume — mount with: -v $(pwd)/data:/data
VOLUME ["/data"]
EXPOSE 3000

CMD ["bun", "/app/dist-server/server.mjs"]
