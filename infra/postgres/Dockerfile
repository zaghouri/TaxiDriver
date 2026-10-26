# syntax=docker/dockerfile:1.7
# PostGIS 16 + WAL-G (built from source, libsodium encryption, fully static binary).
#
# WAL-G tags v2+/v3+ are not importable through the Go module proxy (the module path has no
# /vN suffix), so we pin a commit through its pseudo-version. To move to a newer commit:
#   curl -s https://proxy.golang.org/github.com/wal-g/wal-g/@v/master.info
# and copy "Version" into WALG_VERSION (check that GO_IMAGE satisfies the "go" line of its go.mod).
ARG GO_IMAGE=golang:1.27-bookworm
ARG WALG_VERSION=v1.1.3-rc-with-build.0.20261026163731-67cb69a43286

FROM ${GO_IMAGE} AS go

# Ubuntu builder: libsodium-dev ships libsodium.a, which we link statically.
FROM ubuntu:22.04 AS walg-build
ARG WALG_VERSION
# Optional build-time CA bundle (only needed behind a TLS-intercepting proxy):
#   docker build --secret id=build_ca,src=/path/ca.crt ...
RUN --mount=type=secret,id=build_ca,required=false,mode=0444 \
    set -eux; \
    if [ -s /run/secrets/build_ca ]; then \
      sed -i 's#http://#https://#g' /etc/apt/sources.list; \
      echo 'Acquire::https::CaInfo "/run/secrets/build_ca";' > /etc/apt/apt.conf.d/99build-ca; \
    fi; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      gcc libc6-dev libsodium-dev ca-certificates; \
    rm -rf /var/lib/apt/lists/*; \
    # Force the linker to pick libsodium.a
    find / -xdev -name 'libsodium.so*' -delete
COPY --from=go /usr/local/go /usr/local/go
ENV PATH=/usr/local/go/bin:/root/go/bin:$PATH \
    CGO_ENABLED=1 \
    GOTOOLCHAIN=auto \
    GOFLAGS=-trimpath
RUN --mount=type=secret,id=build_ca,required=false,mode=0444 \
    --mount=type=cache,target=/root/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    set -eux; \
    if [ -s /run/secrets/build_ca ]; then export SSL_CERT_FILE=/run/secrets/build_ca; fi; \
    go install \
      -tags "libsodium netgo osusergo disable_grpc_modules grpcnotrace" \
      -ldflags "-s -w -linkmode external -extldflags '-static' -X github.com/wal-g/wal-g/cmd/pg.walgVersion=${WALG_VERSION}" \
      "github.com/wal-g/wal-g/main/pg@${WALG_VERSION}"; \
    install -m 0755 /root/go/bin/pg /usr/local/bin/wal-g.real; \
    /usr/local/bin/wal-g.real --version

FROM postgis/postgis:16-3.4
COPY --from=walg-build /usr/local/bin/wal-g.real /usr/local/bin/wal-g.real
COPY --chmod=0755 wal-g-env.sh /usr/local/bin/wal-g
COPY --chmod=0755 walg-archive.sh /usr/local/bin/walg-archive
COPY --chmod=0755 backup-run.sh /usr/local/bin/backup-run
COPY --chmod=0755 backup-scheduler.sh /usr/local/bin/backup-scheduler
RUN wal-g.real --version && ldd /usr/local/bin/wal-g.real 2>&1 | grep -q "not a dynamic executable"
