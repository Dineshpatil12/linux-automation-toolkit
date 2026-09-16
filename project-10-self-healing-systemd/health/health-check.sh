#!/bin/bash

set -u

STATUS_FILE="/opt/self-healing-app/status"

if [[ ! -f "$STATUS_FILE" ]]; then
    echo "UNHEALTHY: status file not found"
    exit 1
fi

if ! pgrep -f "self-healing-app.sh" >/dev/null; then
    echo "UNHEALTHY: application process not running"
    exit 1
fi

LAST_STATUS=$(cat "$STATUS_FILE")

if [[ "$LAST_STATUS" == *"HEALTHY"* ]]; then
    echo "HEALTHY: $LAST_STATUS"
    exit 0
fi

echo "UNHEALTHY: unexpected status"
exit 1
