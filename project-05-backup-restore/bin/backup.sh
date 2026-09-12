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

LOCK_FILE="$STATE_DIR/backup.lock"
exec 200>"$LOCK_FILE"

if ! flock -n 200; then
    echo "Another backup process is already running."
    exit "$GENERAL_ERROR"
fi

for required_dir in "$SOURCE_DIR" "$BACKUP_DIR" "$STATE_DIR" "$LOG_DIR"; do
    [[ -d "$required_dir" ]] || {
        echo "ERROR: Required directory not found: $required_dir"
        exit "$CONFIG_ERROR"
    }
done

exec >> "$LOG_DIR/backup.log" 2>&1

log "Starting backup"
log "Source: $SOURCE_DIR"

FREE_MB=$(df -Pm "$BACKUP_DIR" | awk 'NR==2 {print $4}')

if [[ "$FREE_MB" -lt "$MIN_FREE_MB" ]]; then
    fail "$GENERAL_ERROR" "Insufficient disk space. Available: ${FREE_MB}MB, Required: ${MIN_FREE_MB}MB"
fi

NOW=$(date +%s)
TODAY=$(date +%Y-%m-%d)

LAST_FULL_FILE="$STATE_DIR/last_full_epoch"

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

    rm -f "$SNAPSHOT_FILE"

    ARCHIVE="$BACKUP_DIR/full-${TODAY}-$(date +%H%M%S).tar.gz"
    CHECKSUM="${ARCHIVE}.sha256"

    if ! tar \
        --listed-incremental="$SNAPSHOT_FILE" \
        -czf "$ARCHIVE" \
        -C "$(dirname "$SOURCE_DIR")" \
        "$(basename "$SOURCE_DIR")"; then

        rm -f "$ARCHIVE" "$CHECKSUM"
        fail "$BACKUP_ERROR" "Full backup creation failed"
    fi

    echo "$NOW" > "$LAST_FULL_FILE"

else

    log "Backup type: INCREMENTAL"

    ARCHIVE="$BACKUP_DIR/incremental-${TODAY}-$(date +%H%M%S).tar.gz"
    CHECKSUM="${ARCHIVE}.sha256"

    if ! tar \
        --listed-incremental="$SNAPSHOT_FILE" \
        -czf "$ARCHIVE" \
        -C "$(dirname "$SOURCE_DIR")" \
        "$(basename "$SOURCE_DIR")"; then

        rm -f "$ARCHIVE" "$CHECKSUM"
        fail "$BACKUP_ERROR" "Incremental backup creation failed"
    fi

fi

if ! sha256sum "$ARCHIVE" > "$CHECKSUM"; then
    rm -f "$ARCHIVE" "$CHECKSUM"
    fail "$CHECKSUM_ERROR" "Checksum creation failed"
fi

if ! sha256sum -c "$CHECKSUM" >/dev/null 2>&1; then
    fail "$CHECKSUM_ERROR" "Checksum verification failed"
fi

MANIFEST="${ARCHIVE}.manifest.json"
ARCHIVE_SHA256=$(awk '{print $1}' "$CHECKSUM")

if ! jq -n \
    --arg backup_type "$([[ "$DO_FULL" == true ]] && echo "full" || echo "incremental")" \
    --arg timestamp "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    --arg archive "$ARCHIVE" \
    --arg checksum "$ARCHIVE_SHA256" \
    --arg source "$SOURCE_DIR" \
    --arg rpo "${RPO_MINUTES} minutes" \
    --arg rto "${RTO_MINUTES} minutes" \
    '{
        backup_type: $backup_type,
        timestamp_utc: $timestamp,
        archive: $archive,
        sha256: $checksum,
        source: $source,
        rpo: $rpo,
        rto: $rto
    }' > "$MANIFEST"; then
    fail "$GENERAL_ERROR" "Manifest creation failed"
fi

log "Manifest created successfully: $MANIFEST"

log "Backup created successfully: $ARCHIVE"
log "Checksum verified successfully"
log "Backup completed"

exit "$SUCCESS"
