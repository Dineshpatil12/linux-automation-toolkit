# Project 02 - Disk Usage Alerting Script

## Overview

This project implements a Bash-based disk monitoring and alerting solution on an AWS EC2 Linux server.

The script monitors filesystem disk usage and inode utilization using configurable WARNING and CRITICAL thresholds. It also prevents duplicate alerts, supports escalation, tracks disk growth, collects troubleshooting evidence, and generates a RECOVERED notification when the filesystem returns to normal.

## Objective

The goal of this project is to detect disk problems automatically before the filesystem becomes completely full.

The script performs the following tasks:

- Checks disk usage
- Checks inode usage
- Generates WARNING and CRITICAL alerts
- Prevents duplicate alerts
- Uses a cooldown period
- Escalates WARNING to CRITICAL immediately
- Tracks disk growth
- Finds large directories and files
- Checks deleted-but-open files
- Generates recovery notifications
- Runs automatically using cron

## Project Structure

project-02-disk-usage-alerting/
├── README.md
├── bin/
│   └── disk-alert.sh
├── conf/
│   └── disk-alert.conf
├── sample-output/
│   └── alert-tests.txt
└── screenshots/

## Runtime Structure

/opt/devopsshack/
├── bin/disk-alert.sh
├── conf/disk-alert.conf
├── logs/disk-alert.log
├── logs/disk-alert-cron.log
└── state/
    ├── root.alert
    └── root.history

## Thresholds

Default disk thresholds:

- WARNING: 80%
- CRITICAL: 90%

Default inode thresholds:

- WARNING: 80%
- CRITICAL: 90%

Cooldown period:

- 60 minutes

## Alert Flow

NORMAL -> WARNING -> CRITICAL -> RECOVERED

When the filesystem first reaches the warning threshold, a WARNING alert is generated.

If the same WARNING condition continues during the cooldown period, duplicate alerts are suppressed.

If the filesystem changes from WARNING to CRITICAL, the script immediately generates a CRITICAL alert even if the cooldown period is still active.

When utilization returns below the warning threshold, the script generates a RECOVERED notification and removes the active alert state.

## Stateful Alerting

The script stores alert information inside /opt/devopsshack/state/.

The root.alert file stores the previous alert severity and timestamp.

The root.history file stores previous disk usage information for calculating disk growth.

This state information prevents repeated alerts every time cron executes the script.

## Disk Growth Tracking

The script compares the current disk usage with the previous disk usage.

Formula:

Disk Growth = Current Usage - Previous Usage

Growth Rate = Disk Growth / Time

This helps identify whether disk consumption is increasing slowly or rapidly.

## Troubleshooting Evidence

During a WARNING or CRITICAL condition, the script collects useful troubleshooting information.

It checks:

- Largest directories
- Largest files
- Deleted-but-open files
- Current disk utilization
- Current inode utilization
- Disk growth rate

Useful Linux commands used in this project:

df -h
df -i
du -xh --max-depth=1 /
find / -xdev -type f
sudo lsof +L1
sudo docker system df

## Testing Completed

The following scenarios were successfully tested:

- WARNING alert - PASS
- Duplicate WARNING suppression - PASS
- WARNING to CRITICAL escalation - PASS
- Recovery notification - PASS
- Disk growth tracking - PASS
- Largest directory detection - PASS
- Largest file detection - PASS
- Deleted-but-open file detection - PASS

During testing, the EC2 root filesystem was already approximately 89% utilized.

Instead of filling the real filesystem further, thresholds were temporarily changed to safely test CRITICAL escalation and RECOVERY behavior.

## Example Test Results

WARNING:

Filesystem: /
Disk Usage: 89%
Disk Warning: 80%
Disk Critical: 90%
Inode Usage: 5%
Reason: First WARNING alert

Duplicate suppression:

[SUPPRESSED] / WARNING alert suppressed. Disk=89% Inode=5%

Critical escalation:

[CRITICAL] / Disk=89% Inode=5% - Escalated from WARNING to CRITICAL

Recovery:

[RECOVERED] / recovered. Disk=89% Inode=5%

## Docker Disk Observation

Docker disk usage was also checked during troubleshooting.

Observed usage included approximately:

- Docker Images: 4.122 GB
- Containers: 307.7 MB
- Local Volumes: 5.229 MB

This demonstrated how Docker images and containers can consume significant space on a Linux server.

## Cron Automation

The disk monitoring script runs automatically every 5 minutes.

Cron entry:

*/5 * * * * /opt/devopsshack/bin/disk-alert.sh >> /opt/devopsshack/logs/disk-alert-cron.log 2>&1

Project 1 health monitoring also runs every 5 minutes.

## Real-Time Use Case

In production, disk usage may increase because of:

- Application logs
- Docker images and container logs
- Database files
- Jenkins workspace files
- Backup files
- Temporary files
- Core dumps
- Failed log rotation

Example:

11:00 - Disk usage is 75% - NORMAL

12:00 - Disk usage reaches 82% - WARNING generated

12:15 - Disk usage reaches 91% - CRITICAL generated

Engineer investigates the server and discovers a large application log caused by failed log rotation.

After cleanup and fixing log rotation:

12:30 - Disk usage returns to 55% - RECOVERED generated

## What I Learned

Through this project I learned:

- Linux disk monitoring
- Inode monitoring
- Bash scripting
- Threshold-based alerting
- Persistent state management
- Duplicate alert suppression
- Cooldown logic
- Alert escalation
- Recovery detection
- Disk growth calculation
- Disk troubleshooting using df, du, find, and lsof
- Docker disk investigation
- Cron automation
- Production monitoring concepts

## Interview Explanation

I developed a Bash-based disk monitoring and alerting solution on an AWS EC2 Linux server.

The script monitors filesystem disk usage and inode utilization using configurable warning and critical thresholds.

I implemented persistent state files and cooldown logic to prevent duplicate alerts. If the filesystem changes from warning to critical, the script immediately escalates the alert even during the cooldown period.

When disk utilization returns to normal, the script generates a recovery notification.

The script also tracks disk growth and collects troubleshooting information such as largest directories, largest files, and deleted-but-open files.

Finally, I automated the script using cron to run every five minutes.

## Status

Project 02 - Completed
