# syntax=docker/dockerfile:1.4

FROM public.ecr.aws/ubuntu/ubuntu:24.04 AS base

ARG BAZELISK_VERSION=v1.29.0
ARG BK_CLI_VERSION=3.40.0
ARG MISE_VERSION=v2026.8.3
ARG MISE_SHA256_AMD64=66585ac496c10bf6fbf13272e3e550c1813aed0e1cb780b9bb73c1751de49289
ARG MISE_SHA256_ARM64=a5bdab52367ecca6c253b60f74d85f8cefe51f613e3b7fcec7b7a5f1dc1bbb41
ARG NODE_20_VERSION=20.20.2
ARG NODE_24_VERSION=24.18.0

ENV LC_CTYPE="C.UTF-8"

# https://mise.jdx.dev/mise-cookbook/docker.html
ENV MISE_DATA_DIR="/mise"
ENV MISE_CONFIG_DIR="/mise"
ENV MISE_CACHE_DIR="/mise/cache"
ENV MISE_INSTALL_PATH="/usr/local/bin/mise"
ENV PATH="/mise/shims:$PATH"

ARG TARGETARCH

RUN --mount=type=cache,target=/var/cache/apt,id=apt-cache-${TARGETARCH},sharing=locked \
--mount=type=cache,target=/var/lib/apt,id=apt-lib-${TARGETARCH},sharing=locked \
--mount=type=cache,target=/var/cache/debconf,id=debconf-${TARGETARCH},sharing=locked \
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

# install a pinned mise binary and preload common Hosted toolchains
export MISE_ARCH=x64
export MISE_SHA256=${MISE_SHA256_AMD64}
export TOOLCACHE_ARCH=x64
if [ "${DEBIAN_ARCH}" = "arm64" ]; then
  export MISE_ARCH=arm64
  export MISE_SHA256=${MISE_SHA256_ARM64}
  export TOOLCACHE_ARCH=arm64
fi

curl -fLo /usr/local/bin/mise https://github.com/jdx/mise/releases/download/${MISE_VERSION}/mise-${MISE_VERSION}-linux-${MISE_ARCH}
echo "${MISE_SHA256}  /usr/local/bin/mise" | sha256sum --check
chmod 0755 /usr/local/bin/mise
test "$(mise --version | awk '{print $1}')" = "${MISE_VERSION#v}"

export TOOLCHAIN_DATA_DIR=/opt/buildkite/mise-toolchains

canonical_mise() {
  MISE_DATA_DIR="${TOOLCHAIN_DATA_DIR}" \
    MISE_CONFIG_DIR=/tmp/mise-config \
    MISE_CACHE_DIR=/tmp/mise-cache \
    MISE_RUBY_COMPILE=false \
    mise "$@"
}

export GO_124_VERSION="$(canonical_mise latest go@1.24)"
export GO_125_VERSION="$(canonical_mise latest go@1.25)"
export GO_126_VERSION="$(canonical_mise latest go@1.26)"

[[ "${GO_124_VERSION}" =~ ^1\.24\.[0-9]+$ ]]
[[ "${GO_125_VERSION}" =~ ^1\.25\.[0-9]+$ ]]
[[ "${GO_126_VERSION}" =~ ^1\.26\.[0-9]+$ ]]

# Resolve the newest stable Ruby with precompiled assets for both Linux
# architectures. An ephemeral lockfile selects its exact jdx/ruby build
# revision without relying on the anonymous GitHub API quota.
export RUBY_VERSION=
export RUBY_SOURCE_RELEASE=
for candidate in $(curl --retry 3 --retry-all-errors -fsSL https://mise-versions.jdx.dev/ruby | tr ' ' '\n' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -Vr); do
  candidate_release=
  revision=1
  while true; do
    if [ "${revision}" -gt 1000 ]; then
      echo "Refusing to resolve more than 1000 jdx/ruby revisions for ${candidate}" >&2
      exit 1
    fi
    release="${candidate}-${revision}"
    status="$(curl --retry 3 --retry-all-errors -sSL \
      -o /tmp/mise-ruby-candidate-release.json -w '%{http_code}' \
      "https://mise-versions.jdx.dev/api/github/repos/jdx/ruby/releases/${release}")"
    case "${status}" in
      200)
        if jq -e --arg version "${candidate}" --arg release "${release}" '
          .tag_name == $release and
          any(.assets[]; .name == ("ruby-" + $version + ".x86_64_linux.tar.gz") and (.digest | test("^sha256:[0-9a-f]{64}$"))) and
          any(.assets[]; .name == ("ruby-" + $version + ".arm64_linux.tar.gz") and (.digest | test("^sha256:[0-9a-f]{64}$")))
        ' /tmp/mise-ruby-candidate-release.json >/dev/null; then
          mv /tmp/mise-ruby-candidate-release.json /tmp/mise-ruby-release.json
          candidate_release="${release}"
        fi
        ;;
      404) break ;;
      *) echo "Failed to resolve ${release}: HTTP ${status}" >&2; exit 1 ;;
    esac
    revision=$((revision + 1))
  done
  if [ -n "${candidate_release}" ]; then
    RUBY_VERSION="${candidate}"
    RUBY_SOURCE_RELEASE="${candidate_release}"
    break
  fi
done
test -n "${RUBY_VERSION}"
test -n "${RUBY_SOURCE_RELEASE}"

export RUBY_X64_ASSET="ruby-${RUBY_VERSION}.x86_64_linux.tar.gz"
export RUBY_ARM64_ASSET="ruby-${RUBY_VERSION}.arm64_linux.tar.gz"
export RUBY_X64_URL="$(jq -r --arg asset "${RUBY_X64_ASSET}" '.assets[] | select(.name == $asset) | .browser_download_url' /tmp/mise-ruby-release.json)"
export RUBY_ARM64_URL="$(jq -r --arg asset "${RUBY_ARM64_ASSET}" '.assets[] | select(.name == $asset) | .browser_download_url' /tmp/mise-ruby-release.json)"
export RUBY_X64_SHA256="$(jq -r --arg asset "${RUBY_X64_ASSET}" '.assets[] | select(.name == $asset) | .digest' /tmp/mise-ruby-release.json)"
export RUBY_ARM64_SHA256="$(jq -r --arg asset "${RUBY_ARM64_ASSET}" '.assets[] | select(.name == $asset) | .digest' /tmp/mise-ruby-release.json)"

mkdir /tmp/mise-ruby-project
cat >/tmp/mise-ruby-project/mise.toml <<TOML
[tools]
ruby = "${RUBY_VERSION}"

[settings]
lockfile = true
ruby.compile = false
TOML
cat >/tmp/mise-ruby-project/mise.lock <<TOML
[[tools.ruby]]
version = "${RUBY_VERSION}"
backend = "core:ruby"

[tools.ruby.options]
compile = "false"
precompiled_url = "jdx/ruby"
ruby_build_repo = "https://github.com/rbenv/ruby-build.git"
ruby_install = "false"

[tools.ruby."platforms.linux-x64"]
url = "${RUBY_X64_URL}"
checksum = "${RUBY_X64_SHA256}"

[tools.ruby."platforms.linux-arm64"]
url = "${RUBY_ARM64_URL}"
checksum = "${RUBY_ARM64_SHA256}"
TOML

canonical_mise install "node@${NODE_20_VERSION}"
canonical_mise install "node@${NODE_24_VERSION}"
canonical_mise install "go@${GO_124_VERSION}"
canonical_mise install "go@${GO_125_VERSION}"
canonical_mise install "go@${GO_126_VERSION}"
canonical_mise trust /tmp/mise-ruby-project/mise.toml
(
  cd /tmp/mise-ruby-project
  export MISE_ALWAYS_KEEP_DOWNLOAD=1
  canonical_mise install --locked
)

export RUBY_ARCHIVE="${TOOLCHAIN_DATA_DIR}/downloads/ruby/${RUBY_VERSION}/${RUBY_X64_ASSET}"
export RUBY_ARCHIVE_SHA256="${RUBY_X64_SHA256#sha256:}"
if [ "${DEBIAN_ARCH}" = "arm64" ]; then
  RUBY_ARCHIVE="${TOOLCHAIN_DATA_DIR}/downloads/ruby/${RUBY_VERSION}/${RUBY_ARM64_ASSET}"
  RUBY_ARCHIVE_SHA256="${RUBY_ARM64_SHA256#sha256:}"
fi
test -f "${RUBY_ARCHIVE}"
test ! -L "${RUBY_ARCHIVE}"
echo "${RUBY_ARCHIVE_SHA256}  ${RUBY_ARCHIVE}" | sha256sum --check
rm -rf "${TOOLCHAIN_DATA_DIR}/downloads"

register_tool() {
  local mise_tool="$1"
  local toolcache_tool="$2"
  local version="$3"
  local executable="$4"
  local canonical_root="${TOOLCHAIN_DATA_DIR}/installs/${mise_tool}/${version}"
  local mise_root="/mise/installs/${mise_tool}/${version}"
  local toolcache_version_root="/opt/hostedtoolcache/${toolcache_tool}/${version}"
  local toolcache_root="${toolcache_version_root}/${TOOLCACHE_ARCH}"

  test -d "${canonical_root}"
  test ! -L "${canonical_root}"
  test -f "${canonical_root}/${executable}"
  test ! -L "${canonical_root}/${executable}"

  mise link "${mise_tool}@${version}" "${canonical_root}"
  test -L "${mise_root}"
  test "$(readlink -f "${mise_root}")" = "${canonical_root}"

  mkdir -p "${toolcache_version_root}"
  ln -s "${canonical_root}" "${toolcache_root}"
  test -L "${toolcache_root}"
  test "$(readlink -f "${toolcache_root}")" = "${canonical_root}"
}

register_tool node node "${NODE_20_VERSION}" bin/node
register_tool node node "${NODE_24_VERSION}" bin/node
register_tool go go "${GO_124_VERSION}" bin/go
register_tool go go "${GO_125_VERSION}" bin/go
register_tool go go "${GO_126_VERSION}" bin/go
register_tool ruby Ruby "${RUBY_VERSION}" bin/ruby

test ! -e /mise/bin/mise

for version in "${NODE_20_VERSION}" "${NODE_24_VERSION}"; do
  canonical_root="${TOOLCHAIN_DATA_DIR}/installs/node/${version}"
  test "$(readlink -f "$(mise where "node@${version}")")" = "${canonical_root}"
  test "$(mise exec "node@${version}" -- node --version)" = "v${version}"
  EXPECTED_NODE_VERSION="${version}" mise exec "node@${version}" -- node -e \
    'if (process.versions.node !== process.env.EXPECTED_NODE_VERSION) process.exit(1)'
done

cat >/tmp/mise-go-smoke.go <<'GO'
package main

import "fmt"

func main() { fmt.Print("mise-go-ok") }
GO

for version in "${GO_124_VERSION}" "${GO_125_VERSION}" "${GO_126_VERSION}"; do
  canonical_root="${TOOLCHAIN_DATA_DIR}/installs/go/${version}"
  test "$(readlink -f "$(mise where "go@${version}")")" = "${canonical_root}"
  test "$(mise exec "go@${version}" -- go env GOVERSION)" = "go${version}"
  test "$(mise exec "go@${version}" -- go run /tmp/mise-go-smoke.go)" = mise-go-ok
done

export RUBY_ROOT="${TOOLCHAIN_DATA_DIR}/installs/ruby/${RUBY_VERSION}"
test "$(readlink -f "$(mise where "ruby@${RUBY_VERSION}")")" = "${RUBY_ROOT}"
EXPECTED_RUBY_VERSION="${RUBY_VERSION}" EXPECTED_RUBY_ROOT="${RUBY_ROOT}" \
  mise exec "ruby@${RUBY_VERSION}" -- ruby -ropenssl -rrbconfig -e \
  'abort unless RUBY_VERSION == ENV.fetch("EXPECTED_RUBY_VERSION"); abort unless File.realpath(RbConfig::CONFIG.fetch("prefix")) == ENV.fetch("EXPECTED_RUBY_ROOT")'
mise exec "ruby@${RUBY_VERSION}" -- gem --version
mise exec "ruby@${RUBY_VERSION}" -- bundle --version

mkdir /tmp/mise-ruby-native-extension
cat >/tmp/mise-ruby-native-extension/extconf.rb <<'RUBY'
require "mkmf"
create_makefile("mise_image_smoke")
RUBY
cat >/tmp/mise-ruby-native-extension/mise_image_smoke.c <<'C'
#include "ruby.h"

static VALUE ok(VALUE self) { return Qtrue; }

void Init_mise_image_smoke(void) {
  VALUE module = rb_define_module("MiseImageSmoke");
  rb_define_singleton_method(module, "ok?", ok, 0);
}
C
pushd /tmp/mise-ruby-native-extension
mise exec "ruby@${RUBY_VERSION}" -- ruby extconf.rb
make
mise exec "ruby@${RUBY_VERSION}" -- ruby -I. -rmise_image_smoke -e \
  'abort unless MiseImageSmoke.ok?'
popd

jq -n \
  --arg architecture "${DEBIAN_ARCH}" \
  --arg toolcache_architecture "${TOOLCACHE_ARCH}" \
  --arg mise_version "${MISE_VERSION#v}" \
  --arg mise_sha256 "$(sha256sum /usr/local/bin/mise | awk '{print $1}')" \
  --arg root "${TOOLCHAIN_DATA_DIR}" \
  --arg node20 "${NODE_20_VERSION}" \
  --arg node24 "${NODE_24_VERSION}" \
  --arg go124 "${GO_124_VERSION}" \
  --arg go125 "${GO_125_VERSION}" \
  --arg go126 "${GO_126_VERSION}" \
  --arg ruby "${RUBY_VERSION}" \
  --arg ruby_source_release "${RUBY_SOURCE_RELEASE}" \
  'def tool($name; $version; $executable): {
    tool: $name,
    version: $version,
    canonical_root: ($root + "/installs/" + $name + "/" + $version),
    executable: ($root + "/installs/" + $name + "/" + $version + "/" + $executable)
  } | .executable_sha256 = (input);
  {
    schema_version: 1,
    architecture: $architecture,
    toolcache_architecture: $toolcache_architecture,
    canonical_data_dir: $root,
    mise: {
      version: $mise_version,
      executable: "/usr/local/bin/mise",
      executable_sha256: $mise_sha256
    },
    toolchains: [
      tool("node"; $node20; "bin/node"),
      tool("node"; $node24; "bin/node"),
      tool("go"; $go124; "bin/go"),
      tool("go"; $go125; "bin/go"),
      tool("go"; $go126; "bin/go"),
      (tool("ruby"; $ruby; "bin/ruby") + {source_release: $ruby_source_release})
    ]
  }' \
  < <(
    sha256sum \
      "${TOOLCHAIN_DATA_DIR}/installs/node/${NODE_20_VERSION}/bin/node" \
      "${TOOLCHAIN_DATA_DIR}/installs/node/${NODE_24_VERSION}/bin/node" \
      "${TOOLCHAIN_DATA_DIR}/installs/go/${GO_124_VERSION}/bin/go" \
      "${TOOLCHAIN_DATA_DIR}/installs/go/${GO_125_VERSION}/bin/go" \
      "${TOOLCHAIN_DATA_DIR}/installs/go/${GO_126_VERSION}/bin/go" \
      "${TOOLCHAIN_DATA_DIR}/installs/ruby/${RUBY_VERSION}/bin/ruby" |
      awk '{print "\"" $1 "\""}'
  ) >"${TOOLCHAIN_DATA_DIR}/manifest.json"

test "$(jq -r '.mise.version' "${TOOLCHAIN_DATA_DIR}/manifest.json")" = "$(mise --version | awk '{print $1}')"
while IFS=$'\t' read -r tool version canonical_root executable executable_sha256; do
  test -d "${canonical_root}"
  test ! -L "${canonical_root}"
  test -f "${executable}"
  test ! -L "${executable}"
  test "$(sha256sum "${executable}" | awk '{print $1}')" = "${executable_sha256}"
  case "${tool}" in
    node) reported_version="$("${executable}" --version)"; reported_version="${reported_version#v}" ;;
    go) reported_version="$("${executable}" env GOVERSION)"; reported_version="${reported_version#go}" ;;
    ruby) reported_version="$("${executable}" -e 'print RUBY_VERSION')" ;;
  esac
  test "${reported_version}" = "${version}"
done < <(jq -r '.toolchains[] | [.tool, .version, .canonical_root, .executable, .executable_sha256] | @tsv' "${TOOLCHAIN_DATA_DIR}/manifest.json")

mark_complete() {
  local toolcache_tool="$1"
  local version="$2"
  local marker="/opt/hostedtoolcache/${toolcache_tool}/${version}/${TOOLCACHE_ARCH}.complete"
  test ! -e "${marker}"
  : >"${marker}"
  test -f "${marker}"
  test ! -s "${marker}"
}

mark_complete node "${NODE_20_VERSION}"
mark_complete node "${NODE_24_VERSION}"
mark_complete go "${GO_124_VERSION}"
mark_complete go "${GO_125_VERSION}"
mark_complete go "${GO_126_VERSION}"
mark_complete Ruby "${RUBY_VERSION}"

rm -rf /mise/cache /tmp/mise-cache /tmp/mise-config \
  /tmp/mise-go-smoke.go /tmp/mise-ruby-native-extension \
  /tmp/mise-ruby-project /tmp/mise-ruby-release.json \
  /tmp/mise-ruby-candidate-release.json

# install aws-cli
curl https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}.zip -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /opt
/opt/aws/install --update -i /usr/local/aws-cli -b /usr/local/bin
rm -rf /tmp/awscliv2.zip /opt/aws
aws --version

# install GCP CLI
#
# with workaround for arm64 https://issuetracker.google.com/issues/383568269
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
apt-get update
apt-get install -y google-cloud-cli=502.0.0-0
gcloud --version

# install nodejs
git clone https://github.com/tj/n /usr/src/n
pushd /usr/src/n
make install
popd
n lts
rm -rf /usr/src/n /tmp/*
node --version

ln -s /usr/bin/tini /usr/sbin/tini

apt clean all

# Clean up apt cache
rm -rf /var/lib/apt/lists/*
BASH


FROM base

WORKDIR /root
USER root
