# syntax=docker/dockerfile:1.7
# LOCAL TESTING ONLY (infra/docker-compose.local.yml): S3-compatible bucket for WAL-G backups.
# MinIO no longer publishes images on Docker Hub, so minio + mc are built from source through the
# Go module proxy (the upstream repo is archived; last commits pinned below).
ARG GO_IMAGE=golang:1.27-bookworm
FROM ${GO_IMAGE} AS build
ARG MINIO_VERSION=v0.0.0-20260212201848-7aac2a2c5b7c
ARG MC_VERSION=v0.0.0-20251106162529-77f82e18b540
ENV CGO_ENABLED=0 GOFLAGS=-trimpath GOTOOLCHAIN=local
RUN --mount=type=secret,id=build_ca,required=false,mode=0444 \
    --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    set -eux; \
    if [ -s /run/secrets/build_ca ]; then export SSL_CERT_FILE=/run/secrets/build_ca; fi; \
    go install -ldflags "-s -w" "github.com/minio/minio@${MINIO_VERSION}"; \
    go install -ldflags "-s -w" "github.com/minio/mc@${MC_VERSION}"

FROM ubuntu:22.04
COPY --from=build /go/bin/minio /go/bin/mc /usr/local/bin/
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/minio"]
CMD ["server", "/data", "--address", ":9000"]
