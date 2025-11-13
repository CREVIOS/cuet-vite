# syntax=docker/dockerfile:1.7-labs

ARG NODE_VERSION=22.12.0
ARG PNPM_VERSION=10.21.0
ARG VITE_API_URL=https://api.prod.example.com

FROM node:${NODE_VERSION}-alpine AS build
ENV PNPM_HOME=/pnpm \
    PATH="${PNPM_HOME}:${PATH}" \
    NODE_ENV=production

WORKDIR /app
RUN corepack disable >/dev/null 2>&1 || true \
    && npm install -g pnpm@${PNPM_VERSION}

# Install dependencies with maximal caching by only copying manifests first.
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY patches ./patches
RUN --mount=type=cache,id=pnpm-store,target=/pnpm/store \
    pnpm install --frozen-lockfile

# Copy the full source and build the optimized bundle with the production API URL baked in.
COPY . .
ARG VITE_API_URL
ENV VITE_API_URL=${VITE_API_URL}
RUN --mount=type=cache,id=pnpm-store,target=/pnpm/store \
    pnpm run build

FROM nginx:1.27-alpine AS runtime
LABEL org.opencontainers.image.source="https://github.com/vitejs/vite" \
      org.opencontainers.image.description="Vite frontend microservice" \
      org.opencontainers.image.licenses="MIT"

# Provide sane defaults for container metadata.
ENV NODE_ENV=production \
    PORT=80

# Copy SPA-friendly nginx config and built assets.
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
