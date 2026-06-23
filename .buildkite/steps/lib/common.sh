#!/usr/bin/env bash
#
# Shared helpers for .buildkite/steps/*.sh
#
# This file must produce NO output when sourced, because some
# callers pipe their STDOUT to `buildkite-agent pipeline upload`.

VARIANT_REGEX='^(alpine|alpine-k8s|ubuntu-(focal|jammy|jammy-hosted|noble|noble-hosted|resolute))$'

# validate_variant <variant>
# Returns 0 if the variant is valid, otherwise prints an error to stderr and
# returns 1. Produces no output on success.
validate_variant() {
    local variant="${1:-}"
    if [[ ! "${variant}" =~ ${VARIANT_REGEX} ]]; then
        echo "Unknown image variant '${variant}'" >&2
        return 1
    fi
}
