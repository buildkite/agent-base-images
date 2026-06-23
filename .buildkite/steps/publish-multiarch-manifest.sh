#!/usr/bin/env bash

# Usage:
# publish-multiarch-manifest.sh <variant>
# e.g. publish-multiarch-manifest.sh alpine-k8s
#
# Publishes a multiarch manifest list for a variant to Docker Hub and ECR by
# combining the per-arch image digests stored in Buildkite meta-data.

set -Eeufo pipefail

# shellcheck source=.buildkite/steps/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

variant="${1:?variant required}"

# Validate variant
validate_variant "${variant}"

# Arches to publish
arches=(amd64 arm64)

if [[ -z "${BUILDKITE_BUILD_NUMBER:-}" ]]; then
    echo "BUILDKITE_BUILD_NUMBER is not set" >&2
    exit 1
fi

# Compute image tags
variant_tag="${variant}"
build_tag="${variant}-build-${BUILDKITE_BUILD_NUMBER}"

echo "--- :docker: Resolve per-arch digests for ${variant}"
echo "  Variant: ${variant}"
echo "  Arches:  ${arches[*]}"
echo "  Tags:    ${variant_tag}, ${build_tag}"

# Resolve digests from Buildkite meta-data
declare -A digests=()
for arch in "${arches[@]}"; do
    meta_key="image-digest-${variant}-${arch}"
    digest="$(buildkite-agent meta-data get "${meta_key}")"
    if [[ -z "${digest}" ]]; then
        echo "Expected meta-data key '${meta_key}' is empty or missing" >&2
        exit 1
    fi
    echo "  ${arch}: ${digest}"
    digests["${arch}"]="${digest}"
done

dockerhub_registry="docker.io/buildkite/agent-base"
ecr_registry="public.ecr.aws/buildkite/agent-base"

# Login to Docker Hub. ECR login handled by `ecr` pipeline plugin.
echo "${AGENT_BASE_IMAGES_DOCKER_HUB_TOKEN}" | docker login --username=buildkite --password-stdin

# Publish multiarch manifest to each registry
for registry in "${dockerhub_registry}" "${ecr_registry}"; do
    echo "--- :docker: Publishing manifest list to ${registry}"

    # Build source list: registry@digest for each arch
    sources=()
    for arch in "${arches[@]}"; do
        sources+=("${registry}@${digests[${arch}]}")
    done

    docker buildx imagetools create \
        -t "${registry}:${variant_tag}" \
        -t "${registry}:${build_tag}" \
        "${sources[@]}"

    echo "--- :docker: Inspecting manifest list on ${registry}"
    docker buildx imagetools inspect "${registry}:${variant_tag}"
done
