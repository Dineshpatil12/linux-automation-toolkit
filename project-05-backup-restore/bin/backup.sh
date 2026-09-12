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
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit "$CONFIG_ERROR"
fi

source "$CONFIG_FILE"

for required_dir in "$SOURCE_DIR" "$BACKUP_DIR" "$STATE_DIR" "$LOG_DIR"; do
    [[ -d "$required_dir" ]] || {
        echo "ERROR: Required directory not found: $required_dir"
        exit "$CONFIG_ERROR"
    }
done

LOCK_FILE="$STATE_DIR/backup.lock"
exec 200>"$LOCK_FILE"

if ! flock -n 200; then
    echo "Another backup process is already running."
    exit "$GENERAL_ERROR"
fi

exec >> "$LOG_DIR/backup.log" 2>&1

log "Starting backup"
log "Source: $SOURCE_DIR"

FREE_MB=$(df -Pm "$BACKUP_DIR" | awk 'NR==2 {print $4}')

if [[ "$FREE_MB" -lt "$MIN_FREE_MB" ]]; then
    fail "$GENERAL_ERROR" "Insufficient disk space. Available: ${FREE_MB}MB, Required: ${MIN_FREE_MB}MB"
fi

NOW=$(date +%s)
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H%M%S)

DO_FULL=false

if [[ ! -f "$SNAPSHOT_FILE" ]]; then
    DO_FULL=true
elif [[ ! -f "$LAST_FULL_FILE" ]]; then
    DO_FULL=true
else
    LAST_FULL=$(cat "$LAST_FULL_FILE")
    AGE_DAYS=$(( (NOW - LAST_FULL) / 86400 ))

    if [[ "$AGE_DAYS" -ge "$FULL_BACKUP_DAYS" ]]; then
        DO_FULL=true
    fi
fi

if [[ "$DO_FULL" == true ]]; then

    log "Backup type: FULL"

    CHAIN_ID="$(date -u '+%Y%m%dT%H%M%SZ')"
    echo "$CHAIN_ID" > "$CHAIN_STATE_FILE"

    rm -f "$SNAPSHOT_FILE"

    ARCHIVE="$BACKUP_DIR/full-${DATE}-${TIME}.tar.gz"

    if ! tar \
        --listed-incremental="$SNAPSHOT_FILE" \
        -czf "$ARCHIVE" \
        -C "$(dirname "$SOURCE_DIR")" \
        "$(basename "$SOURCE_DIR")"; then

        rm -f "$ARCHIVE"
        fail "$BACKUP_ERROR" "Full backup creation failed"
    fi

    echo "$NOW" > "$LAST_FULL_FILE"

else

    log "Backup type: INCREMENTAL"

    if [[ ! -f "$CHAIN_STATE_FILE" ]]; then
        fail "$BACKUP_ERROR" "Chain ID is missing"
    fi

    CHAIN_ID=$(cat "$CHAIN_STATE_FILE")

    ARCHIVE="$BACKUP_DIR/incremental-${DATE}-${TIME}.tar.gz"

    if ! tar \
        --listed-incremental="$SNAPSHOT_FILE" \
        -czf "$ARCHIVE" \
        -C "$(dirname "$SOURCE_DIR")" \
        "$(basename "$SOURCE_DIR")"; then

        rm -f "$ARCHIVE"
        fail "$BACKUP_ERROR" "Incremental backup creation failed"
    fi

fi

CHECKSUM="${ARCHIVE}.sha256"

if ! sha256sum "$ARCHIVE" > "$CHECKSUM"; then
    rm -f "$ARCHIVE" "$CHECKSUM"
    fail "$CHECKSUM_ERROR" "Checksum creation failed"
fi

if ! sha256sum -c "$CHECKSUM" >/dev/null 2>&1; then
    fail "$CHECKSUM_ERROR" "Checksum verification failed"
fi

ARCHIVE_SHA256=$(awk '{print $1}' "$CHECKSUM")

MANIFEST="${ARCHIVE}.manifest.json"

if ! jq -n \
    --arg backup_type "$([[ "$DO_FULL" == true ]] && echo "full" || echo "incremental")" \
    --arg timestamp "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    --arg archive "$ARCHIVE" \
    --arg checksum "$ARCHIVE_SHA256" \
    --arg source "$SOURCE_DIR" \
    --arg rpo "${RPO_MINUTES} minutes" \
    --arg rto "${RTO_MINUTES} minutes" \
    --arg chain_id "$CHAIN_ID" \
    '{
        backup_type: $backup_type,
        timestamp_utc: $timestamp,
        archive: $archive,
        sha256: $checksum,
        source: $source,
        chain_id: $chain_id,
        rpo: $rpo,
        rto: $rto
    }' > "$MANIFEST"; then

    fail "$GENERAL_ERROR" "Manifest creation failed"
fi

log "Backup created successfully: $ARCHIVE"
log "Checksum verified successfully"
log "Manifest created successfully: $MANIFEST"
log "Chain ID: $CHAIN_ID"
log "Backup completed"

exit "$SUCCESS"
