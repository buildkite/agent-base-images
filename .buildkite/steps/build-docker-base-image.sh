#!/usr/bin/env bash

set -Eeufo pipefail

variant="${1:-}"
image_tag="${2:-latest}"
push="${PUSH_IMAGE:-true}"

if [[ ! "${variant}" =~ ^(alpine|alpine-k8s|ubuntu-20\.04|ubuntu-22\.04|ubuntu-24\.04)$ ]]; then
    echo "Unknown image variant ${variant}"
    exit 1
fi

# Disable pushing if run manually
if [[ -n "${image_tag}" ]]; then
    push="false"
fi

packaging_dir="${variant}"

echo "--- Building :docker: base image for ${variant}"

builder_name="$(docker buildx create --use)"
# shellcheck disable=SC2064 # we want the current $builder_name to be trapped, not the runtime one
trap "docker buildx rm ${builder_name} || true" EXIT

echo "--- Building :docker: ${image_tag} base for all architectures"
docker buildx build --progress plain --builder "${builder_name}" --platform linux/amd64,linux/arm64 "${packaging_dir}"

# Tag images for just the native architecture. There is a limitation in docker that prevents this
# from being done in one command. Luckliy the second build will be quick because of docker layer caching
# As this is just a native build, we don't need the lock.
docker buildx build --progress plain --builder "${builder_name}" --tag "${image_tag}" --load "${packaging_dir}"

if [[ "${push}" != "true" ]]; then
    exit 0
fi

echo --- :ecr: Pushing to ECR
# Do another build with all architectures. The layers should be cached from the previous build
# with all architectures.
# Pushing to the docker registry in this way greatly simplifies creating the manifest list on
# the docker registry so that either architecture can be pulled with the same tag.
docker buildx build \
    --progress plain \
    --builder "${builder_name}" \
    --tag "${image_tag}" \
    --platform linux/amd64,linux/arm64 \
    --push \
    "${packaging_dir}"