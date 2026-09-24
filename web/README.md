# how to build

The PHP extensions (mysqli, gettext, phpredis and Mosquitto-PHP) are compiled
outside the image and copied in as prebuilt `.so` files. The arm64 build uses a
cross toolchain rather than emulation. Build them for each target architecture
before building the image, using the same `BUILD_FROM` image:

```
BUILD_FROM=php:8.4-apache-trixie
ci/build-extension-artifacts.sh "$BUILD_FROM" amd64 web/extensions/linux-amd64
ci/build-extension-artifacts.sh "$BUILD_FROM" arm64 web/extensions/linux-arm64
```

Run these from the repository root. Then build the image:

```
docker build --build-arg="BUILD_FROM=$BUILD_FROM" -t emoncms_legacy_docker web
```

For a multi-platform image:

```
docker buildx build --platform linux/amd64,linux/arm64 \
    --build-arg="BUILD_FROM=$BUILD_FROM" -t emoncms_legacy_docker web
```

## Database schema on first boot

`sql_ready.sh` waits for MySQL, then runs `emoncmsdbupdate.php` (`db_schema_setup`) when the `users` table is missing.

That oneshot must finish **before** Apache accepts HTTP traffic. It is registered in the **user** s6 bundle with `emoncms_pre → sql_ready → apache2`. (Previously `sql_ready` lived only under **user2**; with s6-overlay v3 the default target may not activate **user2**, so schema init never ran while Apache was already up.)
