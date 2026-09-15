#!/usr/bin/env bash

# Project 07 - Application Watchdog

# Do not use "set -e".
# Expected health/recovery failures must be handled explicitly.
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$PROJECT_DIR/conf/watchdog.conf"

# Meaningful exit codes
EXIT_HEALTHY=0
EXIT_RECOVERED=0
EXIT_RECOVERY_FAILED=1
EXIT_CONFIG_ERROR=2
EXIT_ESCALATED=3

log() {
    local level="$1"
    shift

    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    printf '%s [%s] %s\n' "$timestamp" "$level" "$*" | tee -a "$LOG_FILE"
}

fail_config() {
    log "ERROR" "$*"
    exit "$EXIT_CONFIG_ERROR"
}

if [[ ! -f "$CONFIG_FILE" ]]; then
    fail_config "Configuration file not found: $CONFIG_FILE"
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

required_vars=(
    APP_NAME
    APP_DIR
    APP_SCRIPT
    HEALTH_URL
    HEALTH_TIMEOUT
    LOG_DIR
    STATE_DIR
    LOG_FILE
    MAX_RETRIES
    INITIAL_BACKOFF
    MAX_BACKOFF
    MAX_FAILURES
    FAILURE_WINDOW
    COOLDOWN_PERIOD
)

for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        fail_config "Required configuration variable is missing: $var"
    fi
done

mkdir -p "$LOG_DIR" "$STATE_DIR"

collect_evidence() {
    local timestamp
    local evidence_file

    timestamp="$(date '+%Y%m%d_%H%M%S')"
    evidence_file="$STATE_DIR/evidence_${APP_NAME}_${timestamp}.log"

    log "INFO" "Collecting failure evidence: $evidence_file"

    {
        echo "===== APPLICATION WATCHDOG EVIDENCE ====="
        echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Application: $APP_NAME"
        echo "Health URL: $HEALTH_URL"
        echo

        echo "===== PROCESS STATUS ====="
        ps -ef | grep "[p]ython3 $APP_SCRIPT" || true
        echo

        echo "===== PORT STATUS ====="
        ss -lntp | grep ':8080 ' || true
        echo

        echo "===== RECENT APPLICATION LOG ====="
        if [[ -f "$APP_DIR/app.log" ]]; then
            tail -20 "$APP_DIR/app.log"
        else
            echo "Application log not found: $APP_DIR/app.log"
        fi
        echo

        echo "===== SYSTEM LOAD ====="
        uptime
        echo

        echo "===== MEMORY ====="
        free -h
        echo

        echo "===== RECENT SYSTEM LOG ====="
        if command -v journalctl >/dev/null 2>&1; then
            journalctl --no-pager -n 20 2>/dev/null || true
        else
            echo "journalctl is not available"
        fi

    } > "$evidence_file" 2>&1

    chmod 600 "$evidence_file"

    log "INFO" "Failure evidence collected successfully"
}

health_check() {
    local http_code

    http_code="$(curl \
        --silent \
        --output /dev/null \
        --write-out '%{http_code}' \
        --max-time "$HEALTH_TIMEOUT" \
        "$HEALTH_URL")"

    if [[ "$http_code" == "200" ]]; then
        return 0
    fi

    log "WARN" "Health check failed: HTTP status=$http_code"
    return 1
}

log "INFO" "Application watchdog started for $APP_NAME"

if health_check; then
    log "INFO" "Application is healthy"
    exit "$EXIT_HEALTHY"
fi

log "WARN" "Application is unhealthy"

# Evidence must always be collected before remediation.
collect_evidence

exit "$EXIT_RECOVERY_FAILED"
