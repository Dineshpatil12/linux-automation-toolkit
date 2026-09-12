#!/usr/bin/env bash

set -u

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$PROJECT_DIR/conf/backup.conf"

echo "$(date '+%Y-%m-%d %H:%M:%S') [retention.sh] Starting retention check"

mapfile -t CHAINS < <(
    for manifest in "$BACKUP_DIR"/full-*.tar.gz.manifest.json; do
        [[ -f "$manifest" ]] || continue
        jq -r '.chain_id' "$manifest"
    done | sort -u
)

if [[ "${#CHAINS[@]}" -le "$RETENTION_CHAINS" ]]; then
    echo "Retention: ${#CHAINS[@]} chain(s) found; keeping all."
    exit 0
fi

for ((i=0; i<${#CHAINS[@]}-RETENTION_CHAINS; i++)); do
    OLD_CHAIN="${CHAINS[$i]}"

    echo "Old chain candidate: $OLD_CHAIN"

    for manifest in "$BACKUP_DIR"/*.manifest.json; do
        [[ -f "$manifest" ]] || continue

        chain=$(jq -r '.chain_id' "$manifest")

        if [[ "$chain" == "$OLD_CHAIN" ]]; then
            archive=$(jq -r '.archive' "$manifest")

            echo "Removing: $archive"

            rm -f "$archive"
            rm -f "$manifest"
            rm -f "${archive}.sha256"
        fi
    done
done

echo "$(date '+%Y-%m-%d %H:%M:%S') [retention.sh] Retention completed"
