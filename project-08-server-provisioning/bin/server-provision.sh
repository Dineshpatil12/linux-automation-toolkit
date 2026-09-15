#!/usr/bin/env bash

set -o pipefail

# ============================================================
# Project 08 - Automated Server Provisioning
# Safe, idempotent, configuration-driven provisioning
# ============================================================

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

CONFIG_FILE="${PROJECT_ROOT}/conf/provisioning.conf"

DRY_RUN=false
LOG_FILE=""

# ------------------------------------------------------------
# Exit codes
# ------------------------------------------------------------
EXIT_SUCCESS=0
EXIT_USAGE=2
EXIT_PREREQUISITE=3
EXIT_CONFIG=4
EXIT_PROVISIONING=5
EXIT_VALIDATION=6

# ------------------------------------------------------------
# Logging
# ------------------------------------------------------------
log() {
    local level="$1"
    shift

    local message
    message="$(date '+%Y-%m-%d %H:%M:%S') [${level}] $*"

    echo "$message"

    if [[ -n "${LOG_FILE}" && -f "${LOG_FILE}" && -w "${LOG_FILE}" ]]; then
        printf '%s\n' "$message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

die() {
    local code="$1"
    shift
    log "ERROR" "$*"
    exit "$code"
}

# ------------------------------------------------------------
# Usage
# ------------------------------------------------------------
usage() {
    cat <<USAGE
Usage:
  ${SCRIPT_NAME} [OPTIONS]

Options:
  -c, --config FILE    Use a custom configuration file
  -n, --dry-run        Show planned actions without changing the system
  -h, --help           Show this help message

Examples:
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} --dry-run
  ${SCRIPT_NAME} --config /path/to/provisioning.conf
USAGE
}

# ------------------------------------------------------------
# Argument parsing
# ------------------------------------------------------------
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--config)
                [[ $# -ge 2 ]] || die "$EXIT_USAGE" "Missing value for $1"
                CONFIG_FILE="$2"
                shift 2
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                usage
                exit "$EXIT_SUCCESS"
                ;;
            *)
                usage
                die "$EXIT_USAGE" "Unknown option: $1"
                ;;
        esac
    done
}

# ------------------------------------------------------------
# Root / sudo validation
# ------------------------------------------------------------
check_privileges() {
    if [[ "${EUID}" -eq 0 ]]; then
        log "INFO" "Running with root privileges."
        return 0
    fi

    if sudo -n true 2>/dev/null; then
        log "INFO" "Passwordless sudo is available."
        return 0
    fi

    die "$EXIT_PREREQUISITE" \
        "Root privileges or passwordless sudo are required."
}

# ------------------------------------------------------------
# OS detection
# ------------------------------------------------------------
detect_os() {
    [[ -r /etc/os-release ]] ||
        die "$EXIT_PREREQUISITE" "/etc/os-release not found."

    # shellcheck disable=SC1091
    source /etc/os-release

    OS_ID="${ID:-unknown}"
    OS_VERSION="${VERSION_ID:-unknown}"
    OS_NAME="${PRETTY_NAME:-unknown}"

    log "INFO" "Detected OS: ${OS_NAME}"

    case "${OS_ID}" in
        amzn|rhel|centos|rocky|almalinux|fedora|ubuntu|debian)
            ;;
        *)
            die "$EXIT_PREREQUISITE" \
                "Unsupported operating system: ${OS_ID}"
            ;;
    esac
}

# ------------------------------------------------------------
# Package manager detection
# ------------------------------------------------------------
detect_package_manager() {
    if command -v dnf >/dev/null 2>&1; then
        PACKAGE_MANAGER="dnf"
    elif command -v yum >/dev/null 2>&1; then
        PACKAGE_MANAGER="yum"
    elif command -v apt-get >/dev/null 2>&1; then
        PACKAGE_MANAGER="apt-get"
    else
        die "$EXIT_PREREQUISITE" "No supported package manager found."
    fi

    log "INFO" "Package manager: ${PACKAGE_MANAGER}"
}

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------
load_config() {
    [[ -f "${CONFIG_FILE}" ]] ||
        die "$EXIT_CONFIG" "Configuration file not found: ${CONFIG_FILE}"

    [[ -r "${CONFIG_FILE}" ]] ||
        die "$EXIT_CONFIG" "Configuration file is not readable: ${CONFIG_FILE}"

    # shellcheck disable=SC1090
    source "${CONFIG_FILE}"

    LOG_FILE="${LOG_FILE:-/opt/devopsshack/logs/provisioning.log}"

    log "INFO" "Configuration loaded: ${CONFIG_FILE}"
}


# ------------------------------------------------------------
# Package provisioning
# ------------------------------------------------------------
command_is_available() {
    local command_name="$1"
    command -v "${command_name}" >/dev/null 2>&1
}

install_package() {
    local package="$1"

    if [[ "${DRY_RUN}" == "true" ]]; then
        log "DRY-RUN" "Would install package: ${package}"
        return 0
    fi

    log "INFO" "Installing package: ${package}"

    case "${PACKAGE_MANAGER}" in
        dnf)
            sudo dnf install -y "${package}" || return 1
            ;;
        yum)
            sudo yum install -y "${package}" || return 1
            ;;
        apt-get)
            sudo apt-get install -y "${package}" || return 1
            ;;
    esac

    log "INFO" "Package installation completed: ${package}"
}

provision_packages() {
    log "INFO" "Starting package assessment."

    [[ -n "${REQUIRED_COMMANDS:-}" ]] ||
        die "$EXIT_CONFIG" "REQUIRED_COMMANDS is empty."

    local command_name
    for command_name in ${REQUIRED_COMMANDS}; do
        if command_is_available "${command_name}"; then
            log "INFO" "Command already available: ${command_name}"
        else
            log "INFO" "Required command missing: ${command_name}"

            case "${command_name}" in
                iostat)
                    install_package "sysstat" ||
                        die "$EXIT_PROVISIONING" \
                            "Failed to provision package for ${command_name}"
                    ;;
                *)
                    install_package "${command_name}" ||
                        die "$EXIT_PROVISIONING" \
                            "Failed to provision package for ${command_name}"
                    ;;
            esac

            if [[ "${DRY_RUN}" == "false" ]] &&
               ! command_is_available "${command_name}"; then
                die "$EXIT_PROVISIONING" \
                    "Required command still unavailable: ${command_name}"
            fi
        fi
    done

    log "INFO" "Package assessment/provisioning completed."
}

# ------------------------------------------------------------
# Directory provisioning
# ------------------------------------------------------------
provision_directory() {
    local directory="$1"
    local mode="$2"
    local current_mode

    if [[ -d "${directory}" ]]; then
        current_mode="$(stat -c '%a' "${directory}")"

        if [[ "${current_mode}" == "${mode}" ]]; then
            log "INFO" "Directory already exists with correct mode: ${directory} (${mode})"
            return 0
        fi

        if [[ "${DRY_RUN}" == "true" ]]; then
            log "DRY-RUN" "Would correct directory mode: ${directory} ${current_mode} -> ${mode}"
            return 0
        fi

        log "INFO" "Correcting directory mode: ${directory} ${current_mode} -> ${mode}"

        sudo chmod "${mode}" "${directory}" ||
            return 1

        log "INFO" "Directory mode corrected: ${directory} (${mode})"
        return 0
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
        log "DRY-RUN" "Would create directory: ${directory} mode=${mode}"
        return 0
    fi

    log "INFO" "Creating directory: ${directory}"

    sudo install -d -m "${mode}" "${directory}" ||
        return 1

    log "INFO" "Directory created: ${directory}"
}

provision_directories() {
    log "INFO" "Starting directory assessment."

    provision_directory "${RUNTIME_ROOT}" "0755" ||
        die "$EXIT_PROVISIONING" "Failed to provision ${RUNTIME_ROOT}"

    provision_directory "${RUNTIME_BIN}" "0750" ||
        die "$EXIT_PROVISIONING" "Failed to provision ${RUNTIME_BIN}"

    provision_directory "${RUNTIME_CONF}" "0750" ||
        die "$EXIT_PROVISIONING" "Failed to provision ${RUNTIME_CONF}"

    provision_directory "${RUNTIME_LOGS}" "0750" ||
        die "$EXIT_PROVISIONING" "Failed to provision ${RUNTIME_LOGS}"

    provision_directory "${RUNTIME_ROOT}/state" "0750" ||
        die "$EXIT_PROVISIONING" "Failed to provision state directory"

    provision_directory "${RUNTIME_ROOT}/reports" "0750" ||
        die "$EXIT_PROVISIONING" "Failed to provision reports directory"

    log "INFO" "Directory assessment/provisioning completed."
}


# ------------------------------------------------------------
# Logging initialization
# ------------------------------------------------------------
initialize_logging() {
    if [[ "${DRY_RUN}" == "true" ]]; then
        log "DRY-RUN" "Would initialize log file: ${LOG_FILE}"
        return 0
    fi

    sudo touch "${LOG_FILE}" ||
        die "$EXIT_PROVISIONING" "Failed to create log file: ${LOG_FILE}"

    sudo chown "$(id -un):$(id -gn)" "${LOG_FILE}" ||
        die "$EXIT_PROVISIONING" "Failed to set log ownership: ${LOG_FILE}"

    sudo chmod 640 "${LOG_FILE}" ||
        die "$EXIT_PROVISIONING" "Failed to set log permissions: ${LOG_FILE}"

    log "INFO" "Logging initialized: ${LOG_FILE}"
}


# ------------------------------------------------------------
# User and group provisioning
# ------------------------------------------------------------
group_exists() {
    local group="$1"
    getent group "${group}" >/dev/null 2>&1
}

user_exists() {
    local user="$1"
    id "${user}" >/dev/null 2>&1
}

provision_group() {
    local group="$1"

    if group_exists "${group}"; then
        log "INFO" "Group already exists: ${group}"
        return 0
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
        log "DRY-RUN" "Would create group: ${group}"
        return 0
    fi

    log "INFO" "Creating group: ${group}"

    sudo groupadd "${group}" ||
        return 1

    log "INFO" "Group created: ${group}"
}

provision_user() {
    local user="$1"
    local group="$2"

    [[ -n "${user}" ]] || return 0

    if user_exists "${user}"; then
        log "INFO" "User already exists: ${user}"
    else
        if [[ "${DRY_RUN}" == "true" ]]; then
            log "DRY-RUN" "Would create user: ${user}"
        else
            log "INFO" "Creating user: ${user}"

            sudo useradd \
                --create-home \
                --shell /bin/bash \
                "${user}" ||
                return 1

            log "INFO" "User created: ${user}"
        fi
    fi

    if ! id -nG "${user}" 2>/dev/null |
        tr ' ' '\n' |
        grep -Fxq "${group}"; then

        if [[ "${DRY_RUN}" == "true" ]]; then
            log "DRY-RUN" "Would add ${user} to group ${group}"
        else
            log "INFO" "Adding ${user} to group ${group}"

            sudo usermod -aG "${group}" "${user}" ||
                return 1
        fi
    else
        log "INFO" "User ${user} is already a member of ${group}"
    fi
}

provision_users_and_groups() {
    log "INFO" "Starting user/group assessment."

    [[ -n "${ADMIN_GROUP:-}" ]] ||
        die "$EXIT_CONFIG" "ADMIN_GROUP is empty."

    provision_group "${ADMIN_GROUP}" ||
        die "$EXIT_PROVISIONING" \
            "Failed to provision group: ${ADMIN_GROUP}"

    if [[ -n "${PROVISION_USER:-}" ]]; then
        provision_user "${PROVISION_USER}" "${ADMIN_GROUP}" ||
            die "$EXIT_PROVISIONING" \
                "Failed to provision user: ${PROVISION_USER}"
    else
        log "INFO" "No provisioning user configured; no user will be created."
    fi

    log "INFO" "User/group assessment/provisioning completed."
}


# ------------------------------------------------------------
# Service provisioning
# ------------------------------------------------------------
service_enabled() {
    local service="$1"
    systemctl is-enabled "${service}" >/dev/null 2>&1
}

service_active() {
    local service="$1"
    systemctl is-active "${service}" >/dev/null 2>&1
}

provision_service() {
    local service="$1"

    if ! systemctl list-unit-files "${service}.service" >/dev/null 2>&1; then
        log "ERROR" "Service not found: ${service}"
        return 1
    fi

    if service_active "${service}"; then
        log "INFO" "Service already active: ${service}"
    else
        if [[ "${DRY_RUN}" == "true" ]]; then
            log "DRY-RUN" "Would start service: ${service}"
        else
            log "INFO" "Starting service: ${service}"

            sudo systemctl start "${service}" ||
                return 1

            service_active "${service}" ||
                return 1

            log "INFO" "Service started successfully: ${service}"
        fi
    fi

    if service_enabled "${service}"; then
        log "INFO" "Service already enabled: ${service}"
    else
        if [[ "${DRY_RUN}" == "true" ]]; then
            log "DRY-RUN" "Would enable service: ${service}"
        else
            log "INFO" "Enabling service: ${service}"

            sudo systemctl enable "${service}" ||
                return 1

            service_enabled "${service}" ||
                return 1

            log "INFO" "Service enabled successfully: ${service}"
        fi
    fi
}

provision_services() {
    log "INFO" "Starting service assessment."

    if [[ "${ENABLE_CHRONYD:-false}" == "true" ]]; then
        provision_service "chronyd" ||
            die "$EXIT_PROVISIONING" "Failed to provision chronyd."
    fi

    if [[ "${ENABLE_CROND:-false}" == "true" ]]; then
        provision_service "crond" ||
            die "$EXIT_PROVISIONING" "Failed to provision crond."
    fi

    if [[ "${ENABLE_DOCKER:-false}" == "true" ]]; then
        provision_service "docker" ||
            die "$EXIT_PROVISIONING" "Failed to provision docker."
    fi

    log "INFO" "Service assessment/provisioning completed."
}


# ------------------------------------------------------------
# Validation and reporting
# ------------------------------------------------------------
VALIDATION_FAILURES=0
REPORT_FILE=""

validation_pass() {
    log "PASS" "$*"
}

validation_fail() {
    log "FAIL" "$*"
    VALIDATION_FAILURES=$((VALIDATION_FAILURES + 1))
}

validate_os() {
    if [[ "${OS_ID}" == "amzn" ]]; then
        validation_pass "OS validation: Amazon Linux detected."
    else
        validation_fail "OS validation failed: ${OS_NAME}"
    fi
}

validate_commands() {
    local command_name

    for command_name in ${REQUIRED_COMMANDS}; do
        if command_is_available "${command_name}"; then
            validation_pass "Command available: ${command_name}"
        else
            validation_fail "Command missing: ${command_name}"
        fi
    done
}

validate_directories() {
    local directory

    for directory in \
        "${RUNTIME_ROOT}" \
        "${RUNTIME_BIN}" \
        "${RUNTIME_CONF}" \
        "${RUNTIME_LOGS}" \
        "${RUNTIME_ROOT}/state" \
        "${RUNTIME_ROOT}/reports"
    do
        if [[ -d "${directory}" ]]; then
            validation_pass "Directory exists: ${directory}"
        else
            validation_fail "Directory missing: ${directory}"
        fi
    done
}

validate_group() {
    if group_exists "${ADMIN_GROUP}"; then
        validation_pass "Group exists: ${ADMIN_GROUP}"
    else
        validation_fail "Group missing: ${ADMIN_GROUP}"
    fi
}

validate_services() {
    local service

    for service in chronyd crond docker; do
        if systemctl is-active --quiet "${service}"; then
            validation_pass "Service active: ${service}"
        else
            validation_fail "Service not active: ${service}"
        fi

        if systemctl is-enabled --quiet "${service}"; then
            validation_pass "Service enabled: ${service}"
        else
            validation_fail "Service not enabled: ${service}"
        fi
    done
}

validate_time_sync() {
    if timedatectl show -p NTPSynchronized --value 2>/dev/null |
        grep -qi '^yes$'; then
        validation_pass "NTP synchronization: active."
    else
        validation_fail "NTP synchronization is not active."
    fi
}

generate_report() {
    REPORT_FILE="${RUNTIME_ROOT}/reports/project-08-provisioning-report.txt"

    if [[ "${DRY_RUN}" == "true" ]]; then
        log "DRY-RUN" "Would generate report: ${REPORT_FILE}"
        return 0
    fi

    log "INFO" "Generating provisioning report: ${REPORT_FILE}"

    sudo tee "${REPORT_FILE}" >/dev/null <<REPORT
Project 08 - Automated Server Provisioning
===========================================

Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')

Server:
  Hostname: ${HOSTNAME:-unknown}
  OS: ${OS_NAME}
  Kernel: $(uname -r)
  Package Manager: ${PACKAGE_MANAGER}

Validation:
  Failures: ${VALIDATION_FAILURES}

Result:
  $(if [[ "${VALIDATION_FAILURES}" -eq 0 ]]; then echo "PASS"; else echo "FAIL"; fi)
REPORT

    if ! sudo test -f "${REPORT_FILE}"; then
        log "ERROR" "Failed to create provisioning report: ${REPORT_FILE}"
        return 1
    fi

    sudo chmod 640 "${REPORT_FILE}" ||
        return 1

    log "INFO" "Provisioning report generated: ${REPORT_FILE}"
}


validate_server() {
    log "INFO" "Starting final server validation."

    VALIDATION_FAILURES=0

    validate_os
    validate_commands
    validate_directories
    validate_group
    validate_services
    validate_time_sync

    if ! generate_report; then
        log "ERROR" "Report generation failed."
        return 1
    fi

    if [[ "${VALIDATION_FAILURES}" -gt 0 ]]; then
        log "ERROR" \
            "Validation completed with ${VALIDATION_FAILURES} failure(s)."
        return 1
    fi

    log "INFO" "All validation checks passed."
    return 0
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------
main() {
    parse_arguments "$@"

    echo "============================================================"
    echo " Project 08 - Automated Server Provisioning"
    echo "============================================================"

    check_privileges
    detect_os
    detect_package_manager
    load_config

    provision_directories
    initialize_logging

    if [[ "${DRY_RUN}" == "true" ]]; then
        log "INFO" "DRY-RUN mode enabled. No system changes will be made."
    else
        log "INFO" "Normal mode selected."
    fi

    log "INFO" "Provisioning framework initialized."

    provision_packages
    provision_users_and_groups
    provision_services

    if [[ "${VALIDATE_AFTER_PROVISION:-true}" == "true" ]]; then
        validate_server || exit "$EXIT_VALIDATION"
    fi

    exit "$EXIT_SUCCESS"
}

main "$@"
