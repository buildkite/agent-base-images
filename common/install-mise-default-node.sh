#!/usr/bin/env bash

set -Eeufo pipefail

: "${MISE_VERSION:?}"
: "${MISE_SHA256_AMD64:?}"
: "${MISE_SHA256_ARM64:?}"
: "${NODE_24_VERSION:?}"

mise_arch=x64
mise_sha256="${MISE_SHA256_AMD64}"
if [[ "$(dpkg --print-architecture)" == "arm64" ]]; then
  mise_arch=arm64
  mise_sha256="${MISE_SHA256_ARM64}"
fi

curl -fLo /usr/local/bin/mise "https://github.com/jdx/mise/releases/download/${MISE_VERSION}/mise-${MISE_VERSION}-linux-${mise_arch}"
echo "${mise_sha256}  /usr/local/bin/mise" | sha256sum --check
chmod 0755 /usr/local/bin/mise
test "$(mise --version | awk '{print $1}')" = "${MISE_VERSION#v}"

# Install the default Node at the root reused by the toolchains target.
node_24_root="/opt/buildkite/mise-toolchains/installs/node/${NODE_24_VERSION}"
MISE_DATA_DIR=/opt/buildkite/mise-toolchains \
  MISE_CONFIG_DIR=/tmp/mise-config \
  MISE_CACHE_DIR=/tmp/mise-cache \
  mise install "node@${NODE_24_VERSION}"
test -d "${node_24_root}"
test ! -L "${node_24_root}"
test "$(readlink -f "$(command -v node)")" = "${node_24_root}/bin/node"
test "$(node --version)" = "v${NODE_24_VERSION}"
rm -rf /tmp/mise-cache /tmp/mise-config /opt/buildkite/mise-toolchains/downloads
