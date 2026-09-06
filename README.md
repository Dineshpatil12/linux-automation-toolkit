# Linux Automation Toolkit

This repository contains 10 hands-on Linux automation projects built using Bash scripting and Linux administration concepts.

The projects are implemented practically on AWS EC2 using Amazon Linux.

The goal of this repository is to build practical experience in Linux administration, monitoring, troubleshooting, security, automation, backup, and service recovery.

---

## Projects

| No. | Project | Status |
|---|---|---|
| 01 | Automated System Health Checker | Completed |
| 02 | Disk Usage Alerting Script | Completed |
| 03 | Automated User Management System | Completed |
| 04 | Linux Server Hardening | Completed |
| 05 | Backup and Restore System | Upcoming |
| 06 | Log Analysis and Reporting | Upcoming |
| 07 | Application Watchdog | Upcoming |
| 08 | Automated Server Provisioning | Upcoming |
| 09 | Linux Troubleshooting Toolkit | Upcoming |
| 10 | Self-Healing Linux Application with systemd | Upcoming |

---

## Project 01 - Automated System Health Checker

Project 01 implements an automated Linux system health checker for monitoring the health and resource utilization of a Linux server.

The script monitors:

- CPU utilization
- Memory utilization
- Swap utilization
- Disk usage
- Inode usage
- Load average
- System uptime
- Top CPU-consuming processes
- Top memory-consuming processes

Additional features:

- Configurable warning and critical thresholds
- Centralized logging
- Meaningful exit codes
- Cron-based automation
- Human-readable health reports

### Status

Completed

---

## Project 02 - Disk Usage Alerting Script

Project 02 implements automated disk usage monitoring and alerting.

The script monitors filesystem utilization and generates alerts when configured warning or critical thresholds are exceeded.

The project includes:

- Disk utilization monitoring
- Inode monitoring
- Configurable warning and critical thresholds
- Stateful alert management
- Alert cooldown
- Duplicate alert suppression
- Warning-to-critical escalation
- Recovery notifications
- Disk growth tracking
- Largest directory analysis
- Largest file analysis
- Deleted-but-open file detection
- Troubleshooting information collection
- Cron-based automation
- Logging

### Status

Completed

---

## Project 03 - Automated User Management System

Project 03 automates the Linux user lifecycle using Bash and a declarative CSV-based configuration.

Instead of manually creating, modifying, and disabling Linux users, the script reads the required user configuration from a CSV file and reconciles the Linux server with the desired state.

The project includes:

- Declarative user management
- Automated user creation
- Linux group management
- SSH public key management
- Sudo access management
- User shell management
- Account expiry management
- Password ageing policies
- Idempotent user reconciliation
- Dry-run safety
- Safe user offboarding
- Home directory archival
- Audit logging

### Status

Completed

---

## Project 04 - Linux Server Hardening

Project 04 implements automated Linux server security hardening using Bash.

The project includes:

- SSH security hardening
- Firewall configuration
- User and account security checks
- Secure file and directory permissions
- Unnecessary service detection
- Security configuration validation
- Configuration backups before changes
- Safe SSH configuration testing
- Firewall verification
- Security audit reporting
- Logging and verification

### Status

Completed

---

## Project 05 - Backup and Restore System

This project will implement automated backup, retention, verification, and restore operations.

### Status

Upcoming

---

## Project 06 - Log Analysis and Reporting

This project will automate Linux log analysis to identify errors, failures, unusual activity, and useful troubleshooting information.

### Status

Upcoming

---

## Project 07 - Application Watchdog

This project will monitor application health, detect failures, collect diagnostic information, and perform controlled recovery actions.

### Status

Upcoming

---

## Project 08 - Automated Server Provisioning

This project will automate the configuration of a new Linux server and create a repeatable server provisioning process.

### Status

Upcoming

---

## Project 09 - Linux Troubleshooting Toolkit

This project will provide a repeatable Linux troubleshooting toolkit for collecting CPU, memory, disk, I/O, process, network, and system diagnostic information.

### Status

Upcoming

---

## Project 10 - Self-Healing Linux Application with systemd

This project will implement a self-healing Linux application using systemd service supervision, health checks, restart policies, watchdogs, resource limits, and automated recovery.

### Status

Upcoming

---

## Environment

The projects are built and tested using:

- AWS EC2
- Amazon Linux
- Bash
- Linux system utilities
- Cron
- systemd
- Git
- GitHub

---

## Repository Structure

```text
linux-automation-toolkit/
├── README.md
├── project-01-system-health-checker/
├── project-02-disk-usage-alerting/
├── project-03-automated-user-management/
├── project-04-server-hardening/
├── project-05-backup-restore/
├── project-06-log-analysis/
├── project-07-application-watchdog/
├── project-08-server-provisioning/
├── project-09-troubleshooting-toolkit/
└── project-10-self-healing-systemd/
```

Each completed project contains its own documentation, Bash scripts, configuration files, sample output, and testing evidence.

---

## Key Concepts Covered

The projects gradually build practical Linux and DevOps automation skills, including:

- Linux system monitoring
- Bash scripting
- Shell scripting best practices
- Configuration management
- Logging and exit codes
- Threshold-based monitoring
- Stateful alerting
- Idempotent automation
- Linux user and group management
- SSH access management
- Sudo privilege management
- Account lifecycle management
- Linux security hardening
- Backup and recovery
- Log analysis
- Application monitoring
- Server provisioning
- Production troubleshooting
- systemd service management
- Automated recovery
- Self-healing services

---

## Learning Path

The projects follow a progressive learning path:

```text
System Health Monitoring
        ↓
Disk Usage Alerting
        ↓
User Management
        ↓
Server Hardening
        ↓
Backup and Restore
        ↓
Log Analysis
        ↓
Application Watchdog
        ↓
Server Provisioning
        ↓
Linux Troubleshooting
        ↓
Self-Healing Services
```

The objective is not only to practice individual Linux commands, but to understand how Linux administration tasks can be automated safely, consistently, and reliably in real-world environments.

---

## Objective

By completing these projects, the repository demonstrates practical experience with:

- Linux administration
- Bash automation
- Production monitoring
- Incident troubleshooting
- Security and access management
- Operational automation
- Backup and recovery
- Application reliability
- Git-based version control
- DevOps and Site Reliability Engineering concepts

The final goal is to build a reusable Linux automation toolkit while developing hands-on skills applicable to DevOps, Cloud, Linux Administration, Production Support, and Site Reliability Engineering roles.
