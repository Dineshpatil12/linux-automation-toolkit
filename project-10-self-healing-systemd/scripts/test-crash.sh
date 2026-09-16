#!/bin/bash

set -u

CRASH_FILE="/opt/self-healing-app/crash"

echo "Triggering controlled application failure..."
touch "$CRASH_FILE"

echo "Crash signal created."
echo "systemd should detect the failure and restart the service."
