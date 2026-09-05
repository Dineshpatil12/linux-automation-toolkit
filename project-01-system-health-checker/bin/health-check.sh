#!/usr/bin/env bash

set -euo pipefail

CONFIG_FILE="/opt/devopsshack/conf/health.conf"
LOG_FILE="/opt/devopsshack/logs/health-check.log"

OVERALL_STATUS="OK"

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 2
fi

log_message() {
    local MESSAGE="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $MESSAGE" | tee -a "$LOG_FILE"
}

update_overall_status() {
    local CURRENT_STATUS="$1"

    if [[ "$CURRENT_STATUS" == "CRITICAL" ]]; then
        OVERALL_STATUS="CRITICAL"

    elif [[ "$CURRENT_STATUS" == "WARNING" && "$OVERALL_STATUS" != "CRITICAL" ]]; then
        OVERALL_STATUS="WARNING"
    fi
}

check_cpu() {
    read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat

    total1=$((user + nice + system + idle + iowait + irq + softirq + steal))
    idle1=$((idle + iowait))

    sleep 1

    read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat

    total2=$((user + nice + system + idle + iowait + irq + softirq + steal))
    idle2=$((idle + iowait))

    total_diff=$((total2 - total1))
    idle_diff=$((idle2 - idle1))

    cpu_usage=$((100 * (total_diff - idle_diff) / total_diff))

    if (( cpu_usage >= CPU_CRIT )); then
        status="CRITICAL"
    elif (( cpu_usage >= CPU_WARN )); then
        status="WARNING"
    else
        status="OK"
    fi
    update_overall_status "$status"
    log_message "CPU Usage: ${cpu_usage}% - Status: $status"
}

check_memory() {
    mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    mem_available=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)

    mem_used=$((mem_total - mem_available))
    mem_usage=$((100 * mem_used / mem_total))

    if (( mem_usage >= MEM_CRIT )); then
        status="CRITICAL"
    elif (( mem_usage >= MEM_WARN )); then
        status="WARNING"
    else
        status="OK"
    fi

    update_overall_status "$status"
    log_message "Memory Usage: ${mem_usage}% - Status: $status"
}

check_swap() {
    swap_total=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
    swap_free=$(awk '/SwapFree/ {print $2}' /proc/meminfo)

    if (( swap_total == 0 )); then
        log_message "Swap Usage: No swap configured - Status: OK"
        return
    fi

    swap_used=$((swap_total - swap_free))
    swap_usage=$((100 * swap_used / swap_total))

    if (( swap_usage >= SWAP_CRIT )); then
        status="CRITICAL"
    elif (( swap_usage >= SWAP_WARN )); then
        status="WARNING"
    else
        status="OK"
    fi

    update_overall_status "$status"
    log_message "Swap Usage: ${swap_usage}% - Status: $status"
}

check_disk() {
    disk_usage=$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')

    if (( disk_usage >= DISK_CRIT )); then
        status="CRITICAL"
    elif (( disk_usage >= DISK_WARN )); then
        status="WARNING"
    else
        status="OK"
    fi

    update_overall_status "$status"
    log_message "Disk Usage (/): ${disk_usage}% - Status: $status"
}

check_inode() {
    inode_usage=$(df -Pi / | awk 'NR==2 {gsub("%","",$5); print $5}')

    if (( inode_usage >= INODE_CRIT )); then
        status="CRITICAL"
    elif (( inode_usage >= INODE_WARN )); then
        status="WARNING"
    else
        status="OK"
    fi

    update_overall_status "$status"
    log_message "Inode Usage (/): ${inode_usage}% - Status: $status"
}

check_load() {
    load_1min=$(awk '{print $1}' /proc/loadavg)
    cpu_count=$(nproc)

    load_per_core=$(echo "scale=2; $load_1min / $cpu_count" | bc)

    if (( $(echo "$load_per_core >= $LOAD_CRIT" | bc -l) )); then
        status="CRITICAL"
    elif (( $(echo "$load_per_core >= $LOAD_WARN" | bc -l) )); then
        status="WARNING"
    else
        status="OK"
    fi

    update_overall_status "$status"
    log_message "Load Average (1m/Core): ${load_per_core} - Status: $status"
}

check_uptime() {
    uptime_info=$(uptime -p)
    boot_time=$(uptime -s)

    log_message "Uptime: $uptime_info"
    log_message "Server Boot Time: $boot_time"
}

check_top_processes() {
    log_message "Top ${TOP_PROCESSES} CPU consuming processes:"

    ps -eo pid,comm,pcpu,pmem,user --sort=-pcpu \
        | head -n $((TOP_PROCESSES + 1)) \
        | tee -a "$LOG_FILE"

    log_message "Top ${TOP_PROCESSES} Memory consuming processes:"

    ps -eo pid,comm,pcpu,pmem,user --sort=-pmem \
        | head -n $((TOP_PROCESSES + 1)) \
        | tee -a "$LOG_FILE"
}

log_message "Health check script started successfully."
check_cpu
check_memory
check_swap
check_disk
check_inode
check_load
check_uptime
check_top_processes

log_message "Overall Server Health: $OVERALL_STATUS"

if [[ "$OVERALL_STATUS" == "CRITICAL" ]]; then
    exit 2
elif [[ "$OVERALL_STATUS" == "WARNING" ]]; then
    exit 1
else
    exit 0
fi
