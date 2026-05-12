#!/command/with-contenv sh

if [ -n "$TZ" ] && [ -f "/usr/share/zoneinfo/$TZ" ]; then
    cp "/usr/share/zoneinfo/$TZ" /etc/localtime
    echo "$TZ" > /etc/timezone
fi

if ! [ -d "$EMONCMS_DATADIR/phpfina" ]; then
    echo "Creating timeseries directories"
    mkdir -p "$EMONCMS_DATADIR/phpfina"
    mkdir -p "$EMONCMS_DATADIR/phptimeseries"
    mkdir -p "$EMONCMS_DATADIR/backup"
    mkdir -p "$EMONCMS_DATADIR/backup/uploads"
else
    echo "Using existing timeseries directories"
fi

chown -R "$DAEMON" "$EMONCMS_DATADIR"

echo "emoncms_pre init complete"
