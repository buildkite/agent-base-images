# ubuntu-noble-hosted-toolchains

This variant has no separate Dockerfile. It is built from the `toolchains`
target in [`../ubuntu-noble-hosted/Dockerfile`](../ubuntu-noble-hosted/Dockerfile),
selected by
[`build-docker-base-image.sh`](../.buildkite/steps/build-docker-base-image.sh).
