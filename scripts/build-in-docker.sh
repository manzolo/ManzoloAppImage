#!/usr/bin/env bash
# Build one of the examples inside the manzolo-appimage-builder container.
# Usage: ./scripts/build-in-docker.sh <example-dir-name>
# Example: ./scripts/build-in-docker.sh 01-go-cli

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

if [[ $# -lt 1 ]]; then
    log_error "Usage: $0 <example-dir-name>"
    log_error "Available examples:"
    for d in "${REPO_ROOT}"/examples/*/; do
        printf '  - %s\n' "$(basename "$d")" >&2
    done
    exit 2
fi

EXAMPLE="$1"
EXAMPLE_DIR="${REPO_ROOT}/examples/${EXAMPLE}"
IMAGE_NAME="${IMAGE_NAME:-manzolo-appimage-builder}:${IMAGE_TAG:-latest}"

if [[ ! -d "$EXAMPLE_DIR" ]]; then
    log_error "Example directory not found: $EXAMPLE_DIR"
    exit 2
fi
if [[ ! -x "$EXAMPLE_DIR/build.sh" ]]; then
    log_error "Example is missing an executable build.sh: $EXAMPLE_DIR/build.sh"
    exit 2
fi

# Verify the builder image exists. Suggest 'make image' if not.
if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    log_error "Docker image '$IMAGE_NAME' not found. Run: make image"
    exit 1
fi

mkdir -p "${REPO_ROOT}/out"

log_info "Building example: ${C_CYAN}${EXAMPLE}${C_RESET}"
log_info "Using image:      ${IMAGE_NAME}"

# Pass through UID/GID so files written by the container belong to the host user.
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

docker run --rm \
    -v "${REPO_ROOT}:/work" \
    -w "/work" \
    -e EXAMPLE="${EXAMPLE}" \
    -e APPIMAGE_EXTRACT_AND_RUN=1 \
    -e HOST_UID="${HOST_UID}" \
    -e HOST_GID="${HOST_GID}" \
    "${IMAGE_NAME}" \
    bash -c '
        set -euo pipefail
        cd "/work/examples/${EXAMPLE}"
        bash ./build.sh
        # Fix ownership of anything created so the host user can read/delete it.
        chown -R "${HOST_UID}:${HOST_GID}" "/work/out" "/work/examples/${EXAMPLE}" 2>/dev/null || true
    '

log_ok "AppImage(s) produced under: ${REPO_ROOT}/out/"
ls -la "${REPO_ROOT}/out/"
