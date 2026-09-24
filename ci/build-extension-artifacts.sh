#!/bin/bash
set -euo pipefail

image=${1:?usage: build-extension-artifacts.sh <php-image> <amd64|arm64> <output>}
architecture=${2:?missing architecture}
output=${3:?missing output directory}
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
sdk=$(mktemp -d)
trap 'rm -rf "$sdk"' EXIT

case "$architecture" in
    amd64)
        platform=linux/amd64
        packages="gcc g++ libc6-dev libmosquitto-dev"
        ;;
    arm64)
        platform=linux/arm64
        packages="gcc-aarch64-linux-gnu g++-aarch64-linux-gnu libc6-dev:arm64 libmosquitto-dev:arm64"
        ;;
    *)
        printf 'Unsupported architecture: %s\n' "$architecture" >&2
        exit 2
        ;;
esac

"$root/ci/extract-php-sdk.sh" "$image" "$platform" "$sdk"
suite=$(sh -c '. "$1"; printf "%s" "$VERSION_CODENAME"' sh "$sdk/rootfs/etc/os-release")
mkdir -p "$output"

docker run --rm --platform linux/amd64 \
    -v "$root:/workspace" \
    -v "$sdk/rootfs:/php-root:ro" \
    -v "$output:/out" \
    -w /workspace \
    "debian:$suite" \
    bash -euxo pipefail -c "
        dpkg --add-architecture arm64
        apt-get update
        apt-get install -y --no-install-recommends \\
            autoconf automake binutils ca-certificates file git libtool make pkg-config xz-utils \\
            $packages
        ./ci/build-php-extensions.sh '$architecture' /php-root /out
    "
