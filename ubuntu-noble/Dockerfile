# syntax=docker/dockerfile:1.4

FROM public.ecr.aws/ubuntu/ubuntu:24.04

RUN <<BASH
#!/usr/bin/env bash

set -eufo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update

# Install main packages
#
# There's a subtle flaky bug, somewhere in Linux or qemu, that happens when
# running in an emulated arm64 environment. When installing various python3
# dependencies (python3-six, python3-pip, etc), their maintainer scripts run
# py3compile, which sometimes has an exception getting python3 to run
# 'import sys; print(sys.implementation.cache_tag)'.
# Seen at: https://www.kicksecure.com/wiki/Dev/todo#ISO_-_ARM64_build_failing
# Older Ubuntu LTSes also occasionally flake, but it can manifest differently.
#
# It's a flake, so let's wrap `apt-get install` in a small retry.
#
install_main_pkgs() {
    apt-get install -y --no-install-recommends \
        apt-transport-https \
        bash \
        ca-certificates \
        curl \
        git \
        gnupg-agent \
        jq \
        openssh-client \
        perl \
        python3 \
        python3-pip \
        rsync \
        software-properties-common \
        tini
}
(r=3; while ! install_main_pkgs; do ((--r)) || exit; done)

# Install Docker Engine
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

# We just updated the main sources. This only updates the docker source
apt-get update -o Dir::Etc::sourcelist="sources.list.d/docker.list" \
    -o Dir::Etc::sourceparts="-" \
    -o APT::Get::List-Cleanup="0"
apt-get install -y --no-install-recommends docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

rm -rf /var/lib/apt/lists/*

ln -s /usr/bin/tini /usr/sbin/tini
BASH

COPY ./docker-compose /usr/local/bin/docker-compose
