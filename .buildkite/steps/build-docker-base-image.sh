#!/usr/bin/env bash
#
# Usage:
# build-docker-base-image.sh <variant> <arch>
# e.g. build-docker-base-image.sh alpine-k8s arm64
#
# Builds the base image for a given variant and arch.
# When PUSH_IMAGE=true, it pushes the image to Docker Hub and ECR
# and records the image digest in Buildkite meta-data.

set -Eeufo pipefail

# shellcheck source=.buildkite/steps/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

variant="${1:?variant required}"
arch="${2:-}"

# Validate variant
validate_variant "${variant}"

# Validate arch
if [[ ! "${arch}" =~ ^(amd64|arm64)$ ]]; then
    echo "Invalid arch '${arch}': must be amd64 or arm64"
    exit 1
fi

platform="linux/${arch}"
packaging_dir="${variant}"

# `-toolchains` variants are virtual, so rewrite packaging_dir to their real parents
if [[ "${variant}" == *-toolchains ]]; then
    packaging_dir="${variant%-toolchains}" # e.g. ubuntu-jammy-hosted-toolchains → ubuntu-jammy-hosted
fi

build_context="${packaging_dir}"
build_args=()

# - Rewrite `build_context` here because these images need access to common/install-mise-toolchains.sh
# - Rewrite `build_args` here to adapt to new `build_context` and to specify custom --target for `toolchains`
case "${variant}" in
    ubuntu-jammy-hosted|ubuntu-noble-hosted)
        build_context="."
        build_args=(--file "${packaging_dir}/Dockerfile")
        ;;
    ubuntu-jammy-hosted-toolchains|ubuntu-noble-hosted-toolchains)
        build_context="."
        build_args=(--file "${packaging_dir}/Dockerfile" --target toolchains)
        ;;
esac

echo "--- Build :docker: base image for ${variant} on ${platform}"

builder_name="$(docker buildx create --use)"
# shellcheck disable=SC2064 # we want the current $builder_name to be trapped, not the runtime one
trap "docker buildx rm ${builder_name} || true" EXIT

if [[ "${build_context}" != "." ]]; then
    echo "--- Copy files into build context"
    cp common/docker-compose "${packaging_dir}"
fi

if [[ "${PUSH_IMAGE:-}" != "true" ]]; then
    echo "--- :docker: Building ${variant}-${arch} (no push)"
    docker buildx build \
        --progress plain \
        --builder "${builder_name}" \
        --platform "${platform}" \
        "${build_args[@]}" \
        "${build_context}"
    exit 0
fi

metadata_file="${BUILDKITE_BUILD_CHECKOUT_PATH:-.}/metadata-${variant}-${arch}.json"

echo "--- :docker: Build and push ${variant} (${platform}) by digest"

dockerhub_registry="docker.io/buildkite/agent-base"
ecr_registry="public.ecr.aws/buildkite/agent-base"

# Login to Docker Hub. ECR login handled by `ecr` pipeline plugin.
echo "${AGENT_BASE_IMAGES_DOCKER_HUB_TOKEN}" | docker login --username=buildkite --password-stdin

# Push both registries in a single build using comma-separated name= entries.
docker buildx build \
    --progress plain \
    --builder "${builder_name}" \
    --platform "${platform}" \
    --metadata-file "${metadata_file}" \
    --output "type=image,\"name=${dockerhub_registry},${ecr_registry}\",push-by-digest=true,name-canonical=true,push=true" \
    "${build_args[@]}" \
    "${build_context}"

digest="$(jq -r '."containerimage.digest"' "${metadata_file}")"

echo "--- :docker: Pushed digests"
echo "  Digest:     ${digest}"
echo "  Docker Hub: ${dockerhub_registry}@${digest}"
echo "  ECR:        ${ecr_registry}@${digest}"

buildkite-agent meta-data set "image-digest-${variant}-${arch}" "${digest}"
