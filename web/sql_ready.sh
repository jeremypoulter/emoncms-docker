#!/command/with-contenv sh

# Wait until MariaDB accepts TCP connections with our app credentials.
# mysqladmin ping can fail silently if mysqladmin is missing (stderr discarded) or misbehaves
# with remote hosts without --protocol=TCP; use mysql client like the checks below.
MYSQL_PORT="${MYSQL_PORT:-3306}"
# Client may default to TLS; DB container has no TLS. Use --skip-ssl (MariaDB client; --ssl-mode is not always available).
MYSQL_SSL="--skip-ssl"

echo "Waiting for MySQL at $MYSQL_HOST:$MYSQL_PORT (user $MYSQL_USER, db $MYSQL_DATABASE)..."
RETRIES=0
while ! mysql $MYSQL_SSL -h "$MYSQL_HOST" -P "$MYSQL_PORT" --protocol=TCP -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "USE \`$MYSQL_DATABASE\`" 2>/dev/null; do
    RETRIES=$((RETRIES + 1))
    if [ "$RETRIES" -ge 30 ]; then
        echo "ERROR: Could not authenticate as $MYSQL_USER after 30 attempts."
        echo "If this is a fresh install, ensure MYSQL_USER, MYSQL_PASSWORD and"
        echo "MYSQL_DATABASE are set in the db service environment."
        echo "If reusing an old volume, try: docker compose down -v"
        echo "Debug (this attempt only):"
        echo "MYSQL_HOST=$MYSQL_HOST MYSQL_PORT=$MYSQL_PORT MYSQL_USER=$MYSQL_USER MYSQL_DATABASE=$MYSQL_DATABASE"
        mysql $MYSQL_SSL -h "$MYSQL_HOST" -P "$MYSQL_PORT" --protocol=TCP -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "USE \`$MYSQL_DATABASE\`" 2>&1 || true
        exit 1
    fi
    sleep 1
done
echo "MySQL server is up and credentials OK"

TABLE_EXISTS=$(mysql $MYSQL_SSL -h "$MYSQL_HOST" -P "$MYSQL_PORT" --protocol=TCP -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
    -sse "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$MYSQL_DATABASE' AND table_name='users'" 2>/dev/null)

if [ "$TABLE_EXISTS" = "0" ] || [ -z "$TABLE_EXISTS" ]; then
    echo "New install detected - initialising emoncms database schema"
    php "$OEM_DIR/emoncmsdbupdate.php"
else
    echo "Existing emoncms database found"
fi

echo "sql_ready complete, starting workers"
