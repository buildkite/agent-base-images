#!/usr/bin/env bash

# Usage:
# generate-variant-group-yml.sh <variant> | buildkite-agent pipeline upload
# e.g. generate-variant-group-yml.sh alpine-k8s | buildkite-agent pipeline upload
#
# Generates the dynamic pipeline YAML Group Step for a variant and outputs to STDOUT.
# It runs `build-docker-base-image.sh` per <arch>.
# When PUSH_IMAGE=true, the images are pushed and `publish-multiarch-manifest.sh`
# publishes a multiarch variant of the image to Docker Hub and ECR.

set -Eeufo pipefail

variant="${1:?variant required}"

# Validate variant — same regex as build-docker-base-image.sh
if [[ ! "${variant}" =~ ^(alpine|alpine-k8s|ubuntu-(focal|jammy|jammy-hosted|noble|noble-hosted|resolute))$ ]]; then
    echo "Unknown image variant '${variant}'" >&2
    exit 1
fi

# Reusable anchor
cat <<EOF
anchor_1: &build-and-publish-variant
  agents:
    queue: "${AGENT_BUILDERS_QUEUE}"
  env:
    PUSH_IMAGE: "${PUSH_IMAGE:-}"
  plugins:
    - aws-assume-role-with-web-identity#v1.4.0:
        role_arn: "arn:aws:iam::\${BUILD_AWS_ACCOUNT_ID}:role/\${BUILD_AWS_ROLE_NAME}"
        session-tags:
          - organization_slug
          - organization_id
          - pipeline_slug
    - ecr#v2.9.0:
        login: true
        account_ids: "public.ecr.aws"
EOF


# Emit secret in anchor if pushing image
if [[ "${PUSH_IMAGE:-}" == "true" ]]; then
cat <<EOF
  secrets:
    - AGENT_BASE_IMAGES_DOCKER_HUB_TOKEN
EOF
fi

# Emit start of Step Group
cat <<EOF
steps:
  - group: ":docker: ${variant}"
    key: "build-${variant}"
    steps:
EOF

# Emit one `build` step per arch
for arch in amd64 arm64; do
    cat <<EOF
      - <<: *build-and-publish-variant
        label: ":docker: Build ${variant} ${arch} base image"
        agents:
          queue: "agent-runners-linux-${arch}"
        command: ".buildkite/steps/build-docker-base-image.sh ${variant} ${arch}"
EOF
done

# Emit one `publish` step per variant behind a wait block if pushing image
if [[ "${PUSH_IMAGE:-}" == "true" ]]; then
    cat <<EOF
      - wait
      - <<: *build-and-publish-variant
        label: ":docker: Publish ${variant} multiarch manifest"
        command: ".buildkite/steps/publish-multiarch-manifest.sh ${variant}"
EOF
fi
