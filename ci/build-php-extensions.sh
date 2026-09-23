#!/bin/bash
set -euo pipefail

target_arch=${1:?usage: build-php-extensions.sh <amd64|arm64> <php-root> <output>}
php_root=${2:?missing extracted PHP root}
output=${3:?missing output directory}

PHPREDIS_COMMIT=df4fab2de7fc327c54c94a13af2b9542e4fbd720
MOSQUITTO_PHP_COMMIT=426a08afc452a5779a1404ffb875aed375431dfa
PHP_API_EXPECTED=20240924

case "$target_arch" in
    amd64)
        host=x86_64-linux-gnu
        multiarch=x86_64-linux-gnu
        CC="gcc"
        CXX="g++"
        AR="ar"
        RANLIB="ranlib"
        STRIP="strip"
        READELF="readelf"
        expected_machine="Advanced Micro Devices X86-64"
        ;;
    arm64)
        host=aarch64-linux-gnu
        multiarch=aarch64-linux-gnu
        CC=aarch64-linux-gnu-gcc
        CXX=aarch64-linux-gnu-g++
        AR=aarch64-linux-gnu-ar
        RANLIB=aarch64-linux-gnu-ranlib
        STRIP=aarch64-linux-gnu-strip
        READELF=aarch64-linux-gnu-readelf
        expected_machine=AArch64
        ;;
    *)
        printf 'Unsupported target architecture: %s\n' "$target_arch" >&2
        exit 2
        ;;
esac

export CC CXX AR RANLIB STRIP
export CFLAGS="-O2 -fPIC -fstack-protector-strong -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64"
export CPPFLAGS="$CFLAGS"
export LDFLAGS="-Wl,-O1 -Wl,-z,relro -Wl,-z,now"

php_headers=$php_root/usr/local/include/php
php_api=$(sed -n 's/^#define ZEND_MODULE_API_NO //p' "$php_headers/Zend/zend_modules.h")
test "$php_api" = "$PHP_API_EXPECTED"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$output" "$work/sdk"

sed "s|/usr/local|$php_root/usr/local|g" \
    "$php_root/usr/local/bin/phpize" > "$work/sdk/phpize"
sed "s|/usr/local|$php_root/usr/local|g" \
    "$php_root/usr/local/bin/php-config" > "$work/sdk/php-config"
chmod +x "$work/sdk/phpize" "$work/sdk/php-config"
phpize=$work/sdk/phpize
php_config=$work/sdk/php-config

clone_commit() {
    repository=$1
    commit=$2
    destination=$3
    git init -q "$destination"
    git -C "$destination" remote add origin "$repository"
    git -C "$destination" fetch -q --depth=1 origin "$commit"
    git -C "$destination" checkout -q --detach FETCH_HEAD
    test "$(git -C "$destination" rev-parse HEAD)" = "$commit"
}

build_extension() {
    source_directory=$1
    output_name=$2
    shift 2
    (
        cd "$source_directory"
        "$phpize"
        ./configure \
            --build=x86_64-linux-gnu \
            --host="$host" \
            --with-php-config="$php_config" \
            --with-libdir="lib/$multiarch" \
            "$@"
        make -j"$(nproc)"
        "$STRIP" --strip-unneeded "modules/$output_name.so"
        cp "modules/$output_name.so" "$output/$output_name.so"
    )
}

clone_commit https://github.com/phpredis/phpredis.git \
    "$PHPREDIS_COMMIT" "$work/phpredis"
build_extension "$work/phpredis" redis \
    --disable-redis-igbinary \
    --disable-redis-msgpack \
    --disable-redis-lzf \
    --disable-redis-zstd \
    --disable-redis-lz4

clone_commit https://github.com/openenergymonitor/Mosquitto-PHP.git \
    "$MOSQUITTO_PHP_COMMIT" "$work/mosquitto-php"
build_extension "$work/mosquitto-php" mosquitto --with-mosquitto=/usr

mkdir "$work/php-src"
tar -C "$work/php-src" --strip-components=1 -xf "$php_root/usr/src/php.tar.xz"
build_extension "$work/php-src/ext/mysqli" mysqli --with-mysqli=mysqlnd
build_extension "$work/php-src/ext/gettext" gettext --with-gettext

for extension in mysqli gettext redis mosquitto; do
    shared_object=$output/$extension.so
    test -s "$shared_object"
    "$READELF" -h "$shared_object" | grep -F "Machine:" | grep -F "$expected_machine"
    "$READELF" --dyn-syms --wide "$shared_object" | grep get_module >/dev/null
    if "$READELF" -d "$shared_object" | grep -Eq 'RUNPATH|RPATH'; then
        printf '%s contains an unexpected runtime search path\n' "$shared_object" >&2
        exit 1
    fi
done

"$READELF" -d "$output/mosquitto.so" | grep -F 'Shared library: [libmosquitto.so.1]'

{
    printf 'target_arch=%s\n' "$target_arch"
    printf 'target_triplet=%s\n' "$host"
    printf 'php_api=%s\n' "$php_api"
    printf 'phpredis_commit=%s\n' "$PHPREDIS_COMMIT"
    printf 'mosquitto_php_commit=%s\n' "$MOSQUITTO_PHP_COMMIT"
    sha256sum "$output"/*.so
} > "$output/build-metadata.txt"
