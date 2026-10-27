#!/usr/bin/env bash
# One-time server preparation for Ubuntu 24.04 (run as root ON the server):
#   ssh root@SERVER 'bash -s' < scripts/bootstrap-server.sh
# Installs Docker Engine + compose plugin, ufw (22, 80, 443, 3478 tcp/udp, TURN relay range),
# swap, unattended security upgrades, fail2ban for sshd, Docker log limits. Idempotent.
# Env: SWAP_SIZE=4G  TURN_MIN_PORT=49160  TURN_MAX_PORT=49200
set -euo pipefail

SWAP_SIZE="${SWAP_SIZE:-4G}"
TURN_MIN_PORT="${TURN_MIN_PORT:-49160}"
TURN_MAX_PORT="${TURN_MAX_PORT:-49200}"
export DEBIAN_FRONTEND=noninteractive

[ "$(id -u)" = 0 ] || { echo "run as root" >&2; exit 1; }
. /etc/os-release
[ "${ID:-}" = ubuntu ] || echo "WARNING: tested on Ubuntu 24.04 only (found ${PRETTY_NAME:-unknown})" >&2

echo "== base packages"
apt-get update -y
apt-get install -y ca-certificates curl gnupg ufw fail2ban unattended-upgrades rsync jq openssl

echo "== docker"
if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
mkdir -p /etc/docker
if [ ! -f /etc/docker/daemon.json ]; then
  # userland-proxy=false keeps real client IPs for Caddy's admin allowlist.
  cat > /etc/docker/daemon.json <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "5" },
  "userland-proxy": false,
  "live-restore": true
}
JSON
fi
systemctl enable docker >/dev/null
systemctl restart docker

echo "== swap ($SWAP_SIZE)"
if ! swapon --show | grep -q .; then
  fallocate -l "$SWAP_SIZE" /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
cat > /etc/sysctl.d/90-ridema.conf <<'SYSCTL'
vm.swappiness=10
# Redis background saves / AOF rewrite
vm.overcommit_memory=1
net.core.somaxconn=1024
SYSCTL
sysctl --system >/dev/null

echo "== firewall"
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 443/udp
ufw allow 3478/tcp
ufw allow 3478/udp
ufw allow "${TURN_MIN_PORT}:${TURN_MAX_PORT}/udp"
ufw --force enable
# Note: ports published by Docker bypass ufw. Only caddy (80/443) publishes ports; coturn uses
# host networking (covered by the rules above); postgres/redis/osrm are internal only.

echo "== unattended upgrades"
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'APT'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
APT
systemctl enable --now unattended-upgrades >/dev/null

echo "== fail2ban"
cat > /etc/fail2ban/jail.d/ridema.local <<'F2B'
[sshd]
enabled = true
backend = systemd
maxretry = 5
findtime = 10m
bantime = 1h
F2B
systemctl enable fail2ban >/dev/null
systemctl restart fail2ban

echo "== done. Next: scripts/deploy.sh from your machine, then infra/osrm/prepare.sh on the server."
docker --version
docker compose version
