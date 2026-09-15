#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$PROJECT_DIR/conf/troubleshooting.conf"

ERRORS=0
WARNINGS=()

usage() {
    cat <<'EOF'
Usage: troubleshoot.sh all

Linux Troubleshooting Toolkit

Commands:
  all       Run all enabled diagnostics
  -h, --help  Show this help message
EOF
}

case "${1:-}" in
    all)
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    *)
        usage >&2
        exit 1
        ;;
esac

add_warning() {
    WARNINGS+=("$1")
    ERRORS=$((ERRORS + 1))
}

if [[ ! -r "$CONFIG_FILE" ]]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE" >&2
    exit 1
fi

# shellcheck disable=SC1090
# shellcheck disable=SC2153
source "$CONFIG_FILE"

mkdir -p "$REPORT_DIR" || {
    echo "ERROR: Cannot access report directory: $REPORT_DIR" >&2
    exit 1
}

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
REPORT_FILE="$REPORT_DIR/${REPORT_PREFIX}_$(date '+%Y%m%d_%H%M%S').txt"

section() {
    printf '\n============================================================\n'
    printf '%s\n' "$1"
    printf '============================================================\n'
}

write_command() {
    local description="$1"
    shift

    printf '\n--- %s ---\n' "$description"

    if command -v "$1" >/dev/null 2>&1; then
        if ! "$@"; then
            printf '[WARNING] Command failed: %s\n' "$1"
            add_warning "Command failed: $1"
        fi
    else
        printf '[WARNING] Command unavailable: %s\n' "$1"
        add_warning "Command unavailable: $1"
    fi
}

{
    printf 'Linux Troubleshooting Toolkit\n'
    printf 'Generated: %s\n' "$TIMESTAMP"
    printf 'Hostname: %s\n' "$(hostname)"
    printf 'Report: %s\n' "$REPORT_FILE"

    section "CPU"

    if [[ -r /proc/stat ]]; then
        printf 'CPU statistics from /proc/stat:\n'
        head -n 5 /proc/stat
    else
        printf '[WARNING] /proc/stat unavailable\n'
        WARNINGS+=("CPU: /proc/stat unavailable")
        ERRORS=$((ERRORS + 1))
    fi

    if [[ -r /proc/cpuinfo ]]; then
        printf '\nCPU information:\n'
        grep -E '^(processor|model name|cpu MHz)' /proc/cpuinfo | head -n 15
    else
        printf '[WARNING] /proc/cpuinfo unavailable\n'
        WARNINGS+=("CPU: /proc/cpuinfo unavailable")
        ERRORS=$((ERRORS + 1))
    fi

    section "Load Average"

    if [[ -r /proc/loadavg ]]; then
        printf 'Load average:\n'
        cat /proc/loadavg
    else
        printf '[WARNING] /proc/loadavg unavailable\n'
        WARNINGS+=("Load: /proc/loadavg unavailable")
        ERRORS=$((ERRORS + 1))
    fi

    section "Memory and Swap"

    if command -v free >/dev/null 2>&1; then
        free -h
    else
        printf '[WARNING] free command unavailable\n'
        WARNINGS+=("Memory: free command unavailable")
        ERRORS=$((ERRORS + 1))
    fi

    if [[ -r /proc/meminfo ]]; then
        printf '\nSelected memory/swap counters:\n'
        grep -E '^(MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree):' /proc/meminfo
    else
        printf '[WARNING] /proc/meminfo unavailable\n'
        WARNINGS+=("Memory: /proc/meminfo unavailable")
        ERRORS=$((ERRORS + 1))
    fi

    section "Uptime"

    if command -v uptime >/dev/null 2>&1; then
        uptime
    elif [[ -r /proc/uptime ]]; then
        cat /proc/uptime
    else
        printf '[WARNING] Uptime information unavailable\n'
        WARNINGS+=("System: uptime information unavailable")
        ERRORS=$((ERRORS + 1))
    fi

    section "Disk and Inodes"

    printf 'Filesystem usage:\n'
    if command -v df >/dev/null 2>&1; then
        df -hT

        while read -r percent mountpoint; do
            usage="${percent%%%}"
            if [[ "$usage" =~ ^[0-9]+$ ]] && (( usage >= DISK_WARN_PERCENT )); then
                add_warning "Disk: ${mountpoint} utilization is ${usage}% (threshold ${DISK_WARN_PERCENT}%)"
            fi
        done < <(df -P | awk 'NR > 1 {print $5, $6}')
    else
        printf '[WARNING] df command unavailable\n'
        add_warning "Disk: df command unavailable"
    fi

    printf '\nInode usage:\n'
    if command -v df >/dev/null 2>&1; then
        df -ih
    else
        printf '[WARNING] df command unavailable for inode check\n'
        add_warning "Inodes: df command unavailable"
    fi

    printf '\nLargest directories under /opt/devopsshack:\n'
    if command -v du >/dev/null 2>&1; then
        du -xhd1 /opt/devopsshack 2>/dev/null | sort -h | tail -n "$TOP_DISK_ITEMS"
    else
        printf '[WARNING] du command unavailable\n'
        add_warning "Disk: du command unavailable"
    fi

    section "Disk I/O"

    if command -v iostat >/dev/null 2>&1; then
        printf 'I/O statistics from iostat:\n'
        if ! iostat -xz 1 2; then
            printf '[WARNING] iostat collection failed\n'
            add_warning "I/O: iostat collection failed"
        fi
    elif command -v vmstat >/dev/null 2>&1; then
        printf 'iostat unavailable; using vmstat as I/O fallback:\n'
        if ! vmstat 1 2; then
            printf '[WARNING] vmstat I/O collection failed\n'
            add_warning "I/O: vmstat collection failed"
        fi
    else
        printf '[WARNING] Neither iostat nor vmstat is available\n'
        add_warning "I/O: iostat and vmstat unavailable"
    fi

    section "Processes"

    if command -v ps >/dev/null 2>&1; then
        printf 'Top processes by CPU:\n'
        ps -eo pid,ppid,user,stat,%cpu,%mem,etime,comm --sort=-%cpu | head -n "$((TOP_PROCESSES + 1))"

        printf '\nTop processes by memory:\n'
        ps -eo pid,ppid,user,stat,%cpu,%mem,etime,comm --sort=-%mem | head -n "$((TOP_PROCESSES + 1))"

        printf '\nProcess state summary:\n'
        ps -eo stat= | awk '
        {
            state=substr($1,1,1)
            count[state]++
        }
        END {
            for (state in count)
                printf "%s: %d\n", state, count[state]
        }' | sort

        printf '\nTotal process count:\n'
        ps -e --no-headers | wc -l
    else
        printf '[WARNING] ps command unavailable\n'
        add_warning "Processes: ps command unavailable"
    fi

    section "Network"

    printf 'Network interfaces and addresses:\n'
    if command -v ip >/dev/null 2>&1; then
        ip -br addr
    else
        printf '[WARNING] ip command unavailable\n'
        add_warning "Network: ip command unavailable"
    fi

    printf '\nRouting table:\n'
    if command -v ip >/dev/null 2>&1; then
        ip route
    else
        printf '[WARNING] ip command unavailable for routing check\n'
        add_warning "Network: ip routing check unavailable"
    fi

    printf '\nListening TCP/UDP ports:\n'
    if command -v ss >/dev/null 2>&1; then
        ss -lntup
    else
        printf '[WARNING] ss command unavailable\n'
        add_warning "Network: ss command unavailable"
    fi

    printf '\nSocket summary:\n'
    if command -v ss >/dev/null 2>&1; then
        ss -s
    else
        printf '[WARNING] ss command unavailable for socket summary\n'
        add_warning "Network: socket summary unavailable"
    fi

    section "Logs"

    printf 'Recent journal errors/warnings:\n'
    if command -v journalctl >/dev/null 2>&1; then
        # shellcheck disable=SC2153
        journalctl -p warning..alert -n "$LOG_LINES" --no-pager 2>&1 || {
            printf '[WARNING] journalctl warning/error collection failed\n'
            add_warning "Logs: journalctl collection failed"
        }
    else
        printf '[WARNING] journalctl command unavailable\n'
        add_warning "Logs: journalctl unavailable"
    fi

    printf '\nRecent kernel messages:\n'
    if command -v dmesg >/dev/null 2>&1; then
        dmesg --level=err,warn -T 2>&1 | tail -n "$LOG_LINES" || {
            printf '[WARNING] dmesg collection failed or access was restricted\n'
            add_warning "Logs: dmesg access restricted or collection failed"
        }
    else
        printf '[WARNING] dmesg command unavailable\n'
        add_warning "Logs: dmesg unavailable"
    fi

    printf '\nConfigured application logs:\n'

    if [[ -n "${LOG_FILES:-}" ]]; then
        for logfile in $LOG_FILES; do
            printf '\n--- %s ---\n' "$logfile"

            if [[ -r "$logfile" ]]; then
                tail -n "$LOG_LINES" "$logfile"
            else
                printf '[WARNING] Log file unavailable or unreadable: %s\n' "$logfile"
                WARNINGS+=("Logs: unavailable or unreadable file: $logfile")
                ERRORS=$((ERRORS + 1))
            fi
        done
    else
        printf 'No application log files configured.\n'
    fi

    section "System and Service State"

    if command -v systemctl >/dev/null 2>&1; then
        printf 'Failed systemd units:\n'
        systemctl --failed --no-pager 2>&1 || {
            printf '[WARNING] systemctl --failed failed\n'
            add_warning "System: systemctl failed-unit check failed"
        }

        printf '\nSystem state:\n'
        systemctl is-system-running 2>&1 || true
    else
        printf '[WARNING] systemctl command unavailable\n'
        add_warning "System: systemctl unavailable"
    fi

    printf '\nMount information:\n'
    if command -v findmnt >/dev/null 2>&1; then
        findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS
    else
        printf '[WARNING] findmnt command unavailable\n'
        add_warning "System: findmnt unavailable"
    fi

    section "Warnings / Errors"

    if (( ${#WARNINGS[@]} == 0 )); then
        printf '✓ No diagnostic warnings or errors encountered.\n'
    else
        for warning in "${WARNINGS[@]}"; do
            printf '⚠ %s\n' "$warning"
        done
    fi

    section "Collection Summary"

    printf 'Warnings/errors during collection: %s\n' "$ERRORS"

} > "$REPORT_FILE" 2>&1

if [[ -s "$REPORT_FILE" ]]; then
    printf 'Report created successfully: %s\n' "$REPORT_FILE"
else
    printf 'ERROR: Report was not created correctly: %s\n' "$REPORT_FILE" >&2
    exit 1
fi
