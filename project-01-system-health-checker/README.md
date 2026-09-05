# Project 01 - Automated System Health Checker

## Overview

This project is a Bash-based Linux system health monitoring script.

The script checks important system resources such as CPU, memory, swap, disk usage, inode usage, load average, uptime, and top resource-consuming processes.

It uses configurable thresholds to classify each check as:

- OK
- WARNING
- CRITICAL

The script also generates logs and returns meaningful exit codes so that it can be integrated with cron jobs, monitoring systems, or automation pipelines.

## Features

- CPU utilization monitoring
- Memory utilization monitoring
- Swap utilization monitoring
- Root filesystem disk usage monitoring
- Inode usage monitoring
- Load average per CPU core
- Server uptime and boot time
- Top CPU-consuming processes
- Top memory-consuming processes
- Configurable thresholds
- Overall server health status
- Log file generation
- Linux exit codes
- Cron automation

## Project Structure

```text
project-01-system-health-checker/
├── bin/
│   └── health-check.sh
├── conf/
│   └── health.conf
├── sample-output/
│   └── health-check-output.txt
├── screenshots/
└── README.md
```

## Runtime Location

The script is installed and executed from:

`/opt/devopsshack/bin/health-check.sh`

Configuration file:

`/opt/devopsshack/conf/health.conf`

Log file:

`/opt/devopsshack/logs/health-check.log`

## Configuration

The health check uses configurable thresholds:

- CPU Warning: 75%
- CPU Critical: 90%
- Memory Warning: 80%
- Memory Critical: 92%
- Swap Warning: 20%
- Swap Critical: 50%
- Disk Warning: 80%
- Disk Critical: 90%
- Inode Warning: 80%
- Inode Critical: 90%
- Load Warning: 1.5 per core
- Load Critical: 2.5 per core
- Top Processes: 5

## Run the Script

Run:

`/opt/devopsshack/bin/health-check.sh`

Check the exit code:

`echo $?`

Exit codes:

- 0 = OK
- 1 = WARNING
- 2 = CRITICAL

## Cron Automation

The health check is configured to run automatically every 5 minutes.

Cron schedule:

`*/5 * * * * /opt/devopsshack/bin/health-check.sh >/dev/null 2>&1`

## Testing

The script was tested for all three health states:

- OK = Exit Code 0
- WARNING = Exit Code 1
- CRITICAL = Exit Code 2

Threshold values were temporarily modified to safely simulate OK and CRITICAL conditions without intentionally overloading the server.

## Environment

- AWS EC2
- Amazon Linux 2023
- Bash
- Cronie / crond

## Learning Outcome

This project demonstrates how Bash scripting can automate Linux server health monitoring.

It collects system metrics, compares them against configurable thresholds, generates logs, identifies resource-consuming processes, returns meaningful exit codes, and runs automatically using cron.

