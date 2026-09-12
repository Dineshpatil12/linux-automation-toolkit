#!/usr/bin/env bash

set -u

SCRIPT_NAME="$(basename "$0")"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$PROJECT_DIR/conf/backup.conf"

SUCCESS=0
GENERAL_ERROR=1
CONFIG_ERROR=2
BACKUP_ERROR=3
CHECKSUM_ERROR=4

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$SCRIPT_NAME] $1"
}

fail() {
    log "ERROR: $2"
    exit "$1"
}

if [[ ! -f "$CONFIG_FILE" ]]; then
    fail "$CONFIG_ERROR" "Configuration file not found: $CONFIG_FILE"
fi

source "$CONFIG_FILE"

for required_dir in "$SOURCE_DIR" "$BACKUP_DIR" "$STATE_DIR" "$LOG_DIR"; do
    [[ -d "$required_dir" ]] || fail "$CONFIG_ERROR" "Required directory not found: $required_dir"
done

exec >> "$LOG_DIR/backup.log" 2>&1

log "Starting backup"
log "Source: $SOURCE_DIR"

ARCHIVE="$BACKUP_DIR/full-$(date +%Y%m%d-%H%M%S).tar.gz"
CHECKSUM="${ARCHIVE}.sha256"

if ! tar -czf "$ARCHIVE" \
    -C "$(dirname "$SOURCE_DIR")" \
    "$(basename "$SOURCE_DIR")"; then
    fail "$BACKUP_ERROR" "Backup creation failed"
fi

if ! sha256sum "$ARCHIVE" > "$CHECKSUM"; then
    fail "$CHECKSUM_ERROR" "Checksum creation failed"
fi

if ! sha256sum -c "$CHECKSUM" >/dev/null 2>&1; then
    fail "$CHECKSUM_ERROR" "Checksum verification failed"
fi

log "Backup created successfully: $ARCHIVE"
log "Checksum verified successfully"
log "Backup completed"

exit "$SUCCESS"
