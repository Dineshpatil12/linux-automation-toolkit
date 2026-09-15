# Project 07 – Application Watchdog

## Overview

A production-style Bash application watchdog that monitors a local application, detects failures, collects diagnostic evidence before remediation, performs controlled recovery, verifies recovery, and prevents uncontrolled restart loops.

## Objective

The goal of this project is to build a reliable Linux application monitoring and recovery workflow using Bash.

The watchdog follows this sequence:

Application → Health Check → Failure Detection → Evidence Collection → Controlled Recovery → Recovery Verification → Retry/Backoff → Escalation

## Key Principle

**Collect diagnostic evidence before remediation.**

The watchdog does not blindly restart an unhealthy application before investigating the failure.

## Environment

- AWS EC2
- Amazon Linux 2023
- Bash
- Python 3
- curl
- cron
- Git

The demo application runs locally on `127.0.0.1:8080`.

Health endpoint: `http://127.0.0.1:8080/health`

## Features

- HTTP health checking
- Process verification
- Port verification
- Application log collection
- System diagnostic collection
- Controlled application recovery
- Recovery verification
- Retry mechanism
- Exponential backoff
- Failure tracking
- Circuit breaker protection
- Cooldown and half-open recovery
- Meaningful exit codes
- Cron automation
- Git-based project management

## Project Structure

```text
project-07-application-watchdog/
├── README.md
├── bin/
│   └── application-watchdog.sh
├── conf/
│   └── watchdog.conf
├── demo-app/
│   ├── app.py
│   └── README.md
├── sample-output/
└── screenshots/
```

## Runtime Structure

/opt/devopsshack/
├── bin/application-watchdog.sh
├── conf/watchdog.conf
├── logs/watchdog.log
├── logs/watchdog-cron.log
└── state/evidence_*.log

## Configuration

The configuration file is `conf/watchdog.conf`.

Important settings:

```bash
APP_NAME="demo-app"
APP_DIR="/opt/devopsshack/demo-app"
APP_SCRIPT="/opt/devopsshack/demo-app/app.py"
HEALTH_URL="http://127.0.0.1:8080/health"
HEALTH_TIMEOUT=5
MAX_RETRIES=3
INITIAL_BACKOFF=2
MAX_BACKOFF=30
MAX_FAILURES=3
FAILURE_WINDOW=300
COOLDOWN_PERIOD=300
```

## Failure Handling Workflow

1. Run the application health check.
2. If healthy, log the healthy state and exit successfully.
3. If unhealthy, collect diagnostic evidence.
4. Record the failure.
5. Check circuit-breaker state.
6. Perform controlled recovery when allowed.
7. Verify application health.
8. Retry with backoff if recovery fails.
9. Escalate when repeated failures reach the configured threshold.

## Evidence Collection

Before remediation, the watchdog collects process information, port information, recent application logs, system load, memory information, and recent system journal entries.

Evidence is stored under `/opt/devopsshack/state/`.

## Controlled Recovery

Recovery starts the application, confirms that the process remains running, waits for initialization, and verifies the health endpoint.

Recovery is successful only after HTTP 200 is confirmed.

## Retry and Backoff

The watchdog supports three recovery attempts by default.

The default retry delays are 2 seconds and 4 seconds, with a maximum configured backoff of 30 seconds.

## Circuit Breaker

The watchdog tracks repeated failures within a five-minute failure window.

After three recent failures, the circuit breaker opens and automatic recovery is suppressed.

This prevents uncontrolled restart loops and requires manual investigation.

## Cooldown and Half-Open Recovery

After the 300-second cooldown period expires, the watchdog allows a controlled half-open recovery attempt.

Successful recovery clears the failure and circuit-breaker state.

## Exit Codes

| Code | Meaning |
|---:|---|
| 0 | Application healthy or successfully recovered |
| 1 | Recovery failed |
| 2 | Configuration error |
| 3 | Circuit breaker escalation |

## Cron Automation

The watchdog runs every five minutes using cron:

```cron
*/5 * * * * /opt/devopsshack/bin/application-watchdog.sh >> /opt/devopsshack/logs/watchdog-cron.log 2>&1
```

Existing Project 1, Project 2, and Project 6 cron jobs were preserved.

## Testing Performed

### Healthy Application

Health check returned HTTP 200. The watchdog exited with code 0 and did not restart the healthy application.

### Application Failure and Recovery

The demo application was stopped. The watchdog detected the failure, collected evidence, started the application, and verified HTTP 200.

### Recovery Failure

The application script was temporarily disabled. The watchdog attempted recovery three times with backoff and returned exit code 1.

### Circuit Breaker

Repeated failures reached the configured threshold. Automatic recovery was suppressed and the watchdog returned exit code 3.

### Cooldown / Half-Open Recovery

After the cooldown period, the watchdog allowed controlled recovery and cleared the previous failure state after successful verification.

## Troubleshooting Commands

```bash
curl -i http://127.0.0.1:8080/health
pgrep -af 'python3 /opt/devopsshack/demo-app/app.py'
ss -lntp | grep ':8080 '
tail -20 /opt/devopsshack/demo-app/app.log
tail -20 /opt/devopsshack/logs/watchdog.log
ls -lt /opt/devopsshack/state/evidence_*.log
```

## Production Considerations

In a production environment this pattern can be integrated with systemd, Prometheus, Grafana, Zabbix, Nagios, Splunk, PagerDuty, centralized logging, and incident-management platforms.

The current project intentionally uses a local demo application for safe laboratory testing.

## Safety

The demo application listens only on 127.0.0.1:8080. The project does not modify SSH configuration, firewall rules, or important operating-system services.

## Interview Explanation

**One-line answer:** I built a Bash application watchdog that checks application health, collects evidence before remediation, performs controlled recovery with retry and backoff, verifies recovery, and uses a circuit breaker to prevent restart loops.

**Troubleshooting sequence:** First I check the health endpoint. Then I verify the process and listening port. Based on the error, I collect evidence before remediation. After fixing the issue, I verify recovery. If recovery repeatedly fails, I suppress automatic recovery and escalate.

## Learning Outcomes

- Linux application monitoring
- Bash scripting
- Process management
- HTTP health checks
- Evidence collection
- Automated remediation
- Retry and exponential backoff
- Circuit-breaker design
- Cron automation
- Production troubleshooting

## Status

**Project 07 – Application Watchdog: Completed**
