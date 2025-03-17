#!/bin/bash

# Define array of logrotate configs (can be multiple .d files)
LOGROTATE_CONFIGS=(
    "/etc/logrotate.d/logrotate-logs"
)

# Default to 3600 seconds (1 hour) if LOGROTATE_INTERVAL is not provided externally
SLEEP_INTERVAL="${LOGROTATE_INTERVAL:-3600}"

while true; do
    for config in "${LOGROTATE_CONFIGS[@]}"; do
        if [ -f "$config" ]; then
            echo "[logrotate] Rotating logs using: $config"
            /usr/sbin/logrotate -s /tmp/logrotate.status -f "$config"
        else
            echo "[logrotate] Config not found: $config"
        fi
    done
    echo "[logrotate] Sleeping for ${SLEEP_INTERVAL} seconds"
    sleep "$SLEEP_INTERVAL"
done
