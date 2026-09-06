#!/bin/bash

# ==========================================================
# Project 2 - Disk Usage Alerting Script
# ==========================================================

CONFIG_FILE="/opt/devopsshack/conf/disk-alert.conf"

# ----------------------------------------------------------
# Load configuration
# ----------------------------------------------------------
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

mkdir -p "$STATE_DIR"
touch "$LOG_FILE"

# ----------------------------------------------------------
# Logging function
# ----------------------------------------------------------
log_message() {
    local level="$1"
    local message="$2"

    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" | tee -a "$LOG_FILE"
}

# ----------------------------------------------------------
# Convert mount point into safe filename
# /      -> root
# /var   -> var
# ----------------------------------------------------------
get_mount_key() {
    local mount_point="$1"

    if [[ "$mount_point" == "/" ]]; then
        echo "root"
    else
        echo "$mount_point" |
            sed 's#^/##; s#[ /]#_#g'
    fi
}

# ----------------------------------------------------------
# Collect evidence when disk is high
# ----------------------------------------------------------
collect_evidence() {
    local mount_point="$1"

    echo
    echo "----- Largest directories -----"

    timeout 20 du -x -h --max-depth=1 "$mount_point" 2>/dev/null |
        sort -hr |
        head -n "$TOP_N"

    echo
    echo "----- Largest files -----"

    timeout 20 find "$mount_point" -xdev -type f -printf '%s %p\n' 2>/dev/null |
        sort -nr |
        head -n "$TOP_N" |
        awk '{
            size=$1;
            $1="";
            printf "%.2f MB%s\n", size/1024/1024, $0
        }'

    echo
    echo "----- Deleted but open files -----"

    if command -v lsof >/dev/null 2>&1; then
        sudo -n lsof +L1 2>/dev/null | head -n "$TOP_N"
    else
        echo "lsof command not installed"
    fi
}

# ----------------------------------------------------------
# Process each filesystem
# ----------------------------------------------------------
check_filesystem() {

    local mount_point="$1"
    local warn_threshold="$2"
    local crit_threshold="$3"

    local mount_key
    mount_key=$(get_mount_key "$mount_point")

    local state_file="$STATE_DIR/${mount_key}.alert"
    local history_file="$STATE_DIR/${mount_key}.history"

    # ------------------------------------------------------
    # Get disk usage
    # ------------------------------------------------------
    local disk_usage
    disk_usage=$(df -P "$mount_point" 2>/dev/null |
        awk 'NR==2 {gsub("%","",$5); print $5}')

    local used_kb
    used_kb=$(df -Pk "$mount_point" 2>/dev/null |
        awk 'NR==2 {print $3}')

    # ------------------------------------------------------
    # Get inode usage
    # ------------------------------------------------------
    local inode_usage
    inode_usage=$(df -Pi "$mount_point" 2>/dev/null |
        awk 'NR==2 {gsub("%","",$5); print $5}')

    if [[ -z "$disk_usage" || -z "$used_kb" ]]; then
        log_message "ERROR" "Unable to read filesystem: $mount_point"
        return
    fi

    if [[ -z "$inode_usage" || "$inode_usage" == "-" ]]; then
        inode_usage=0
    fi

    # ------------------------------------------------------
    # Determine severity
    # ------------------------------------------------------
    local severity="NORMAL"

    if (( disk_usage >= crit_threshold ||
          inode_usage >= INODE_CRIT_THRESHOLD )); then

        severity="CRITICAL"

    elif (( disk_usage >= warn_threshold ||
            inode_usage >= INODE_WARN_THRESHOLD )); then

        severity="WARNING"
    fi

    # ------------------------------------------------------
    # Growth calculation
    # ------------------------------------------------------
    local current_time
    current_time=$(date +%s)

    local growth_message="No previous disk sample available"

    if [[ -f "$history_file" ]]; then

        read -r previous_time previous_used_kb < "$history_file"

        if [[ -n "$previous_time" &&
              -n "$previous_used_kb" &&
              "$current_time" -gt "$previous_time" ]]; then

            local diff_kb=$((used_kb - previous_used_kb))
            local diff_seconds=$((current_time - previous_time))

            local growth_mb
            local growth_mb_hour

            growth_mb=$(awk -v kb="$diff_kb" \
                'BEGIN {printf "%.2f", kb/1024}')

            growth_mb_hour=$(awk \
                -v kb="$diff_kb" \
                -v sec="$diff_seconds" \
                'BEGIN {
                    printf "%.2f", (kb/1024)/(sec/3600)
                }')

            growth_message="Change=${growth_mb} MB, Rate=${growth_mb_hour} MB/hour"
        fi
    fi

    echo "$current_time $used_kb" > "$history_file"

    # ------------------------------------------------------
    # NORMAL state
    # ------------------------------------------------------
    if [[ "$severity" == "NORMAL" ]]; then

        log_message "INFO" \
            "$mount_point Disk=${disk_usage}% Inode=${inode_usage}% Status=NORMAL"

        # Send recovery only when previous alert existed
        if [[ -f "$state_file" ]]; then

            read -r previous_severity previous_alert_time < "$state_file"

            echo
            echo "=============================================="
            echo "RECOVERED"
            echo "Filesystem : $mount_point"
            echo "Disk Usage : ${disk_usage}%"
            echo "Inode Usage: ${inode_usage}%"
            echo "Previous   : $previous_severity"
            echo "=============================================="
            echo

            log_message "RECOVERED" \
                "$mount_point recovered. Disk=${disk_usage}% Inode=${inode_usage}%"

            rm -f "$state_file"
        fi

        return
    fi

    # ------------------------------------------------------
    # Decide whether alert should be sent
    # ------------------------------------------------------
    local send_alert="NO"
    local alert_reason=""

    if [[ ! -f "$state_file" ]]; then

        send_alert="YES"
        alert_reason="First $severity alert"

    else

        read -r previous_severity previous_alert_time < "$state_file"

        local elapsed_seconds=$((current_time - previous_alert_time))
        local cooldown_seconds=$((COOLDOWN_MINUTES * 60))

        # Warning -> Critical must alert immediately
        if [[ "$severity" == "CRITICAL" &&
              "$previous_severity" != "CRITICAL" ]]; then

            send_alert="YES"
            alert_reason="Escalated from $previous_severity to CRITICAL"

        # Same severity after cooldown
        elif [[ "$severity" == "$previous_severity" &&
                "$elapsed_seconds" -ge "$cooldown_seconds" ]]; then

            send_alert="YES"
            alert_reason="Cooldown expired"

        else

            log_message "SUPPRESSED" \
                "$mount_point $severity alert suppressed. Disk=${disk_usage}% Inode=${inode_usage}%"

        fi
    fi

    # ------------------------------------------------------
    # Alert output
    # ------------------------------------------------------
    if [[ "$send_alert" == "YES" ]]; then

        echo
        echo "=================================================="
        echo "$severity DISK ALERT"
        echo "=================================================="
        echo "Filesystem     : $mount_point"
        echo "Disk Usage     : ${disk_usage}%"
        echo "Disk Warning   : ${warn_threshold}%"
        echo "Disk Critical  : ${crit_threshold}%"
        echo "Inode Usage    : ${inode_usage}%"
        echo "Growth         : $growth_message"
        echo "Reason         : $alert_reason"
        echo "Time           : $(date)"
        echo "=================================================="

        collect_evidence "$mount_point"

        echo
        echo "=================================================="
        echo

        log_message "$severity" \
            "$mount_point Disk=${disk_usage}% Inode=${inode_usage}% - $alert_reason"

        echo "$severity $current_time" > "$state_file"
    fi
}

# ==========================================================
# Main
# ==========================================================

log_message "INFO" "Disk monitoring started"

for mount_config in $MOUNTS; do

    IFS=':' read -r mount_point warn_threshold crit_threshold \
        <<< "$mount_config"

    check_filesystem \
        "$mount_point" \
        "$warn_threshold" \
        "$crit_threshold"
done

log_message "INFO" "Disk monitoring completed"

exit 0
