#!/bin/bash

set -u

APP_DIR="/opt/self-healing-app"
STATUS_FILE="$APP_DIR/status"
CRASH_FILE="$APP_DIR/crash"

mkdir -p "$APP_DIR"

echo "Self-healing demo application started. PID=$$"

trap 'echo "$(date "+%Y-%m-%d %H:%M:%S") Application stopped. PID=$$" >> "$STATUS_FILE"' EXIT

while true; do
    echo "$(date "+%Y-%m-%d %H:%M:%S") HEALTHY PID=$$" > "$STATUS_FILE"

    if [[ -f "$CRASH_FILE" ]]; then
        rm -f "$CRASH_FILE"
        echo "$(date "+%Y-%m-%d %H:%M:%S") CONTROLLED CRASH triggered. PID=$$"
        exit 1
    fi

    sleep 5
done
