#!/bin/bash

set -u

echo "======================================"
echo " Linux Server Hardening - Project 04"
echo "======================================"
echo
echo "Mode: AUDIT"
echo "Host: $(hostname)"
echo "User: $(whoami)"
echo "Date: $(date)"
echo

echo "========== OS INFORMATION =========="
cat /etc/os-release | grep -E '^(NAME|VERSION|ID)='
echo

echo "========== KERNEL =========="
uname -r
echo

echo "========== SSH SECURITY BASELINE =========="
sudo sshd -T | grep -E \
'permitrootlogin|passwordauthentication|x11forwarding|allowagentforwarding|maxauthtries|logingracetime'
echo

echo "========== LISTENING PORTS =========="
sudo ss -lntp
echo

echo "Audit completed."
echo "No system changes were applied."
