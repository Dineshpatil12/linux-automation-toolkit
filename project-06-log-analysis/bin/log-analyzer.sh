#!/usr/bin/env bash

set -u

readonly SCRIPT_NAME="log-analyzer.sh"
readonly VERSION="0.3.0"

CONFIG_FILE="/home/ec2-user/linux-automation-toolkit/project-06-log-analysis/config/log-analyzer.conf"

if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
else
    echo "ERROR: Configuration file not found: $CONFIG_FILE" >&2
    exit 2
fi

LOG_FILE="${LOG_FILE:-/tmp/log-analyzer.log}"

log() {
    printf '%s | %s | %s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "$1" \
        "$2" | tee -a "$LOG_FILE"
}

show_usage() {
    printf 'Usage: %s [--since "TIME"]\n' "$SCRIPT_NAME"
    printf '\n'
    printf 'Examples:\n'
    printf '  %s\n' "$SCRIPT_NAME"
    printf '  %s --since "1 hour ago"\n' "$SCRIPT_NAME"
    printf '  %s --since "24 hours ago"\n' "$SCRIPT_NAME"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --since)
            if [[ $# -lt 2 ]]; then
                printf 'ERROR: --since requires a value.\n' >&2
                show_usage
                exit 2
            fi

            SINCE="$2"
            shift 2
            ;;

        -h|--help)
            show_usage
            exit 0
            ;;

        *)
            printf 'ERROR: Unknown argument: %s\n' "$1" >&2
            show_usage
            exit 2
            ;;
    esac
done

collect_journal() {
    local output_file="$1"

    log "INFO" "Collecting journald data since: $SINCE"

    if sudo journalctl --no-pager --since "$SINCE" | tee "$output_file" >/dev/null; then
        log "INFO" "Journald collection completed"
        return 0
    fi

    log "WARN" "Journald collection failed"
    return 1
}

analyze_severity() {
    local input_file="$1"
    local report_file="$REPORT_DIR/severity-summary.txt"

    log "INFO" "Starting severity analysis"

    {
        echo "========================================"
        echo "Log Analyzer - Severity Summary"
        echo "========================================"
        echo
        echo "Analysis Window: $SINCE"
        echo "Source: $input_file"
        echo
        echo "ERROR Count:"
        grep -Eic '(^|[[:space:]])error([:[:space:]]|$)|level=error' "$input_file" || true
        echo
        echo "WARNING Count:"
        grep -Eic '(^|[[:space:]])warn(ing)?([:[:space:]]|$)|level=warn(ing)?' "$input_file" || true
        echo
        echo "CRITICAL/ALERT/EMERG/PANIC/FATAL Count:"
        grep -Eic 'critical|crit|alert|emerg|panic|fatal' "$input_file" || true
        echo
        echo "Top ERROR Messages:"
        grep -Ei '(^|[[:space:]])error([:[:space:]]|$)|level=error' "$input_file" \
            | tail -20 || true
    } > "$report_file"

    log "INFO" "Severity report created: $report_file"
}
detect_bruteforce() {
    local input_file="$1"
    local report_file="$REPORT_DIR/bruteforce-summary.txt"
    local threshold="${BRUTE_FORCE_THRESHOLD:-5}"
    local ip_counts="/tmp/log-analyzer-ip-counts.txt"

    log "INFO" "Starting brute-force detection"

    grep -Ei \
        'Failed (password|publickey) for |Invalid user |authentication failure|Too many authentication failures|maximum authentication attempts exceeded' \
        "$input_file" |
        sed -nE 's/.*from ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+).*/\1/p' |
        sort |
        uniq -c > "$ip_counts"

    {
        echo "========================================"
        echo "Log Analyzer - Brute-Force Detection"
        echo "========================================"
        echo
        echo "Analysis Window: $SINCE"
        echo "Threshold: $threshold failed attempts per source IP"
        echo

        awk -v threshold="$threshold" '
            $1 >= threshold {
                print "BRUTE_FORCE_CANDIDATE count=" $1 " source_ip=" $2
                found=1
            }
            END {
                if (!found)
                    print "No brute-force candidates detected."
            }
        ' "$ip_counts"
    } > "$report_file"

    rm -f "$ip_counts"

    log "INFO" "Brute-force report created: $report_file"
}

analyze_web_logs() {
    local input_file="$1"
    local report_file="$REPORT_DIR/web-summary.txt"

    log "INFO" "Starting web log analysis"

    if [ ! -f "$input_file" ]; then
        log "WARN" "Web log file not found: $input_file"
        return 1
    fi

    {
        echo "========================================"
        echo "Log Analyzer - Web Log Analysis"
        echo "========================================"
        echo
        echo "Analysis Window: $SINCE"
        echo "Source: $input_file"
        echo

        echo "HTTP Status Summary:"
        echo "--------------------"
        awk '{print $9}' "$input_file" |
            sort |
            uniq -c |
            sort -nr
        echo

        echo "4xx Client Error Requests:"
        echo "--------------------------"
        awk '$9 ~ /^4[0-9][0-9]$/ {print}' "$input_file" || true
        echo

        echo "5xx Server Error Requests:"
        echo "--------------------------"
        awk '$9 ~ /^5[0-9][0-9]$/ {print}' "$input_file" || true
        echo

        echo "Top Error Source IPs:"
        echo "---------------------"
        awk '$9 ~ /^(401|403|404|500|502)$/ {print $1}' "$input_file" |
            sort |
            uniq -c |
            sort -nr
    } > "$report_file"

    log "INFO" "Web log report created: $report_file"
}

analyze_service_instability() {
    local input_file="$1"
    local report_file="$REPORT_DIR/service-instability-summary.txt"
    local clean_file="/tmp/log-analyzer-service-clean.txt"

    log "INFO" "Starting service instability analysis"

    grep -Ev 'sudo\[[0-9]+\].*COMMAND=' "$input_file" > "$clean_file" || true

    {
        echo "========================================"
        echo "Log Analyzer - Service Instability"
        echo "========================================"
        echo
        echo "Analysis Window: $SINCE"
        echo "Source: $input_file"
        echo

        echo "Service Failure Events:"
        echo "-----------------------"
        grep -Ei 'systemd.*: .*\.service: Failed|Failed to start .*\.service|systemd.*failure' "$clean_file" || true
        echo

        echo "Service Restart Events:"
        echo "----------------------"
        grep -Ei 'systemd.*(scheduled restart job|restart counter|restarted)' "$clean_file" || true
        echo

        echo "Failure Count:"
        echo "--------------"
        grep -Eic 'systemd.*: .*\.service: Failed|Failed to start .*\.service|systemd.*failure' "$clean_file" || true
        echo

        echo "Restart Count:"
        echo "-------------"
        grep -Eic 'systemd.*(scheduled restart job|restart counter|restarted)' "$clean_file" || true
    } > "$report_file"

    rm -f "$clean_file"

    log "INFO" "Service instability report created: $report_file"
}

analyze_baseline() {
    local baseline_file="$REPORT_DIR/severity-baseline.txt"
    local current_file="$REPORT_DIR/severity-summary.txt"
    local report_file="$REPORT_DIR/baseline-comparison.txt"

    log "INFO" "Starting baseline comparison"

    if [ ! -f "$baseline_file" ]; then
        log "WARN" "Baseline file not found: $baseline_file"
        return 0
    fi

    local baseline_error
    local current_error
    local baseline_warning
    local current_warning
    local baseline_critical
    local current_critical

    baseline_error=$(awk '/^ERROR Count:/{getline; print; exit}' "$baseline_file")
    current_error=$(awk '/^ERROR Count:/{getline; print; exit}' "$current_file")

    baseline_warning=$(awk '/^WARNING Count:/{getline; print; exit}' "$baseline_file")
    current_warning=$(awk '/^WARNING Count:/{getline; print; exit}' "$current_file")

    baseline_critical=$(awk '/^CRITICAL\/ALERT\/EMERG\/PANIC\/FATAL Count:/{getline; print; exit}' "$baseline_file")
    current_critical=$(awk '/^CRITICAL\/ALERT\/EMERG\/PANIC\/FATAL Count:/{getline; print; exit}' "$current_file")

    {
        echo "========================================"
        echo "Log Analyzer - Baseline Comparison"
        echo "========================================"
        echo
        echo "Analysis Window: $SINCE"
        echo
        echo "Metric                         Baseline  Current  Difference"
        echo "------                         --------  -------  ----------"
        printf "%-30s %-9s %-8s %+d\n" "ERROR" "$baseline_error" "$current_error" "$((current_error - baseline_error))"
        printf "%-30s %-9s %-8s %+d\n" "WARNING" "$baseline_warning" "$current_warning" "$((current_warning - baseline_warning))"
        printf "%-30s %-9s %-8s %+d\n" "CRITICAL/ALERT/etc." "$baseline_critical" "$current_critical" "$((current_critical - baseline_critical))"
    } > "$report_file"

    log "INFO" "Baseline comparison report created: $report_file"
}

analyze_authentication() {
    local input_file="$1"
    local report_file="$REPORT_DIR/authentication-summary.txt"

    log "INFO" "Starting authentication forensics"

    {
        echo "========================================"
        echo "Log Analyzer - Authentication Forensics"
        echo "========================================"
        echo
        echo "Analysis Window: $SINCE"
        echo "Source: $input_file"
        echo

        echo "Successful SSH Logins:"
        grep -Eic 'Accepted (publickey|password) for ' "$input_file" || true
        echo

        echo "Failed SSH Authentication:"
        grep -Eic \
            'Failed (password|publickey) for |authentication failure|Too many authentication failures|maximum authentication attempts exceeded' \
            "$input_file" || true
        echo

        echo "Invalid Users:"
        grep -Eic 'Invalid user ' "$input_file" || true
        echo

        echo "Successful Login Details:"
        grep -Ei 'Accepted (publickey|password) for ' "$input_file" \
            | sed -E 's/.*Accepted (publickey|password) for ([^ ]+) from ([^ ]+).*/method=\1 user=\2 source_ip=\3/' \
            || true
    } > "$report_file"

    log "INFO" "Authentication report created: $report_file"
}

normalize_signature() {
    local message="$1"

    printf '%s\n' "$message" |
        sed -E \
            -e 's/[0-9]+ ms/<N> ms/g' \
            -e 's/[0-9]+ms/<N>ms/g' \
            -e 's/[0-9]+ seconds/<N> seconds/g' \
            -e 's/[0-9]+s/<N>s/g' \
            -e 's/0x[0-9a-fA-F]+/<HEX>/g' \
            -e 's/([[:digit:]]{1,3}\.){3}[[:digit:]]{1,3}/<IP>/g'
}
analyze_signatures() {
    local input_file="$1"
    local report_file="$REPORT_DIR/signature-summary.txt"
    local normalized_file="/tmp/log-analyzer-normalized.txt"

    log "INFO" "Starting signature normalization"

    while IFS= read -r line; do
        normalize_signature "$line"
    done < "$input_file" > "$normalized_file"

    {
        echo "========================================"
        echo "Log Analyzer - Signature Summary"
        echo "========================================"
        echo
        echo "Analysis Window: $SINCE"
        echo "Source: $input_file"
        echo
        echo "Count  Normalized Signature"
        echo "-----  ---------------------"
        sort "$normalized_file" | uniq -c | sort -nr
    } > "$report_file"

    rm -f "$normalized_file"

    log "INFO" "Signature report created: $report_file"
}

log "INFO" "$SCRIPT_NAME version $VERSION started"
log "INFO" "Analysis window: since $SINCE"

JOURNAL_FILE="/tmp/log-analyzer-journal.txt"

if collect_journal "$JOURNAL_FILE"; then
    JOURNAL_STATUS="SUCCESS"
else
    JOURNAL_STATUS="FAILED"
fi

if [[ "$JOURNAL_STATUS" == "FAILED" ]]; then
    log "ERROR" "Log collection failed"
    exit 3
fi

printf '\nLog Analyzer\n'
printf 'Version: %s\n' "$VERSION"
printf 'Since:   %s\n' "$SINCE"
printf 'Journal: %s\n' "$JOURNAL_STATUS"

if [[ "$JOURNAL_STATUS" == "SUCCESS" ]]; then
    printf 'Records: '
    wc -l < "$JOURNAL_FILE"
fi

printf 'Status:  Collection completed\n'

ANALYSIS_ISSUES=0

analyze_severity "$JOURNAL_FILE" || ANALYSIS_ISSUES=1
analyze_signatures "$JOURNAL_FILE" || ANALYSIS_ISSUES=1
analyze_authentication "$JOURNAL_FILE" || ANALYSIS_ISSUES=1
detect_bruteforce "$JOURNAL_FILE" || ANALYSIS_ISSUES=1
analyze_web_logs "/home/ec2-user/linux-automation-toolkit/project-06-log-analysis/tests/fixtures/web-access-test.log" || ANALYSIS_ISSUES=1
analyze_service_instability "$JOURNAL_FILE" || ANALYSIS_ISSUES=1
analyze_baseline || ANALYSIS_ISSUES=1

if (( ANALYSIS_ISSUES )); then
    log "WARN" "Analysis completed with one or more module issues"
    exit 1
fi

log "INFO" "Analysis completed successfully"
exit 0
