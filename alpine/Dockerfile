FROM public.ecr.aws/docker/library/alpine:3.20.3@sha256:beefdbd8a1da6d2915566fde36db9db0b524eb737fc57cd1367effd16dc0d06d

RUN apk add --no-cache \
    bash \
    curl \
    docker-cli \
    docker-cli-compose \
    docker-cli-buildx \
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
