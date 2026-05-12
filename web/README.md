# how to build

```
docker build --build-arg="BUILD_FROM=php:8.2.27-apache" -t emoncms_legacy_docker .
```

## Database schema on first boot

`sql_ready.sh` waits for MySQL, then runs `emoncmsdbupdate.php` (`db_schema_setup`) when the `users` table is missing.

That oneshot must finish **before** Apache accepts HTTP traffic. It is registered in the **user** s6 bundle with `emoncms_pre → sql_ready → apache2`. (Previously `sql_ready` lived only under **user2**; with s6-overlay v3 the default target may not activate **user2**, so schema init never ran while Apache was already up.)
