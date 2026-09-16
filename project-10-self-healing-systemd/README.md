# Project 10 — Self-Healing Linux Application with systemd

## Overview

This project demonstrates a self-healing Linux application managed by
systemd on Amazon Linux 2023.

A small Bash application runs continuously and writes a health/status
message. A controlled failure can terminate the application safely.

systemd detects the failure and automatically restarts the application.

## Architecture

```text
                    +----------------------+
                    |   systemd service    |
                    | self-healing-app     |
                    +----------+-----------+
                               |
                               | ExecStart
                               v
                    +----------------------+
                    | self-healing-app.sh  |
                    | Continuous process   |
                    +----------+-----------+
                               |
                    +----------+-----------+
                    |                      |
                    v                      v
             Status file             Crash signal
             /opt/.../status         /opt/.../crash
                    |                      |
                    v                      v
             Health probe            Controlled exit
                                           |
                                           v
                                  systemd detects failure
                                           |
                                           v
                                  RestartSec=5 seconds
                                           |
                                           v
                                      Application
                                       restarted
