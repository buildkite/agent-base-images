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

variant="${1:-}"
arch="${2:-}"

# Validate variant
if [[ ! "${variant}" =~ ^(alpine|alpine-k8s|ubuntu-(focal|jammy|jammy-hosted|noble|noble-hosted|resolute))$ ]]; then
    echo "Unknown image variant '${variant}'"
    exit 1
fi

# Validate arch
if [[ ! "${arch}" =~ ^(amd64|arm64)$ ]]; then
    echo "Invalid arch '${arch}': must be amd64 or arm64"
    exit 1
fi

platform="linux/${arch}"
packaging_dir="${variant}"

echo "--- Build :docker: base image for ${variant} on ${platform}"

builder_name="$(docker buildx create --use)"
# shellcheck disable=SC2064 # we want the current $builder_name to be trapped, not the runtime one
trap "docker buildx rm ${builder_name} || true" EXIT

echo "--- Copy files into build context"
cp common/docker-compose "${packaging_dir}"

push="${PUSH_IMAGE:-true}"

if [[ "${push}" != "true" ]]; then
    echo "--- :docker: Building ${variant}-${arch} (no push)"
    docker buildx build \
        --progress plain \
        --builder "${builder_name}" \
        --platform "${platform}" \
        "${packaging_dir}"
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
    "${packaging_dir}"

digest="$(jq -r '."containerimage.digest"' "${metadata_file}")"

echo "--- :docker: Pushed digests"
echo "  Digest:     ${digest}"
echo "  Docker Hub: ${dockerhub_registry}@${digest}"
echo "  ECR:        ${ecr_registry}@${digest}"

buildkite-agent meta-data set "image-digest-${variant}-${arch}" "${digest}"
