# Project 3 - Automated User Management System

## Overview

This project automates the Linux user lifecycle using Bash.

Instead of manually creating, modifying, and disabling Linux users, the script reads the required user configuration from a CSV file and reconciles the Linux server with that desired state.

The project demonstrates:

- Declarative user management
- Idempotent automation
- Linux user and group management
- SSH public key management
- Sudo access management
- Account expiry
- Safe user offboarding
- Home directory archival
- Audit logging
- Dry-run safety

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
   +--> Manage shell
   +--> Manage sudo access
   +--> Configure SSH public keys
   +--> Configure account expiry
   +--> Identify unmanaged users
   +--> Safely offboard users
   +--> Archive home directories
   +--> Write audit logs
