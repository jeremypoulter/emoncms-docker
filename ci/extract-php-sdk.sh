#!/bin/bash
set -euo pipefail

image=${1:?usage: extract-php-sdk.sh <image> <platform> <destination>}
platform=${2:?missing platform}
destination=${3:?missing destination}

rm -rf "$destination"
mkdir -p "$destination/rootfs/usr/local/bin" \
    "$destination/rootfs/usr/local/include" \
    "$destination/rootfs/usr/local/lib/php" \
    "$destination/rootfs/usr/src" \
    "$destination/rootfs/etc"

docker pull --platform "$platform" "$image"
container=$(docker create --platform "$platform" "$image")
trap 'docker rm -f "$container" >/dev/null 2>&1 || true' EXIT

docker cp "$container:/usr/local/bin/phpize" "$destination/rootfs/usr/local/bin/phpize"
docker cp "$container:/usr/local/bin/php-config" "$destination/rootfs/usr/local/bin/php-config"
docker cp "$container:/usr/local/include/php" "$destination/rootfs/usr/local/include/php"
docker cp "$container:/usr/local/lib/php/build" "$destination/rootfs/usr/local/lib/php/build"
docker cp "$container:/usr/src/php.tar.xz" "$destination/rootfs/usr/src/php.tar.xz"
docker cp "$container:/usr/lib/os-release" "$destination/rootfs/etc/os-release"

test -f "$destination/rootfs/usr/local/include/php/main/php_config.h"
test -f "$destination/rootfs/usr/local/include/php/Zend/zend_modules.h"
test -f "$destination/rootfs/usr/src/php.tar.xz"
