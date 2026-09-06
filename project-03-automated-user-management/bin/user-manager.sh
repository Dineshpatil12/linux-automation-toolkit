#!/bin/bash

set -u

CSV_FILE="/opt/devopsshack/conf/users.csv"
AUDIT_LOG="/opt/devopsshack/logs/user-management-audit.log"

DRY_RUN=false

BACKUP_DIR="/opt/devopsshack/backups/offboarded-users"

if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

log() {
    local level="$1"
    local message="$2"

    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" | tee -a "$AUDIT_LOG"
}

run_cmd() {
    local description="$1"
    shift

    if $DRY_RUN; then
        log "DRY-RUN" "$description"
    else
        "$@"
        log "CHANGE" "$description"
    fi
}

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Run this script using sudo/root."
    exit 1
fi

if [[ ! -f "$CSV_FILE" ]]; then
    log "ERROR" "CSV file not found: $CSV_FILE"
    exit 1
fi

log "INFO" "User reconciliation started"

tail -n +2 "$CSV_FILE" |
while IFS=',' read -r username fullname groups shell sudo_access expiry ssh_key
do
    [[ -z "$username" ]] && continue

    log "INFO" "Checking user: $username"

    if id "$username" >/dev/null 2>&1; then
        log "OK" "User $username already exists"
    else
        run_cmd \
            "Creating user $username" \
            useradd -m -c "$fullname" -s "$shell" "$username"
    fi

    if ! id "$username" >/dev/null 2>&1 && $DRY_RUN; then
        log "DRY-RUN" "Would configure remaining settings for $username"
        continue
    fi

    if [[ -n "$groups" ]]; then
        IFS='|' read -ra GROUP_ARRAY <<< "$groups"

        for group in "${GROUP_ARRAY[@]}"
        do
            if id -nG "$username" | tr ' ' '\n' | grep -qx "$group"; then
                log "OK" "$username already belongs to $group"
            else
                run_cmd \
                    "Adding $username to group $group" \
                    usermod -aG "$group" "$username"
            fi
        done

	log "INFO" "Checking for users to offboard"

	managed_users=$(tail -n +2 "$CSV_FILE" | cut -d',' -f1)

	while IFS=: read -r existing_user _ uid _ _ home _
	do
    # Skip system/special accounts.
	[[ "$uid" -lt 1000 ]] && continue
	[[ "$uid" -ge 60000 ]] && continue

    # Never touch our EC2 login account.
	[[ "$existing_user" == "ec2-user" ]] && continue

    # Only manage normal users whose home is under /home.
	[[ "$home" != /home/* ]] && continue

    [[ "$existing_user" == "ec2-user" ]] && continue

    if ! echo "$managed_users" | grep -qx "$existing_user"; then

        log "WARNING" "User $existing_user is not present in desired state"

	        account_status=$(passwd -S "$existing_user" 2>/dev/null | awk '{print $2}')
        account_expiry=$(chage -l "$existing_user" 2>/dev/null |
            awk -F': ' '/Account expires/ {print $2}')

        if [[ "$account_status" == "LK" && "$account_expiry" == "Jan 01, 1970" ]]; then
            log "OK" "$existing_user already offboarded"
            continue
        fi

        if $DRY_RUN; then
            log "DRY-RUN" "Would offboard user $existing_user"
            continue
        fi

        mkdir -p "$BACKUP_DIR"

        backup_file="$BACKUP_DIR/${existing_user}-$(date '+%Y%m%d-%H%M%S').tar.gz"

        if [[ -d "$home" ]]; then
            tar -czf "$backup_file" "$home" 2>/dev/null
            chmod 600 "$backup_file"
            log "CHANGE" "Archived home directory for $existing_user to $backup_file"
        fi

        pkill -KILL -u "$existing_user" 2>/dev/null || true

        usermod -L "$existing_user"
        chage -E 0 "$existing_user"

        if getent group wheel >/dev/null; then
            gpasswd -d "$existing_user" wheel >/dev/null 2>&1 || true
        fi

        if getent group sudo >/dev/null; then
            gpasswd -d "$existing_user" sudo >/dev/null 2>&1 || true
        fi

        log "CHANGE" "Offboarded user $existing_user"

    fi

done < /etc/passwd

    fi

    current_shell=$(getent passwd "$username" | cut -d: -f7)

    if [[ "$current_shell" != "$shell" ]]; then
        run_cmd \
            "Changing shell for $username to $shell" \
            usermod -s "$shell" "$username"
    else
        log "OK" "Shell already correct for $username"
    fi

    if [[ "$sudo_access" == "yes" ]]; then
        if getent group wheel >/dev/null; then
            ADMIN_GROUP="wheel"
        elif getent group sudo >/dev/null; then
            ADMIN_GROUP="sudo"
        else
            ADMIN_GROUP=""
        fi

        if [[ -n "$ADMIN_GROUP" ]]; then
            if id -nG "$username" | tr ' ' '\n' | grep -qx "$ADMIN_GROUP"; then
                log "OK" "$username already has sudo access"
            else
                run_cmd \
                    "Granting sudo access to $username using $ADMIN_GROUP" \
                    usermod -aG "$ADMIN_GROUP" "$username"
            fi
        fi
    fi

	if [[ "$expiry" != "never" && -n "$expiry" ]]; then

    		current_expiry=$(chage -l "$username" | awk -F': ' '/Account expires/ {print $2}')

    		desired_expiry=$(date -d "$expiry" '+%b %d, %Y')

    	if [[ "$current_expiry" != "$desired_expiry" ]]; then
        	run_cmd \
            		"Setting expiry $expiry for $username" \
            		chage -E "$expiry" "$username"
    	else
        	log "OK" "Account expiry already correct for $username"
    fi

fi

    if [[ -f "$ssh_key" ]]; then
        HOME_DIR=$(getent passwd "$username" | cut -d: -f6)
        SSH_DIR="$HOME_DIR/.ssh"
        AUTH_KEYS="$SSH_DIR/authorized_keys"

        desired_key=$(cat "$ssh_key")
        current_key=""

        [[ -f "$AUTH_KEYS" ]] && current_key=$(cat "$AUTH_KEYS")

        if [[ "$desired_key" != "$current_key" ]]; then
            if $DRY_RUN; then
                log "DRY-RUN" "Would install SSH key for $username"
            else
                mkdir -p "$SSH_DIR"
                cp "$ssh_key" "$AUTH_KEYS"
                chown -R "$username:$username" "$SSH_DIR"
                chmod 700 "$SSH_DIR"
                chmod 600 "$AUTH_KEYS"

                log "CHANGE" "SSH key installed for $username"
            fi
        else
            log "OK" "SSH key already correct for $username"
        fi
    else
        log "WARNING" "SSH public key missing for $username: $ssh_key"
    fi

done

log "INFO" "User reconciliation completed"
