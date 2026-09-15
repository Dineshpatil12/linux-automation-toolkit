# Project 09 - Linux Troubleshooting Toolkit

## Overview

A production-oriented Linux troubleshooting toolkit that collects system health, resource usage, process information, network state, logs, and service status into timestamped diagnostic reports.

## Project Structure

```text
project-09-troubleshooting-toolkit/
├── README.md
├── bin/
│   └── troubleshoot.sh
├── conf/
│   └── troubleshooting.conf
├── sample-output/
└── screenshots/
```

## Status

Project 09 - Linux Troubleshooting Toolkit

## Problem Statement

When a Linux server has performance, availability, or resource issues, engineers
need a fast and repeatable way to collect evidence before troubleshooting the
root cause.

This toolkit automates the initial troubleshooting and evidence-collection
process so that engineers can quickly understand the current state of a server.

## Objectives

- Perform structured Linux system triage.
- Collect CPU, load, memory, and swap information.
- Check disk space and inode utilization.
- Collect disk I/O statistics.
- Identify CPU- and memory-intensive processes.
- Inspect network interfaces, routes, and listening ports.
- Collect system and application logs.
- Check failed services and system state.
- Continue safely when optional diagnostic commands are unavailable.
- Generate timestamped troubleshooting reports.

## Troubleshooting Workflow

The toolkit follows a structured troubleshooting workflow:

1. Establish the server baseline using hostname and uptime.
2. Check CPU utilization and load average.
3. Check memory and swap pressure.
4. Check filesystem space and inode utilization.
5. Check disk I/O activity.
6. Identify high CPU and memory consuming processes.
7. Check network interfaces, routes, and listening ports.
8. Review system warnings and errors from logs.
9. Check system state and failed services.
10. Record warnings and diagnostic failures in the final report.
11. Use the collected evidence to narrow down the possible root cause.

The goal is to collect evidence first and make changes only after understanding
the problem.

## Diagnostic Sections

The generated report contains the following sections:

- CPU
- Load Average
- Memory and Swap
- Uptime
- Disk and Inodes
- Disk I/O
- Processes
- Network
- Logs
- System and Service State
- Warnings / Errors
- Collection Summary

## Prerequisites

- Linux server with Bash.
- Access to `/proc`.
- Standard Linux diagnostic utilities.
- Optional tools such as `iostat`, `journalctl`, and `ss` are used when available.
- Permission to write reports under `/opt/devopsshack/reports`.

## Installation

Clone the repository and enter the project directory:

```bash
cd linux-automation-toolkit
```

Create the runtime directories:

```bash
sudo mkdir -p /opt/devopsshack/bin /opt/devopsshack/conf /opt/devopsshack/reports
```

Make the troubleshooting script executable:

```bash
chmod +x project-09-troubleshooting-toolkit/bin/troubleshoot.sh
```

## Configuration

Configuration is stored in `project-09-troubleshooting-toolkit/conf/troubleshooting.conf`.

Important settings include report location, report prefix, process limits, log lines,
disk warning threshold, diagnostic collection controls, and optional application logs.

## Usage

Run all diagnostics:

```bash
./project-09-troubleshooting-toolkit/bin/troubleshoot.sh all
```

Display help:

```bash
./project-09-troubleshooting-toolkit/bin/troubleshoot.sh --help
```

Reports are generated under `/opt/devopsshack/reports/`.

Example report filename:

```text
troubleshooting_YYYYMMDD_HHMMSS.txt
```

## Report Architecture

Each execution creates a timestamped report containing structured diagnostic sections. The report is designed to provide a quick snapshot of the server state for troubleshooting and evidence collection.

The toolkit separates data collection from remediation. It does not automatically kill processes, modify firewall rules, change SSH configuration, or delete files.

## Failure Handling

Diagnostic commands are treated as optional where possible. Before using an optional command, the toolkit checks whether it is available.

If a diagnostic command fails or access is restricted, the toolkit records a warning in the report and continues with the remaining diagnostics.

For example, `dmesg` may be restricted for a non-root user. In that case, the toolkit records the restriction instead of terminating the complete troubleshooting run.

## Safety Controls

- No production processes are killed by the toolkit.
- No SSH configuration is modified.
- No firewall configuration is modified.
- No large test files are created on the root filesystem.
- No automatic remediation actions are performed.
- Diagnostic failures do not stop the complete report collection.

## Testing

The toolkit was validated using safe synthetic tests on the lab EC2 server.

### Functional Tests

- Normal diagnostic collection and report generation.
- CPU observation using a temporary bounded CPU workload.
- Memory observation using a temporary bounded memory workload.
- Process detection using a temporary `sleep` process.
- Synthetic application log collection using a temporary log file.
- Missing `iostat` simulation to verify graceful failure handling.
- Network and listening-port diagnostics using the local server state.
- Bash syntax validation using `bash -n`.
- ShellCheck validation using ShellCheck 0.11.0.

### Graceful Failure Test

A temporary `iostat` command was used to simulate an unavailable or failed diagnostic dependency. The toolkit recorded the failure and continued collecting process, network, log, and system information.

### Cleanup

All synthetic test processes, temporary logs, and temporary test directories were removed after testing.

## ShellCheck Result

ShellCheck 0.11.0 was used to validate `bin/troubleshoot.sh`. The script passes ShellCheck with no findings.

## Interview Explanation

I built a Linux Troubleshooting Toolkit to automate the initial production troubleshooting process.

First I check the server baseline, CPU, load, memory, and disk usage. Then I check disk I/O and identify high CPU or memory consuming processes. After that I verify network interfaces, routes, and listening ports. I review system logs and failed services to collect additional evidence.

If an optional diagnostic command is unavailable or fails, the toolkit records a warning and continues with the remaining checks. This prevents one failed diagnostic from stopping the complete troubleshooting report.

I use the collected evidence to narrow down the possible root cause before taking any remediation action. After remediation, I would run the toolkit again to verify the server state.

This project is a hands-on lab implementation of a production troubleshooting workflow.

## What I Learned

- Structured Linux troubleshooting and evidence collection.
- CPU, memory, disk, I/O, process, and network diagnostics.
- Bash scripting with defensive error handling.
- Graceful handling of missing or restricted diagnostic commands.
- Timestamped report generation.
- Safe troubleshooting without automatic remediation.
- ShellCheck-based Bash quality validation.

## Project Status

**Completed - Project 09: Linux Troubleshooting Toolkit**
