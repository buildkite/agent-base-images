#!/usr/bin/env bash
#
# Installs Docker Engine from Docker's official apt repository, mirroring
# what GitHub Actions runner images provide on ubuntu-latest: the docker
# CLI and daemon, containerd, and the buildx and compose CLI plugins.
#
# Like the GitHub runner images, there is no standalone `docker-compose`
# binary; workflows use `docker compose`. The daemon is not configured or
# started here; the hosted platform manages that at runtime.

set -Eeufo pipefail

export DEBIAN_FRONTEND=noninteractive

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" |
    tee /etc/apt/sources.list.d/docker.list >/dev/null

# Full update: the base stage removes /var/lib/apt/lists, and docker-ce
# depends on Ubuntu packages (iptables, nftables) beyond the docker repo.
apt-get update
apt-get install -y --no-install-recommends \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

docker --version
docker buildx version
docker compose version

apt clean all
rm -rf /var/lib/apt/lists/*
