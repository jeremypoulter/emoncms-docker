#!/command/with-contenv sh

echo "Waiting for MySQL server at $MYSQL_HOST to accept connections..."
while ! mysqladmin ping -h "$MYSQL_HOST" --silent 2>/dev/null; do
    sleep 1
done
echo "MySQL server is up"

echo "Checking credentials for user $MYSQL_USER on database $MYSQL_DATABASE..."
RETRIES=0
while ! mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "USE $MYSQL_DATABASE" 2>/dev/null; do
    RETRIES=$((RETRIES + 1))
    if [ "$RETRIES" -ge 30 ]; then
        echo "ERROR: Could not authenticate as $MYSQL_USER after 30 attempts."
        echo "If this is a fresh install, ensure MYSQL_USER, MYSQL_PASSWORD and"
        echo "MYSQL_DATABASE are set in the db service environment."
        echo "If reusing an old volume, try: docker compose down -v"
        exit 1
    fi
    sleep 1
done
echo "MySQL credentials verified"

TABLE_EXISTS=$(mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
    -sse "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$MYSQL_DATABASE' AND table_name='users'" 2>/dev/null)

if [ "$TABLE_EXISTS" = "0" ] || [ -z "$TABLE_EXISTS" ]; then
    echo "New install detected - initialising emoncms database schema"
    php "$OEM_DIR/emoncmsdbupdate.php"
else
    echo "Existing emoncms database found"
fi

echo "sql_ready complete, starting workers"
