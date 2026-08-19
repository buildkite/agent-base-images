# syntax=docker/dockerfile:1.4

ARG MISE_VERSION=v2026.8.3
ARG NODE_22_VERSION=22.23.2
ARG NODE_24_VERSION=24.18.0
ARG YARN_VERSION=1.22.22

FROM public.ecr.aws/ubuntu/ubuntu:22.04 AS base

ARG BAZELISK_VERSION=v1.29.0
ARG BK_CLI_VERSION=3.40.0
ARG MISE_VERSION
ARG NODE_24_VERSION
ARG MISE_SHA256_AMD64=66585ac496c10bf6fbf13272e3e550c1813aed0e1cb780b9bb73c1751de49289
ARG MISE_SHA256_ARM64=a5bdab52367ecca6c253b60f74d85f8cefe51f613e3b7fcec7b7a5f1dc1bbb41

ENV LC_CTYPE="C.UTF-8"

# https://mise.jdx.dev/mise-cookbook/docker.html
ENV MISE_DATA_DIR="/mise"
ENV MISE_CONFIG_DIR="/mise"
ENV MISE_CACHE_DIR="/mise/cache"
ENV MISE_INSTALL_PATH="/usr/local/bin/mise"
ENV PATH="/mise/shims:/opt/buildkite/mise-toolchains/installs/node/${NODE_24_VERSION}/bin:$PATH"

ARG TARGETARCH

RUN --mount=type=cache,target=/var/cache/apt,id=apt-cache-${TARGETARCH},sharing=locked \
--mount=type=cache,target=/var/lib/apt,id=apt-lib-${TARGETARCH},sharing=locked \
--mount=type=cache,target=/var/cache/debconf,id=debconf-${TARGETARCH},sharing=locked \
--mount=type=bind,source=common/install-mise-default-node.sh,target=/install-mise-default-node.sh \
<<BASH
#!/usr/bin/env bash

set -eufo pipefail

export DEBIAN_FRONTEND=noninteractive

export ARCH=x86_64
if [ "$(dpkg --print-architecture)" = "arm64" ]; then export ARCH=aarch64 ; fi

export DEBIAN_ARCH=$(dpkg --print-architecture)

# Install main packages
apt-get update
apt-get install -y --no-install-recommends \
  apt-transport-https \
  bash \
  ca-certificates \
  curl \
  git \
  git-lfs \
  gnupg-agent \
  jq \
  openssh-client \
  perl \
  python3 \
  python3-pip \
  python3-dev \
  python3-crcmod \
  lsb-release \
  rsync \
  software-properties-common \
  tini \
  sudo \
  bash \
  gnupg \
  zip \
  unzip \
  build-essential

git --version
git-lfs --version

# install bazelisk
curl -fLo /tmp/bazelisk.deb https://github.com/bazelbuild/bazelisk/releases/download/${BAZELISK_VERSION}/bazelisk-${DEBIAN_ARCH}.deb
dpkg -i /tmp/bazelisk.deb
rm -f /tmp/bazelisk.deb

# install buildkite-cli
curl -fLo /tmp/bk.deb https://github.com/buildkite/cli/releases/download/v${BK_CLI_VERSION}/bk_${BK_CLI_VERSION}_linux_${DEBIAN_ARCH}.deb
dpkg -i /tmp/bk.deb
rm -f /tmp/bk.deb

bash /install-mise-default-node.sh

# install aws-cli
curl https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}.zip -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /opt
/opt/aws/install --update -i /usr/local/aws-cli -b /usr/local/bin
rm -rf /tmp/awscliv2.zip /opt/aws
aws --version

# install GCP CLI
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
apt-get update && apt-get install -y google-cloud-cli
gcloud --version

rm -rf /tmp/*

ln -s /usr/bin/tini /usr/sbin/tini

apt clean all

# Clean up apt cache
rm -rf /var/lib/apt/lists/*
BASH

FROM base AS toolchains

ARG MISE_VERSION
ARG NODE_22_VERSION
ARG NODE_24_VERSION
ARG YARN_VERSION

RUN --mount=type=bind,source=common/install-mise-toolchains.sh,target=/tmp/install-mise-toolchains.sh \
  bash /tmp/install-mise-toolchains.sh

RUN --mount=type=bind,source=common/install-docker.sh,target=/tmp/install-docker.sh \
  bash /tmp/install-docker.sh

WORKDIR /root
USER root

# Keep the normal Hosted tag slim; the opt-in variant explicitly builds the
# toolchains target above.
FROM base AS hosted

WORKDIR /root
USER root
