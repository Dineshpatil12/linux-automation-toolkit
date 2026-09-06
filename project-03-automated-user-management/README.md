# Project 3 - Automated User Management System

## Overview

This project automates the Linux user lifecycle using Bash.

Instead of manually creating, modifying, and disabling Linux users, the script reads the required user configuration from a CSV file and reconciles the Linux server with that desired state.

The project demonstrates:

* Declarative user management
* Idempotent automation
* Linux user and group management
* SSH public key management
* Sudo access management
* Account expiry
* Safe user offboarding
* Home directory archival
* Audit logging
* Dry-run safety
* Protected system-account handling

---

## Architecture

```text
users.csv
   |
   v
user-manager.sh
   |
   +--> Create missing users
   +--> Manage groups
   +--> Manage login shell
   +--> Manage sudo access
   +--> Configure SSH public keys
   +--> Configure account expiry
   +--> Identify unmanaged users
   +--> Safely offboard users
   +--> Archive home directories
   +--> Write audit logs
```

---

## Project Structure

```text
project-03-automated-user-management/
├── README.md
├── .gitignore
├── bin/
│   └── user-manager.sh
├── conf/
│   ├── users.csv.example
│   └── keys/
├── sample-output/
└── screenshots/
```

---

## Runtime Structure

The script is executed from the following runtime location:

```text
/opt/devopsshack/
├── bin/
│   └── user-manager.sh
├── conf/
│   ├── users.csv
│   └── keys/
├── logs/
│   └── user-management-audit.log
└── backups/
    └── offboarded-users/
```

---

## User Manifest

The required Linux users are defined in a CSV file.

Example:

```csv
username,fullname,groups,shell,sudo,expiry,ssh_key
devuser1,Dev User One,developers,/bin/bash,yes,2026-12-31,/opt/devopsshack/conf/keys/devuser1.pub
```

Each field defines the desired state of the user.

| Field    | Description                     |
| -------- | ------------------------------- |
| username | Linux username                  |
| fullname | Full name of the user           |
| groups   | Additional Linux groups         |
| shell    | Login shell                     |
| sudo     | Whether sudo access is required |
| expiry   | Account expiry date             |
| ssh_key  | SSH public key path             |

The script compares this desired state with the current Linux server configuration and applies only the required changes.

---

## Declarative User Management

This project follows a declarative approach.

Instead of running individual commands manually such as:

```bash
useradd
usermod
chage
```

the required state is defined in `users.csv`.

The script checks:

```text
Desired state
      |
      v
Current Linux state
      |
      v
Difference detected
      |
      v
Required change applied
```

This process is called reconciliation.

---

## Dry-Run Mode

Before applying any real changes, the script can be executed in dry-run mode.

```bash
sudo /opt/devopsshack/bin/user-manager.sh --dry-run
```

Example output:

```text
[INFO] User reconciliation started
[INFO] Checking user: devuser1
[DRY-RUN] Creating user devuser1
[DRY-RUN] Would configure remaining settings for devuser1
[INFO] User reconciliation completed
```

Dry-run mode shows what the script would change without actually modifying the system.

This provides an important safety layer before user, sudo, SSH, or offboarding changes are applied.

---

## User Creation

To apply the desired state:

```bash
sudo /opt/devopsshack/bin/user-manager.sh
```

Example output:

```text
[INFO] Checking user: devuser1
[CHANGE] Creating user devuser1
[CHANGE] Adding devuser1 to group developers
[OK] Shell already correct for devuser1
[CHANGE] SSH key installed for devuser1
```

The script can configure:

* User account
* Home directory
* Login shell
* Linux groups
* Sudo access
* SSH public key
* Account expiry

---

## User Verification

The created Linux user can be verified using:

```bash
id devuser1
```

Example:

```text
uid=1001(devuser1) gid=1004(devuser1) groups=1004(devuser1),1001(developers)
```

Check group membership:

```bash
id -nG devuser1
```

Example:

```text
devuser1 developers
```

Check account information:

```bash
getent passwd devuser1
```

Example:

```text
devuser1:x:1001:1004:Dev User One:/home/devuser1:/bin/bash
```

---

## Idempotence

The script is designed to be idempotent.

This means running the script multiple times does not create duplicate users or make unnecessary changes.

Example second run:

```text
[INFO] Checking user: devuser1
[OK] User devuser1 already exists
[OK] devuser1 already belongs to developers
[OK] Shell already correct for devuser1
[OK] devuser1 already has sudo access
[OK] Account expiry already correct for devuser1
[OK] SSH key already correct for devuser1
```

The desired state is already correct, so no additional changes are required.

This is the same general automation concept used by tools such as:

* Ansible
* Terraform
* Kubernetes

---

## SSH Public Key Management

The script installs the user's SSH public key into:

```text
/home/<username>/.ssh/authorized_keys
```

For example:

```text
/home/devuser1/.ssh/authorized_keys
```

The script also applies secure permissions.

```text
.ssh directory       -> 700
authorized_keys      -> 600
```

Verification:

```bash
sudo ls -ld /home/devuser1/.ssh
```

Example:

```text
drwx------. 2 devuser1 devuser1 /home/devuser1/.ssh
```

Check the authorized key:

```bash
sudo ls -l /home/devuser1/.ssh/authorized_keys
```

Example:

```text
-rw-------. 1 devuser1 devuser1 authorized_keys
```

Correct ownership and permissions are important because SSH authentication can fail when `.ssh` or `authorized_keys` permissions are too open.

Private SSH keys are never stored in this Git repository.

---

## Sudo Access Management

On Amazon Linux, privileged access is commonly controlled using the `wheel` group.

Initially, a user can be configured without sudo:

```csv
devuser1,Dev User One,developers,/bin/bash,no,never,/opt/devopsshack/conf/keys/devuser1.pub
```

To grant sudo access, update:

```text
sudo=no
```

to:

```text
sudo=yes
```

Then run:

```bash
sudo /opt/devopsshack/bin/user-manager.sh --dry-run
```

Example:

```text
[DRY-RUN] Granting sudo access to devuser1 using wheel
```

Apply the real change:

```bash
sudo /opt/devopsshack/bin/user-manager.sh
```

Example:

```text
[CHANGE] Granting sudo access to devuser1 using wheel
```

Verify:

```bash
id -nG devuser1
```

Example:

```text
devuser1 wheel developers
```

This demonstrates desired-state access management instead of manually changing privileges.

---

## Account Expiry

The project supports account expiry using `chage`.

Example CSV value:

```text
2026-12-31
```

After reconciliation:

```bash
sudo chage -l devuser1
```

Example:

```text
Account expires : Dec 31, 2026
```

The script also checks whether the expiry is already correct.

Example repeat execution:

```text
[OK] Account expiry already correct for devuser1
```

This prevents unnecessary changes on future runs.

---

## Safe User Offboarding

When a user is no longer present in the desired-state CSV file, the script can safely offboard the account.

The script does not immediately delete the Linux user.

Instead, the offboarding flow is:

```text
User removed from desired state
          |
          v
Archive home directory
          |
          v
Terminate active sessions
          |
          v
Lock account
          |
          v
Expire account
          |
          v
Remove privileged access
          |
          v
Write audit log
```

This approach preserves user data and provides safer access removal.

---

## Offboarding Test

A test account was created:

```bash
sudo useradd -m olduser1
```

Because `olduser1` was not present in `users.csv`, the dry-run detected it:

```text
[WARNING] User olduser1 is not present in desired state
[DRY-RUN] Would offboard user olduser1
```

After the real run:

```text
[CHANGE] Archived home directory for olduser1
[CHANGE] Offboarded user olduser1
```

---

## Account Lock Verification

The offboarded account status can be checked with:

```bash
sudo passwd -S olduser1
```

Example:

```text
olduser1 LK 2026-09-06 0 99999 7 -1 (Password locked.)
```

`LK` indicates that the account password is locked.

---

## Account Expiry Verification

Check:

```bash
sudo chage -l olduser1
```

Example:

```text
Account expires : Jan 01, 1970
```

This shows that the account has been expired.

---

## Home Directory Backup

Before offboarding, the user's home directory is archived.

Backup location:

```text
/opt/devopsshack/backups/offboarded-users/
```

Example:

```text
olduser1-20260906-053446.tar.gz
```

The backup file is protected with restrictive permissions.

Example:

```text
-rw------- root root olduser1-20260906-053446.tar.gz
```

This protects user data while still allowing administrators to recover it if required.

---

## Idempotent Offboarding

Offboarding is also designed to be idempotent.

When the script detects that the account is already locked and expired, it does not archive or offboard the same user again.

Example:

```text
[WARNING] User olduser1 is not present in desired state
[OK] olduser1 already offboarded
```

This prevents:

* Duplicate archives
* Repeated destructive actions
* Unnecessary account changes

---

## System Account Protection

During testing, an important edge case was discovered.

The initial logic considered accounts with UID greater than or equal to 1000 as normal users.

However, the special Linux account:

```text
nobody
```

uses a high UID on the test system.

Because of this, UID-only filtering was not sufficient.

Additional safety checks were added.

The script now protects:

* Accounts with UID below 1000
* High-UID special accounts
* The AWS `ec2-user` account
* Accounts whose home directory is not under `/home`

Example safety logic:

```bash
[[ "$uid" -lt 1000 ]] && continue
[[ "$uid" -ge 60000 ]] && continue
[[ "$existing_user" == "ec2-user" ]] && continue
[[ "$home" != /home/* ]] && continue
```

This prevents system or special accounts from being accidentally offboarded.

---

## Real Troubleshooting Scenario

During testing, the original offboarding logic detected:

```text
[WARNING] User nobody is not present in desired state
```

The script then started creating a backup for that account.

Because the special `nobody` account was not intended to be managed, execution was stopped and the filtering logic was improved.

After the fix, dry-run correctly detected only:

```text
[WARNING] User olduser1 is not present in desired state
[DRY-RUN] Would offboard user olduser1
```

This was an important lesson in defensive Linux automation.

A UID value alone should not be used as the only condition before destructive operations.

---

## Audit Logging

Every important action is written to:

```text
/opt/devopsshack/logs/user-management-audit.log
```

Example entries:

```text
[CHANGE] Creating user devuser1
[CHANGE] Adding devuser1 to group developers
[CHANGE] SSH key installed for devuser1
[CHANGE] Granting sudo access to devuser1 using wheel
[CHANGE] Archived home directory for olduser1
[CHANGE] Offboarded user olduser1
```

Audit logs provide useful information for:

* Troubleshooting
* Security investigation
* Change tracking
* Compliance
* Operational review

---

## Important Commands Used

### User Management

```bash
useradd
usermod
id
getent
```

### Group Management

```bash
groupadd
gpasswd
```

### Account Security

```bash
passwd
chage
```

### SSH

```bash
ssh-keygen
chmod
chown
```

### Session Management

```bash
pkill
```

### Backup

```bash
tar
```

### Validation

```bash
bash -n
```

---

## Testing Performed

The following tests were completed:

### Test 1 - Dry-Run User Creation

```bash
sudo /opt/devopsshack/bin/user-manager.sh --dry-run
```

Confirmed that no actual user was created.

---

### Test 2 - User Creation

```bash
sudo /opt/devopsshack/bin/user-manager.sh
```

Confirmed that `devuser1` was successfully created.

---

### Test 3 - Group Membership

```bash
id -nG devuser1
```

Confirmed:

```text
devuser1 developers
```

---

### Test 4 - SSH Key Deployment

Verified:

```text
/home/devuser1/.ssh
/home/devuser1/.ssh/authorized_keys
```

Permissions confirmed:

```text
700 - .ssh
600 - authorized_keys
```

---

### Test 5 - Idempotent Second Run

The script was executed again.

Result:

```text
[OK] User devuser1 already exists
[OK] devuser1 already belongs to developers
[OK] Shell already correct for devuser1
[OK] SSH key already correct for devuser1
```

No duplicate changes were made.

---

### Test 6 - Sudo Reconciliation

Changed:

```text
sudo=no
```

to:

```text
sudo=yes
```

The script detected the change and added the user to:

```text
wheel
```

---

### Test 7 - Account Expiry

Configured:

```text
2026-12-31
```

Verified using:

```bash
sudo chage -l devuser1
```

---

### Test 8 - Safe Offboarding

Created test user:

```text
olduser1
```

Removed it from the desired state and confirmed:

* Home directory archived
* Account locked
* Account expired
* Audit event recorded

---

### Test 9 - Offboarding Idempotence

Ran the script again after offboarding.

Result:

```text
[OK] olduser1 already offboarded
```

No additional backup or destructive operation was performed.

---

### Test 10 - System Account Protection

Detected a high-UID system account during testing and improved the safety logic so special users such as `nobody` are excluded from offboarding.

---

## Git Security

The `.gitignore` prevents sensitive or unnecessary files from being committed.

Example:

```gitignore
*.pem
id_rsa
id_rsa.pub
id_ed25519
id_ed25519.pub
*-test-key
*.tar.gz
```

Private SSH keys and home-directory backup archives must never be committed to GitHub.

---

## Git Commit

Project commit:

```text
Add Project 3 automated user management system
```

The project is maintained inside:

```text
linux-automation-toolkit
```

under:

```text
project-03-automated-user-management/
```

---

## Key Learning

This project demonstrated that production Linux user management is more than running:

```bash
useradd
```

Important concepts learned include:

* Desired-state management
* Declarative automation
* Idempotence
* Linux user lifecycle management
* Group management
* Privilege management
* SSH security
* Account expiration
* Safe offboarding
* Home-directory backup
* Auditability
* Defensive scripting
* System-account protection
* Dry-run validation

These concepts are closely related to configuration-management and infrastructure-automation tools such as Ansible, Terraform, and Kubernetes.

---

## Real-World Use Case

In a real organization, this type of automation can support:

```text
New employee joins
        |
        v
Create account
Assign required groups
Install SSH key
Configure access
```

For an existing employee:

```text
Role changes
     |
     v
Update CSV
     |
     v
Run reconciliation
     |
     v
Required access automatically updated
```

For an employee leaving the organization:

```text
Employee leaves
      |
      v
Remove from desired state
      |
      v
Account locked
Sessions terminated
Privileged access revoked
Home directory archived
Audit entry created
```

---

## Interview Explanation

I built an automated Linux user-management system using Bash.

The required users are defined in a CSV file as the desired state, and the script reconciles the Linux server with that configuration.

It manages user creation, Linux groups, login shells, sudo access, SSH public keys, and account expiry.

The script is idempotent, so repeated executions do not make unnecessary changes.

For offboarding, I do not immediately delete the user. The script archives the home directory, terminates active sessions, locks and expires the account, removes privileged access, and records the action in an audit log.

I also implemented dry-run functionality and system-account protection.

During testing, I found that the `nobody` account had a high UID, so using only UID greater than or equal to 1000 was unsafe. I improved the logic by adding multiple safety checks before any offboarding operation.

---

## Status

Project 03 - Completed
