#!/bin/bash
# Builds the Switch .nro in Docker, from a clean checkout:
#   1. builds the image in scripts/docker/ (devkitPro toolchain, pinned tag)
#   2. builds the custom portlibs once into portlibs/ (slow: ffmpeg and mpv)
#   3. installs them in a fresh container and builds the .nro in build_switch/
#
#   scripts/build.sh             everything above, portlibs only if missing
#   scripts/build.sh portlibs    force a portlib rebuild
#
# Environment:
#   IMAGE          image tag to build and use (default akintio-build)
#   TARGET         make target (default: <project>.nro, read from CMakeLists.txt)
#   CMAKE_ARGS     extra configure options
#   EXTRA_CA_CERT  a PEM file to trust inside the container (an HTTPS proxy's CA)
#   DOCKER_ARGS    extra `docker run` options (e.g. --network host)
#   DOCKERHUB_USER, DOCKERHUB_TOKEN
#                  log in to Docker Hub before pulling the base image (anonymous
#                  pulls are rate-limited per IP)
# http_proxy / https_proxy / no_proxy are passed through when set.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${IMAGE:-akintio-build}"
PROJECT="$(sed -n 's/^project(\([A-Za-z0-9_-]*\).*/\1/p' "$ROOT/CMakeLists.txt" | head -n 1)"
TARGET="${TARGET:-$PROJECT.nro}"
CMAKE_ARGS="${CMAKE_ARGS:-}"

if [[ -n "${DOCKERHUB_USER:-}" && -n "${DOCKERHUB_TOKEN:-}" ]]; then
    printf '%s' "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USER" --password-stdin >/dev/null
fi
docker build -t "$IMAGE" "$ROOT/scripts/docker"

# shellcheck disable=SC2206 # DOCKER_ARGS is split on purpose
run=(docker run --rm -v "$ROOT":/project -w /project ${DOCKER_ARGS:-})
for v in http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY; do
    if [[ -n "${!v:-}" ]]; then run+=(-e "$v=${!v}"); fi
done
trust=""
if [[ -n "${EXTRA_CA_CERT:-}" ]]; then
    run+=(-v "$(realpath "$EXTRA_CA_CERT")":/usr/local/share/ca-certificates/extra-ca.crt:ro)
    trust="update-ca-certificates >/dev/null && "
fi
# Hand the outputs back to whoever ran the script, not root.
owner="chown -R $(id -u):$(id -g) portlibs build_switch 2>/dev/null || true"

if [[ "${1:-}" == portlibs ]] || ! ls "$ROOT"/portlibs/switch-libmpv-0*.pkg.tar.zst >/dev/null 2>&1; then
    "${run[@]}" "$IMAGE" bash -c "${trust}scripts/build-portlibs.sh build; status=\$?; $owner; exit \$status"
fi

"${run[@]}" "$IMAGE" bash -c "${trust}scripts/build-portlibs.sh install \
    && cmake -B build_switch -DPLATFORM_SWITCH=ON -DBUILTIN_NSP=OFF $CMAKE_ARGS \
    && make -C build_switch '$TARGET' -j\$(nproc); status=\$?; $owner; exit \$status"

echo "==> $ROOT/build_switch/$TARGET"
