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

start_application() {
    log "INFO" "Starting application: $APP_NAME"

    if [[ ! -f "$APP_SCRIPT" ]]; then
        log "ERROR" "Application script not found: $APP_SCRIPT"
        return 1
    fi

    if [[ -f "$APP_DIR/app.log" ]]; then
        touch "$APP_DIR/app.log"
    fi

    nohup python3 "$APP_SCRIPT" >> "$APP_DIR/app.log" 2>&1 &
    local new_pid=$!

    echo "$new_pid" > "$STATE_DIR/${APP_NAME}.pid"

    log "INFO" "Application start command issued: PID=$new_pid"

    sleep 2

    if kill -0 "$new_pid" 2>/dev/null; then
        log "INFO" "Application process is running: PID=$new_pid"
        return 0
    fi

    log "ERROR" "Application process exited after start attempt"
    return 1
}

recover_application() {
    local attempt=1
    local backoff="$INITIAL_BACKOFF"

    while (( attempt <= MAX_RETRIES )); do
        log "INFO" "Recovery attempt $attempt of $MAX_RETRIES"

        if start_application; then
            log "INFO" "Application process started successfully"

            if health_check; then
                log "INFO" "Recovery verification successful: application is healthy"
                return 0
            fi

            log "WARN" "Recovery attempt $attempt failed health verification"
        else
            log "WARN" "Recovery attempt $attempt failed to start application"
        fi

        if (( attempt < MAX_RETRIES )); then
            log "INFO" "Waiting ${backoff}s before next recovery attempt"
            sleep "$backoff"

            backoff=$(( backoff * 2 ))

            if (( backoff > MAX_BACKOFF )); then
                backoff="$MAX_BACKOFF"
            fi
        fi

        (( attempt++ ))
    done

    log "ERROR" "All recovery attempts failed"
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

log "INFO" "Beginning controlled recovery"

if recover_application; then
    log "INFO" "Application recovered successfully"
    exit "$EXIT_RECOVERED"
fi

log "ERROR" "Application recovery failed after all attempts"

exit "$EXIT_RECOVERY_FAILED"
