#!/bin/bash

set -u

SERVICE="self-healing-app.service"
HEALTH_CHECK="/home/ec2-user/linux-automation-toolkit/project-10-self-healing-systemd/health/health-check.sh"

echo "Checking systemd service recovery..."

if ! systemctl is-active --quiet "$SERVICE"; then
    echo "FAIL: $SERVICE is not active"
    systemctl status "$SERVICE" --no-pager
    exit 1
fi

if [[ ! -x "$HEALTH_CHECK" ]]; then
    echo "FAIL: health-check.sh not found at $HEALTH_CHECK"
    exit 1
fi

if ! "$HEALTH_CHECK"; then
    echo "FAIL: application health check failed"
    exit 1
fi

echo "PASS: service is active and application is healthy."
