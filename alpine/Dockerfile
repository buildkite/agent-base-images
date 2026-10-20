FROM public.ecr.aws/docker/library/alpine:latest

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
    openssl \
    perl \
    py-pip \
    rsync \
    run-parts \
    su-exec \
    tini \
    tini-static \
    tzdata

# Distrust roots chaining to compromised eMudhra intermediates.
# https://emudhra.we-have-a-problem.com/
RUN apk add --no-cache --upgrade ca-certificates ca-certificates-bundle && \
    sed -i \
        -e 's|^mozilla/emSign_ECC_Root_CA_-_G3.crt|!&|' \
        -e 's|^mozilla/Comodo_AAA_Services_root.crt|!&|' \
        /etc/ca-certificates.conf && update-ca-certificates

COPY docker-compose /usr/local/bin/docker-compose
