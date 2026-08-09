# Agent Base Images

Scheduled builds of container images with base software installed, 
used as bases for [Buildkite Agent](https://buildkite.com/docs/agent/self-hosted)
and [Buildkite Linux Hosted Agents](https://buildkite.com/docs/agent/buildkite-hosted).

These images are not intended to be used by customers directly, 
since they do not contain the Buildkite Agent or configuration, but 
are publicly available so that the contents and provenance of the 
base images are transparent.

Available at:
  - [**buildkite/agent-base** on Docker Hub](https://hub.docker.com/r/buildkite/agent-base)
  - [**buildkite/agent-base** on Amazon ECR Public Gallery](https://gallery.ecr.aws/buildkite/agent-base)

If you are looking for the Buildkite Agent, see the 
[buildkite/agent](https://github.com/buildkite/agent) repository.

## Standard Variants

Base Images for [Buildkite Agent container images](https://hub.docker.com/r/buildkite/agent).

Contains Docker tooling and other common system tools.

| Tag | Description |
| - | - |
| [alpine](https://hub.docker.com/layers/buildkite/agent-base/alpine)                   | Alpine base                                                         |
| [alpine-k8s](https://hub.docker.com/layers/buildkite/agent-base/alpine-k8s)           | Alpine base plus `kubectl` and `kustomize` for Kubernetes workloads |
| [ubuntu-focal](https://hub.docker.com/layers/buildkite/agent-base/ubuntu-focal)       | Ubuntu 20.04 LTS base                                               |
| [ubuntu-jammy](https://hub.docker.com/layers/buildkite/agent-base/ubuntu-jammy)       | Ubuntu 22.04 LTS base                                               |
| [ubuntu-noble](https://hub.docker.com/layers/buildkite/agent-base/ubuntu-noble)       | Ubuntu 24.04 LTS base                                               |
| [ubuntu-resolute](https://hub.docker.com/layers/buildkite/agent-base/ubuntu-resolute) | Ubuntu 26.04 base                                                   |

## Hosted Variants

Base Images for [Buildkite Linux Hosted Agents](https://buildkite.com/docs/agent/buildkite-hosted).

Contains python3, node, mise, buildkite-cli, aws-cli, google-cloud-cli, 
and other common system tools.

| Tag | Description |
| - | - |
| [ubuntu-jammy-hosted](https://hub.docker.com/layers/buildkite/agent-base/ubuntu-jammy-hosted) | Ubuntu 22.04 LTS base for Hosted Agents |
| [ubuntu-jammy-hosted-toolchains](https://hub.docker.com/layers/buildkite/agent-base/ubuntu-jammy-hosted-toolchains) | Ubuntu 22.04 LTS Hosted base with preloaded mise toolchains |
| [ubuntu-noble-hosted](https://hub.docker.com/layers/buildkite/agent-base/ubuntu-noble-hosted) | Ubuntu 24.04 LTS base for Hosted Agents |
| [ubuntu-noble-hosted-toolchains](https://hub.docker.com/layers/buildkite/agent-base/ubuntu-noble-hosted-toolchains) | Ubuntu 24.04 LTS Hosted base with preloaded mise toolchains |

### Preloaded Hosted toolchains

The opt-in `ubuntu-jammy-hosted-toolchains` and
`ubuntu-noble-hosted-toolchains` variants preload a common toolchain using
mise. The corresponding Hosted variants without the `-toolchains` suffix
remain the smaller default images.

The preloaded toolchain contains:

- Node.js 20.20.2 and 24.18.0
- the latest patch release from each supported Go 1.24, 1.25, and 1.26 line
- the latest stable Ruby for which mise has a precompiled binary

The Go and Ruby versions are resolved to exact versions during each image
build. Each toolchain image records those versions, its architecture, the
pinned mise version, canonical install roots, and executable SHA-256 digests in
`/opt/buildkite/mise-toolchains/manifest.json`.

Toolchain bytes live only under `/opt/buildkite/mise-toolchains/installs`.
Native mise discovers the same installs through links under `/mise/installs`.
The matching `/opt/hostedtoolcache` entries provide the case-sensitive
Actions tool-cache layout (`node`, `go`, and `Ruby`) without copying the SDKs.
This compatibility layout is not a claim of full GitHub-hosted Ubuntu image
parity.

The toolchain images keep mise itself at `/usr/local/bin/mise`; they do not
install `/mise/bin/mise`, so `jdx/mise-action` remains free to install its
requested mise version. Reusing the preloaded toolchains from
`jdx/mise-action` still requires the workload runtime to preserve
`MISE_DATA_DIR=/mise`. These images provide the seed and filesystem layout but
do not configure `buildkite-gha`.

### Why Ubuntu codenames?

This makes Dependabot slightly easier to work with. When tagged with version
numbers, Dependabot likes to upgrade e.g. Ubuntu 20.04 to 24.04, when the goal
is to offer an image based on the older LTS release.
