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

echo
echo "========== SECURITY SCORECARD =========="

score=0
total=6

check_setting() {
    local name="$1"
    local actual="$2"
    local expected="$3"

    if [ "$actual" = "$expected" ]; then
        echo "[PASS] $name = $actual"
        score=$((score + 1))
    else
        echo "[FAIL] $name = $actual (expected $expected)"
    fi
}

check_setting "PermitRootLogin" \
"$(sudo sshd -T | awk '/^permitrootlogin / {print $2}')" "no"

check_setting "PasswordAuthentication" \
"$(sudo sshd -T | awk '/^passwordauthentication / {print $2}')" "no"

check_setting "X11Forwarding" \
"$(sudo sshd -T | awk '/^x11forwarding / {print $2}')" "no"

check_setting "MaxAuthTries" \
"$(sudo sshd -T | awk '/^maxauthtries / {print $2}')" "3"

check_setting "TCP Syncookies" \
"$(sysctl -n net.ipv4.tcp_syncookies)" "1"

check_setting "ASLR" \
"$(sysctl -n kernel.randomize_va_space)" "2"

echo
echo "Security Score: $score/$total"
