# Project 08 - Automated Server Provisioning

## Overview

Project 08 is a Bash-based Linux server provisioning automation project.
The script assesses the server, validates required components, provisions the required baseline configuration, performs final validation, and generates an audit report.

## Problem Statement

Manual Linux server setup can be time-consuming and inconsistent.
This project automates operating system checks, command validation, directory provisioning, group management, service validation, NTP validation, logging, reporting, and final health checks.

## Workflow

1. Preflight server assessment
2. Configuration loading
3. Directory provisioning
4. Required command validation
5. User and group management
6. Service management
7. NTP validation
8. Final validation
9. Logging
10. Provisioning report generation
11. PASS or FAIL exit status

## Environment

- AWS EC2
- Amazon Linux 2023
- Bash
- DNF
- systemd
- Docker
- chronyd
- crond

## Repository Structure

project-08-server-provisioning/
  README.md
  bin/server-provision.sh
  conf/provisioning.conf
  sample-output/
  screenshots/

## Runtime Structure

Project 08 uses an isolated runtime directory so existing Project 01-07 data is protected.

/opt/devopsshack/project-08/
  bin/
  conf/
  logs/provisioning.log
  state/
  reports/project-08-provisioning-report.txt

## Configuration

Configuration file: conf/provisioning.conf

Important settings:

TIMEZONE=UTC
HOSTNAME_MANAGED=false
UPDATE_PACKAGES=false
ADMIN_GROUP=devops
PROVISION_USER=empty
RUNTIME_ROOT=/opt/devopsshack/project-08
ENABLE_CHRONYD=true
ENABLE_CROND=true
ENABLE_DOCKER=true
VALIDATE_AFTER_PROVISION=true

## Required Commands

The script validates availability of:

git, curl, wget, vim, tree, unzip, rsync, jq, bc, lsof, strace, tcpdump, iostat.

Existing command availability is checked before attempting package installation.

## Usage

Normal provisioning:

./bin/server-provision.sh

Dry run:

./bin/server-provision.sh --dry-run

Custom configuration:

./bin/server-provision.sh --config conf/provisioning.conf

Help:

./bin/server-provision.sh --help

## Idempotence

The script is designed to be idempotent.
Running it repeatedly against an already configured server does not unnecessarily recreate resources.

Examples:

- Existing directories are reused.
- Existing commands are detected.
- Existing groups are reused.
- Active services are not unnecessarily restarted.
- Enabled services are not unnecessarily re-enabled.

## Permission Drift Detection

A controlled drift test was performed on the Project 08 state directory.
The directory permission was changed from 750 to 777.
The provisioning script detected the drift and corrected the permission back to 750.
Final validation passed.

## Logging

Provisioning activity is recorded in:

/opt/devopsshack/project-08/logs/provisioning.log

Logging provides an audit trail of provisioning and validation activity.

## Provisioning Report

The final report is generated at:

/opt/devopsshack/project-08/reports/project-08-provisioning-report.txt

The successful report contains zero validation failures and a PASS result.

## Validation

The script validates:

- Operating system
- Required commands
- Required directories
- Directory permissions
- Administrative group
- Required services
- NTP synchronization
- Report generation

## Testing Completed

Preflight assessment: PASS
Dry run: PASS
Initial provisioning: PASS
Logging: PASS
Report generation: PASS
Permission drift correction: PASS
Idempotence test: PASS
Final validation: PASS

## Exit Codes

0 - Success
2 - Invalid usage
3 - Prerequisite failure
4 - Configuration failure
5 - Provisioning failure
6 - Validation failure

## Safety Considerations

- Existing users were not removed.
- Existing Project 01-07 data was not deleted.
- SSH configuration was not modified.
- Firewall changes were not performed blindly.
- Existing services were not unnecessarily restarted.
- Package updates are disabled by default.
- Project 08 runtime is isolated.
- Dry-run mode is available.
- No credentials or private keys are stored in the repository.

## Shell Syntax Validation

ShellCheck was not available in the enabled Amazon Linux 2023 repositories during testing.
Shell syntax was validated successfully using bash -n.

## What I Learned

- Bash automation
- Linux server provisioning
- Configuration-driven automation
- Idempotence
- Permission management
- Service validation
- Logging and reporting
- Error handling
- Exit codes
- Dry-run design
- Configuration drift detection
- AWS EC2 Linux administration

## Interview Explanation

In Project 8, I built a Bash-based automated Linux server provisioning script. It checks the server state, loads configuration, validates required commands, provisions directories, manages the administrative group, validates services such as Docker, chronyd and crond, and checks NTP synchronization. I also implemented dry-run mode, idempotence, permission drift correction, logging and a provisioning report. I tested the solution on Amazon Linux 2023 running on AWS EC2.

## Status

Project 08 - Automated Server Provisioning: COMPLETE

Core provisioning, validation, idempotence, drift correction, logging and reporting have been tested successfully.
