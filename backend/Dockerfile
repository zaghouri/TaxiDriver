# syntax=docker/dockerfile:1.7
# RideMA backend image: one image, three entrypoints (compose picks the command):
#   api      node dist/main.js
#   worker   node dist/worker.js
#   migrate  node dist/db/migrate.js

# ---- build: full deps + TypeScript compile ----
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
# Optional build-time CA for TLS-intercepting proxies (never needed on a normal server):
#   docker build --secret id=build_ca,src=/path/ca.crt ...
RUN --mount=type=cache,target=/root/.npm --mount=type=secret,id=build_ca,required=false,mode=0444 \
    if [ -s /run/secrets/build_ca ]; then export NODE_EXTRA_CA_CERTS=/run/secrets/build_ca; fi; \
    npm ci --no-audit --no-fund
COPY . .
# build = tsc + scripts/copy-assets.mjs (SQL migrations -> dist/db/migrations, web assets)
RUN npm run build && test -d dist/db/migrations

# ---- prod deps only ----
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm --mount=type=secret,id=build_ca,required=false,mode=0444 \
    if [ -s /run/secrets/build_ca ]; then export NODE_EXTRA_CA_CERTS=/run/secrets/build_ca; fi; \
    npm ci --omit=dev --no-audit --no-fund

# ---- runtime ----
FROM node:22-alpine
ENV NODE_ENV=production
WORKDIR /app
RUN mkdir -p /data/storage /data/apk && chown -R node:node /data
COPY --chown=node:node package.json ./
COPY --from=deps --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/dist ./dist
USER node
EXPOSE 3000
CMD ["node", "dist/main.js"]
