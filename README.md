# agent-base-images

Scheduled builds of container images with base software installed, used as bases
for the [agent container images](https://hub.docker.com/r/buildkite/agent).

If you are looking for the Buildkite Agent, head over to the
[agent repo](https://github.com/buildkite/agent).

### Why Ubuntu codenames?

This makes Dependabot slightly easier to work with. When tagged with version
numbers, Dependabot likes to upgrade e.g. Ubuntu 20.04 to 24.04, when the goal
is to offer an image based on the older LTS release.
