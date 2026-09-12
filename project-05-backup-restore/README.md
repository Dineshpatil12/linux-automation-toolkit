# Project 5 - Linux Backup & Restore System

## Overview

This project implements a practical Linux backup and restore system using Bash, GNU tar, SHA-256 checksums, JSON manifests, file locking, retention management, and cron automation.

The project uses safe test data on an AWS EC2 Amazon Linux lab environment.

## Objectives

- Full and incremental backups
- GNU tar snapshot-based backup chains
- SHA-256 integrity verification
- JSON backup manifests
- Unique backup chain IDs
- Preflight and disk-space validation
- Concurrent execution protection with flock
- Complete backup-chain restore
- Chain-safe retention
- Database-aware backup design
- Cron automation
- Logging and exit codes
- Real restore validation

## Architecture

Application/Test Data -> backup.sh -> Full/Incremental Backup -> SHA-256 -> JSON Manifest -> Chain ID -> backups/ -> retention.sh

Restore: Full Backup + Matching Incrementals -> restore.sh -> restore-test/ -> Source vs Restored Validation

## Project Structure

```text
project-05-backup-restore/
|-- bin/
|   |-- backup.sh
|   |-- restore.sh
|   `-- retention.sh
|-- conf/
|   `-- backup.conf
|-- sample-output/
|-- screenshots/
`-- README.md
```

Runtime data:

```text
/opt/devopsshack/backup-lab/
|-- test-data/
|-- backups/
|-- state/
|-- logs/
`-- restore-test/
```

## Full Backup

A full backup contains the complete source dataset and starts a new backup chain.

Example: full-2026-09-12-150709.tar.gz

## Incremental Backup

Incremental backups contain changes detected after the previous backup in the chain.

GNU tar snapshot mode is used:

```bash
tar --listed-incremental="$SNAPSHOT_FILE"
```

Restore requires the full backup followed by the required incrementals from the same chain.

## Backup Chain

Every full backup receives a unique chain ID. Example: 20260912T150709Z

The full backup and its incrementals use the same chain ID. This prevents an incremental from another chain being applied incorrectly.

## Integrity Verification

Every backup archive receives a SHA-256 checksum.

```bash
sha256sum backup.tar.gz > backup.tar.gz.sha256
sha256sum -c backup.tar.gz.sha256
```

Expected: backup.tar.gz: OK

## JSON Manifest

Automated backups create a JSON manifest containing backup type, timestamp, archive path, SHA-256 checksum, source, chain ID, RPO, and RTO.

## RPO and RTO

**RPO:** Recovery Point Objective defines the acceptable data-loss window. Current target: 60 minutes.

**RTO:** Recovery Time Objective defines the target recovery time. Current target: 30 minutes.

## Preflight Validation

backup.sh validates configuration, required directories, available disk space, and incremental chain state before backup execution.

Minimum free space: MIN_FREE_MB=100

## Concurrent Execution Protection

The project uses flock and /opt/devopsshack/backup-lab/state/backup.lock to prevent concurrent backup processes from modifying the same snapshot state.

## Restore

restore.sh finds the latest full backup, verifies its checksum, identifies matching incrementals using chain ID, verifies their checksums, applies them, and creates the restored dataset under restore-test/.

## Real Restore Test

A real restore test was successfully completed.

Full: full-2026-09-12-150709.tar.gz

Incremental: incremental-2026-09-12-150837.tar.gz

Chain: 20260912T150709Z

Restored files included app.conf, app-data.txt, backup-demo.conf, and application.log.

Source and restored app-data.txt SHA-256 matched:

a46e4c02477a4dcd26d8bf63c7c78d9d5ffab2df236d0c5ec6005bd5f4ba9591

diff produced no differences.

## Retention

retention.sh manages retention by complete backup chain. Current policy: RETENTION_CHAINS=2.

Old complete chains are removed instead of deleting individual incremental files blindly.

## Database-Aware Backup

No database is installed in this lab, therefore DB_BACKUP_ENABLED=false.

Production examples include pg_dump for PostgreSQL, mysqldump for MySQL/MariaDB, and mongodump for MongoDB. Database-consistent dumps should be created before filesystem archival.

## Cron Automation

```cron
0 2 * * * /home/ec2-user/linux-automation-toolkit/project-05-backup-restore/bin/backup.sh
30 2 * * * /home/ec2-user/linux-automation-toolkit/project-05-backup-restore/bin/retention.sh
```

Verify with: sudo crontab -l

## Logging

Log file: /opt/devopsshack/backup-lab/logs/backup.log

The log records backup type, archive creation, checksum verification, manifest creation, chain ID, and completion status.

## Exit Codes

| Code | Meaning |
|---:|---|
| 0 | Success |
| 1 | General error / lock |
| 2 | Configuration error |
| 3 | Backup or chain error |
| 4 | Checksum verification failure |

## Useful Commands

```bash
./bin/backup.sh
./bin/restore.sh
./bin/retention.sh
sudo crontab -l
git status
```

## Security

Production improvements should include encryption, least-privilege access, secrets management, separate backup storage, immutable storage, monitoring, and regular restore testing.

No production secrets are stored in Git.

## Git Safety

Runtime backup files are excluded from Git, including tar archives, checksums, snapshots, manifests, locks, logs, and restore-test data.

## Production Improvements

1. Remote rsync backup
2. AWS S3 storage
3. S3 versioning/object lock
4. Encryption
5. Automated database dumps
6. Backup monitoring
7. Prometheus metrics
8. Notifications
9. Automated restore testing
10. Multi-region disaster recovery

## Interview Explanation

I implemented a Linux backup and restore system using Bash and GNU tar. It supports full and snapshot-based incremental backups, SHA-256 checksum verification, JSON manifests, chain IDs, flock locking, retention management, cron automation, and a tested restore process. I verified the solution by restoring a full backup plus an incremental backup and comparing the restored data with the source using SHA-256 and diff.

## Final Checklist

- [x] Full backup
- [x] Incremental backup
- [x] GNU tar snapshot
- [x] SHA-256 verification
- [x] JSON manifests
- [x] Chain ID tracking
- [x] Preflight validation
- [x] Disk-space check
- [x] Locking
- [x] Restore script
- [x] Real restore test
- [x] Source vs restored validation
- [x] Chain-safe retention
- [x] Database-aware configuration
- [x] Cron automation
- [x] Logging
- [x] Exit codes
- [x] Git/GitHub integration

# Status

**PROJECT 05 - COMPLETED**
