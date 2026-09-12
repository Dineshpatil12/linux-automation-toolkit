#!/usr/bin/env bash

set -u

SCRIPT_NAME="$(basename "$0")"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$PROJECT_DIR/conf/backup.conf"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Configuration file not found"
    exit 2
fi

source "$CONFIG_FILE"

exec 200>"$STATE_DIR/restore.lock"

if ! flock -n 200; then
    echo "Another restore process is already running."
    exit 1
fi

mkdir -p "$RESTORE_DIR"

echo "$(date '+%Y-%m-%d %H:%M:%S') [$SCRIPT_NAME] Starting restore"

LATEST_FULL=$(find "$BACKUP_DIR" -maxdepth 1 -type f \
    -regextype posix-extended \
    -regex '.*/full-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}\.tar\.gz' \
    -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)

if [[ -z "$LATEST_FULL" ]]; then
    echo "ERROR: No full backup found"
    exit 3
fi

CHAIN_ID=$(jq -r '.chain_id' "${LATEST_FULL}.manifest.json")

if [[ -z "$CHAIN_ID" || "$CHAIN_ID" == "null" ]]; then
    echo "ERROR: Chain ID missing from full manifest"
    exit 3
fi

echo "Restoring chain: $CHAIN_ID"
echo "Full backup: $LATEST_FULL"

if ! sha256sum -c "${LATEST_FULL}.sha256"; then
    echo "ERROR: Full backup checksum failed"
    exit 4
fi

rm -rf "$RESTORE_DIR"/*
mkdir -p "$RESTORE_DIR"

tar --listed-incremental=/dev/null \
    -xzf "$LATEST_FULL" \
    -C "$RESTORE_DIR"

mapfile -t INCREMENTALS < <(
    for manifest in "$BACKUP_DIR"/incremental-*.tar.gz.manifest.json; do
        [[ -f "$manifest" ]] || continue

        manifest_chain=$(jq -r '.chain_id' "$manifest")

        if [[ "$manifest_chain" == "$CHAIN_ID" ]]; then
            jq -r '.archive' "$manifest"
        fi
    done | sort
)

for incremental in "${INCREMENTALS[@]}"; do
    [[ -f "$incremental" ]] || continue

    echo "Applying incremental: $incremental"

    if ! sha256sum -c "${incremental}.sha256"; then
        echo "ERROR: Incremental checksum failed"
        exit 4
    fi

    tar --listed-incremental=/dev/null \
        -xzf "$incremental" \
        -C "$RESTORE_DIR"
done

echo "$(date '+%Y-%m-%d %H:%M:%S') [$SCRIPT_NAME] Restore completed successfully"
echo "Restore location: $RESTORE_DIR"

exit 0
