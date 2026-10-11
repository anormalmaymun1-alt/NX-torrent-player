# Akıntio build image: the devkitPro toolchain pinned to the tag Switchfin's CI
# uses, plus what dkp-makepkg needs to build the custom portlibs in
# scripts/switch/ (scripts/build-portlibs.sh).
FROM devkitpro/devkita64:20260219

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        fakeroot zstd bison flex file libtool python3-mako meson sudo \
    && rm -rf /var/lib/apt/lists/* /usr/share/man/*

# dkp-makepkg refuses to run as root.
RUN useradd --create-home --shell /bin/bash builder \
    && echo 'builder ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/builder

# Not every build machine has a file system git trusts by uid.
RUN git config --system --add safe.directory '*'
