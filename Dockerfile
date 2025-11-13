# syntax=docker/dockerfile:1.7-labs

ARG NODE_VERSION=22.12.0
ARG PNPM_VERSION=10.21.0
FROM node:${NODE_VERSION}-slim AS base

ENV PNPM_HOME=/usr/local/share/pnpm \
    PNPM_STORE_PATH=/pnpm/store \
    PATH="${PNPM_HOME}:${PATH}" \
    CI=1

WORKDIR /app
RUN npm install -g pnpm@${PNPM_VERSION}

FROM base AS deps
ENV NODE_ENV=development
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      ca-certificates \
      git \
      python3 \
      build-essential \
      pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Only copy files that affect dependency resolution to maximize cache hits.
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY patches ./patches

FROM deps AS builder
COPY . .
RUN --mount=type=cache,id=pnpm-store,target=/pnpm/store \
    pnpm install --frozen-lockfile
RUN pnpm run build

FROM node:${NODE_VERSION}-slim AS runtime
LABEL org.opencontainers.image.source="https://github.com/vitejs/vite" \
      org.opencontainers.image.description="Vite monorepo build artifacts" \
      org.opencontainers.image.licenses="MIT"

ENV PNPM_HOME=/usr/local/share/pnpm \
    PNPM_STORE_PATH=/pnpm/store \
    PATH="${PNPM_HOME}:${PATH}"

WORKDIR /app
RUN npm install -g pnpm@${PNPM_VERSION}

COPY --from=builder /app ./

EXPOSE 5173
CMD ["pnpm", "--filter", "./packages/vite", "run", "dev"]
