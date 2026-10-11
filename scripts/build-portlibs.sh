#!/bin/bash
# Builds the custom Switch portlibs from scripts/switch/*/PKGBUILD, or installs
# ones built earlier. Runs as root inside the image from scripts/docker/
# (scripts/build.sh drives it), or on any machine with devkitPro pacman.
#
#   build-portlibs.sh build     build every package into $PORTLIBS_DIR, then install
#   build-portlibs.sh install   install the packages already in $PORTLIBS_DIR
#
# The order and flags follow Switchfin's switch-portlibs CI: the first group is
# built and installed as it goes (-si) because later packages link against it;
# mpv and curl are built (-s) and then installed with dkp-pacman -U. The stock
# switch-libmpv is removed first: it is 0.39, the custom one is 0.36.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORTLIBS_DIR="${PORTLIBS_DIR:-$ROOT/portlibs}"
WORK_DIR="${WORK_DIR:-/tmp/akintio-portlibs}"
BUILDER="${BUILDER:-builder}"

STAGE1=(mbedtls libssh2 dav1d ffmpeg libuam)
STAGE2=(mpv curl)

# What gets installed, in dependency order. libmpv-deko3d is built too (the mpv
# PKGBUILD makes both variants) but conflicts with the OpenGL one, which is
# what the app uses.
INSTALL=(switch-mbedtls switch-libssh2 switch-dav1d switch-ffmpeg libuam
         switch-libmpv switch-curl)

remove_stock_mpv() {
    if dkp-pacman -Q switch-libmpv >/dev/null 2>&1; then
        dkp-pacman -R --noconfirm switch-libmpv
    fi
}

pkg_file() {
    # The newest file for package name $1, excluding names that only share its
    # prefix (switch-libmpv vs switch-libmpv-deko3d).
    local f
    f=$(ls -1 "$PORTLIBS_DIR"/"$1"-[0-9m]*.pkg.tar.zst 2>/dev/null | sort -V | tail -n 1)
    [[ -n "$f" ]] || { echo "missing package $1 in $PORTLIBS_DIR" >&2; return 1; }
    echo "$f"
}

install_all() {
    remove_stock_mpv
    local files=()
    for p in "${INSTALL[@]}"; do files+=("$(pkg_file "$p")"); done
    dkp-pacman -U --noconfirm --needed "${files[@]}"
}

makepkg_as_builder() {
    local pkg=$1 flags=$2
    echo "==> building $pkg ($flags)"
    su - "$BUILDER" -c "cd '$WORK_DIR/$pkg' && dkp-makepkg $flags --noconfirm"
    cp "$WORK_DIR/$pkg"/*.pkg.tar.zst "$PORTLIBS_DIR/"
}

build_all() {
    mkdir -p "$PORTLIBS_DIR"
    rm -rf "$WORK_DIR"
    mkdir -p "$WORK_DIR"
    for pkg in "${STAGE1[@]}" "${STAGE2[@]}"; do
        cp -r "$ROOT/scripts/switch/$pkg" "$WORK_DIR/"
    done
    chown -R "$BUILDER:$BUILDER" "$WORK_DIR"

    remove_stock_mpv
    for pkg in "${STAGE1[@]}"; do makepkg_as_builder "$pkg" -siCf; done
    for pkg in "${STAGE2[@]}"; do makepkg_as_builder "$pkg" -sCf; done
    install_all

    (cd "$PORTLIBS_DIR" && sha256sum *.pkg.tar.zst > SHA256SUMS)
    echo "==> portlibs in $PORTLIBS_DIR"
}

case "${1:-build}" in
    build) build_all ;;
    install) install_all ;;
    *) echo "usage: $0 [build|install]" >&2; exit 2 ;;
esac
