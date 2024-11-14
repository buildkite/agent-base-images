# syntax=docker/dockerfile:1.4

FROM public.ecr.aws/docker/library/alpine:latest AS kubectl-downloader
ARG TARGETOS
ARG TARGETARCH

ENV K8_VERSION=v1.31.0

RUN <<EOF
set -eu
wget -qO kubectl \
    "https://storage.googleapis.com/kubernetes-release/release/$K8_VERSION/bin/linux/$TARGETARCH/kubectl"
chmod +x kubectl
EOF

FROM public.ecr.aws/docker/library/alpine:latest AS kustomize-downloader
ARG TARGETOS
ARG TARGETARCH

RUN <<EOF
set -eu

apk update
apk add jq
URL=$(wget -qO- https://api.github.com/repos/kubernetes-sigs/kustomize/releases | jq -r '.[] | select(has("assets") and .assets != []) | .assets[].browser_download_url' | grep "${TARGETOS}_${TARGETARCH}" | head)
wget -qO- $URL | tar xz
EOF

FROM public.ecr.aws/docker/library/alpine:latest

RUN apk update && apk add --no-cache \
    bash \
    curl \
    docker-cli \
    docker-cli-buildx \
    docker-cli-compose \
    git \
    jq \
    libc6-compat \
    openssh-client \
    perl \
    py-pip \
    rsync \
    run-parts \
    su-exec \
    tini \
    tini-static \
    tzdata

COPY docker-compose /usr/local/bin/docker-compose

COPY --from=kubectl-downloader /kubectl /usr/local/bin/kubectl
COPY --from=kustomize-downloader /kustomize /usr/local/bin/kustomize
