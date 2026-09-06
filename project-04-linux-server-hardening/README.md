# Project 4 - Linux Server Hardening

## Overview

This project demonstrates Linux server hardening on an AWS EC2 Amazon Linux 2023 instance.

The goal of this project is to improve the security posture of a Linux server while avoiding SSH lockout, service disruption, and Docker networking issues.

The project includes:

- SSH hardening
- AWS Security Group hardening
- Account and password policies
- Kernel and network hardening
- Filesystem permission auditing
- World-writable file auditing
- Unnecessary service auditing
- Security verification
- Security scorecard
- Git-based configuration management

The project follows a safety-first approach where every important security change is backed up, validated, tested, and verified before moving to the next stage.

---

## Objectives

The main objectives of this project are:

- Disable direct root SSH login
- Disable SSH password authentication
- Disable unnecessary SSH forwarding features
- Reduce SSH authentication attempts
- Reduce SSH login grace time
- Restrict SSH access to a trusted public IP
- Configure password aging policies
- Configure a restrictive UMASK
- Harden kernel and network parameters
- Enable SYN flood protection
- Enable reverse path filtering
- Maintain ASLR protection
- Preserve Docker networking compatibility
- Audit sensitive system file permissions
- Detect world-writable host files
- Audit legacy and unnecessary services
- Generate security verification evidence
- Generate a security scorecard

---

## Environment

This project was implemented using:

- AWS EC2
- Amazon Linux 2023
- Bash
- OpenSSH
- Docker
- iptables
- sysctl
- systemd
- AWS Security Groups
- Git
- GitHub
- MobaXterm

---

## Safety Approach

Linux server hardening can cause remote access problems if SSH or firewall settings are configured incorrectly.

Therefore, the following safety controls were used:

- Existing SSH configuration was backed up
- Multiple SSH sessions were kept open
- A second SSH session was maintained during SSH changes
- SSH configuration was validated before reload
- SSH daemon was reloaded instead of restarted
- A completely new SSH session was tested after hardening
- AWS Security Group changes were validated before closing existing sessions
- Existing firewall rules were audited before modification
- Docker networking dependencies were checked before kernel changes
- Important system configuration files were backed up
- Every change was verified immediately after implementation
- Git commits were created at important milestones

---

## Project Structure

```text
project-04-linux-server-hardening/
├── README.md
├── bin/
│   └── harden.sh
├── conf/
│   ├── account-hardening.conf
│   ├── kernel-hardening.conf
│   └── ssh-hardening.conf
├── sample-output/
│   ├── account-hardening-verification.txt
│   ├── baseline-audit.txt
│   ├── filesystem-hardening-verification.txt
│   ├── final-audit.txt
│   ├── firewall-verification.txt
│   ├── kernel-hardening-verification.txt
│   ├── service-hardening-verification.txt
│   └── ssh-hardening-verification.txt
└── screenshots/
```

---

# Hardening Modules

## 1. SSH Hardening

The current SSH configuration was first audited using:

```bash
sudo sshd -T
```

Initial SSH settings:

```text
LoginGraceTime 120
MaxAuthTries 6
PermitRootLogin without-password
PasswordAuthentication no
X11Forwarding yes
AllowAgentForwarding yes
```

The following hardened SSH configuration was defined:

```text
PermitRootLogin no
PasswordAuthentication no
X11Forwarding no
AllowAgentForwarding no
MaxAuthTries 3
LoginGraceTime 30
```

The desired SSH configuration is stored in:

```text
conf/ssh-hardening.conf
```

A dedicated OpenSSH drop-in configuration file was used:

```text
/etc/ssh/sshd_config.d/01-project04-hardening.conf
```

Using a separate drop-in configuration avoided unnecessary modification of the main SSH configuration file.

Before applying the configuration, SSH syntax was validated:

```bash
sudo sshd -t
```

No output confirmed that the SSH configuration syntax was valid.

The effective configuration was then verified:

```bash
sudo sshd -T
```

Final SSH settings:

```text
logingracetime 30
maxauthtries 3
permitrootlogin no
passwordauthentication no
x11forwarding no
allowagentforwarding no
```

The SSH daemon was safely reloaded:

```bash
sudo systemctl reload sshd
```

SSH service status was verified:

```bash
sudo systemctl is-active sshd
```

Result:

```text
active
```

A completely new SSH session was successfully opened after the reload.

This confirmed that the hardened SSH configuration was working without causing a remote lockout.

---

## 2. AWS Security Group Hardening

Initially, SSH port 22 was exposed to:

```text
0.0.0.0/0
```

This allowed SSH connection attempts from any IPv4 address on the internet.

The SSH Security Group rule was restricted to:

```text
MY_PUBLIC_IP/32
```

Before:

```text
SSH | TCP | 22 | 0.0.0.0/0
```

After:

```text
SSH | TCP | 22 | MY_PUBLIC_IP/32
```

The `/32` CIDR represents one specific trusted public IP address.

After changing the Security Group rule, a new MobaXterm SSH session was successfully tested.

This reduced the SSH attack surface while maintaining administrative access.

---

## 3. Firewall Audit

The host firewall services were checked using:

```bash
sudo systemctl is-active firewalld
sudo systemctl is-active nftables
```

Result:

```text
inactive
inactive
```

The `nft` command was not installed on the server.

Existing iptables rules were audited using:

```bash
sudo iptables -S
```

Important default policies were:

```text
INPUT ACCEPT
FORWARD DROP
OUTPUT ACCEPT
```

Docker-managed iptables rules were also present.

Docker was publishing ports such as:

```text
3000
3200
4040
4317
4318
9090
```

Because Docker networking was already active, existing iptables rules were not flushed or replaced.

This prevented Docker networking from being accidentally broken.

---

## 4. Account and Password Policy Hardening

The initial Linux password policy was:

```text
PASS_MAX_DAYS   99999
PASS_MIN_DAYS   0
PASS_WARN_AGE   7
UMASK           022
```

The hardened configuration was:

```text
PASS_MAX_DAYS 90
PASS_MIN_DAYS 1
PASS_WARN_AGE 14
UMASK 027
```

The desired configuration is stored in:

```text
conf/account-hardening.conf
```

Before changing `/etc/login.defs`, a backup was created:

```text
/etc/login.defs.project04.bak
```

The final configuration became:

```text
UMASK           027
PASS_MAX_DAYS   90
PASS_MIN_DAYS   1
PASS_WARN_AGE   14
```

The existing `ec2-user` account still had the old password aging policy.

The current policy was checked using:

```bash
sudo chage -l ec2-user
```

The existing user was updated using:

```bash
sudo chage -m 1 -M 90 -W 14 ec2-user
```

Final result:

```text
Minimum number of days between password change : 1
Maximum number of days between password change : 90
Number of days of warning before password expires : 14
```

This demonstrated that changing `/etc/login.defs` does not automatically update password-aging values for existing users.

---

## 5. Kernel and Network Hardening

The current kernel security settings were audited using `sysctl`.

Initial values included:

```text
net.ipv4.ip_forward = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 1
net.ipv4.conf.all.send_redirects = 1
net.ipv4.conf.all.rp_filter = 0
net.ipv4.tcp_syncookies = 1
kernel.randomize_va_space = 2
```

Before disabling IP forwarding, Docker networks were checked:

```bash
docker network ls
```

The server contained Docker bridge networks:

```text
bridge
prometheus-monitoring_default
tracing-net
```

Because Docker bridge networking was active, the following setting was intentionally retained:

```text
net.ipv4.ip_forward = 1
```

Disabling IP forwarding could break Docker container networking and NAT.

The following hardened kernel settings were configured:

```text
net.ipv4.ip_forward = 1

net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0

net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

net.ipv4.tcp_syncookies = 1

kernel.randomize_va_space = 2
```

The configuration is stored in:

```text
conf/kernel-hardening.conf
```

The persistent system configuration was installed as:

```text
/etc/sysctl.d/99-project04-hardening.conf
```

The settings were applied using:

```bash
sudo sysctl --system
```

Final verified values:

```text
net.ipv4.ip_forward = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1
kernel.randomize_va_space = 2
```

---

## 6. Filesystem Hardening Audit

Sensitive system file permissions were audited using:

```bash
sudo stat -c '%a %U:%G %n' \
/etc/passwd \
/etc/shadow \
/etc/group \
/etc/gshadow \
/etc/ssh/sshd_config
```

Verified permissions:

```text
644 root:root /etc/passwd
000 root:root /etc/shadow
644 root:root /etc/group
000 root:root /etc/gshadow
600 root:root /etc/ssh/sshd_config
```

These files were already securely configured.

Therefore, unnecessary permission changes were not made.

This follows an important hardening principle:

> Do not change a secure configuration unnecessarily.

---

## 7. World-Writable File Audit

The server was checked for world-writable files using:

```bash
sudo find / -xdev -type f -perm -0002 2>/dev/null
```

Initial results mainly came from Docker overlay storage.

Docker container filesystem files should not be directly modified from the host.

Therefore, Docker storage was excluded from the host filesystem audit.

Final command:

```bash
sudo find / -xdev \
-path /var/lib/docker -prune -o \
-type f -perm -0002 -print 2>/dev/null
```

Result:

```text
No world-writable host files found outside Docker.
```

---

## 8. Unnecessary Services Audit

Enabled services were reviewed using:

```bash
sudo systemctl list-unit-files --type=service --state=enabled
```

Required services included:

```text
amazon-ssm-agent
auditd
chronyd
crond
docker
sshd
cloud-init
systemd-networkd
```

Legacy and potentially unnecessary services were specifically audited:

```text
telnet
rsh
rlogin
vsftpd
tftp
cups
avahi-daemon
rpcbind
```

Final result:

```text
telnet.socket        not-installed
rsh.socket           not-installed
rlogin.socket        not-installed
vsftpd.service       not-installed
tftp.service         not-installed
cups.service         not-installed
avahi-daemon.service not-installed
rpcbind.service      disabled
```

No insecure legacy remote-access services were active.

---

# Security Audit Script

The main project script is:

```text
bin/harden.sh
```

Run the script using:

```bash
./bin/harden.sh
```

The script collects:

- Operating system information
- Kernel version
- SSH security configuration
- Listening TCP ports
- Security control validation
- Security scorecard

---

## Example Audit Output

```text
======================================
 Linux Server Hardening - Project 04
======================================

Mode: AUDIT

========== SSH SECURITY BASELINE ==========
logingracetime 30
maxauthtries 3
permitrootlogin no
passwordauthentication no
x11forwarding no
allowagentforwarding no
```

---

# Security Scorecard

The audit script automatically checks important security controls.

The following checks are included:

```text
PermitRootLogin
PasswordAuthentication
X11Forwarding
MaxAuthTries
TCP Syncookies
ASLR
```

Final result:

```text
========== SECURITY SCORECARD ==========

[PASS] PermitRootLogin = no
[PASS] PasswordAuthentication = no
[PASS] X11Forwarding = no
[PASS] MaxAuthTries = 3
[PASS] TCP Syncookies = 1
[PASS] ASLR = 2

Security Score: 6/6
```

---

# Before and After Comparison

## SSH Hardening

| Setting | Before | After |
|---|---|---|
| PermitRootLogin | without-password | no |
| PasswordAuthentication | no | no |
| X11Forwarding | yes | no |
| AllowAgentForwarding | yes | no |
| MaxAuthTries | 6 | 3 |
| LoginGraceTime | 120 | 30 |

---

## Account Policy

| Setting | Before | After |
|---|---:|---:|
| PASS_MAX_DAYS | 99999 | 90 |
| PASS_MIN_DAYS | 0 | 1 |
| PASS_WARN_AGE | 7 | 14 |
| UMASK | 022 | 027 |

---

## Kernel Security

| Setting | Before | After |
|---|---:|---:|
| Default Accept Redirects | 1 | 0 |
| Send Redirects | 1 | 0 |
| Reverse Path Filter | 0 | 1 |
| TCP SYN Cookies | 1 | 1 |
| ASLR | 2 | 2 |

---

# Verification Evidence

Before and after verification evidence is stored under:

```text
sample-output/
```

Files include:

```text
baseline-audit.txt
ssh-hardening-verification.txt
firewall-verification.txt
account-hardening-verification.txt
kernel-hardening-verification.txt
filesystem-hardening-verification.txt
service-hardening-verification.txt
final-audit.txt
```

---

# Docker Compatibility Exception

A generic Linux security recommendation may suggest:

```text
net.ipv4.ip_forward = 0
```

However, this server runs Docker bridge networking.

Disabling IPv4 forwarding could break:

- Docker bridge networking
- Container-to-container communication
- Docker NAT
- Published container ports

Therefore:

```text
net.ipv4.ip_forward = 1
```

was intentionally retained.

This demonstrates an important real-world security principle:

> Hardening should consider application and infrastructure dependencies instead of blindly applying generic recommendations.

---

# Rollback Strategy

SSH configuration backup:

```text
/etc/ssh/sshd_config.project04.bak
```

Account configuration backup:

```text
/etc/login.defs.project04.bak
```

Before SSH reload, configuration should always be validated:

```bash
sudo sshd -t
```

The SSH daemon should only be reloaded after successful validation.

Existing SSH sessions should remain open until a completely new SSH connection has been tested successfully.

---

# Testing and Validation

SSH configuration syntax:

```bash
sudo sshd -t
```

SSH effective configuration:

```bash
sudo sshd -T
```

SSH service:

```bash
sudo systemctl is-active sshd
```

Password policy:

```bash
sudo chage -l ec2-user
```

Kernel parameters:

```bash
sysctl net.ipv4.tcp_syncookies
sysctl kernel.randomize_va_space
```

Docker networks:

```bash
docker network ls
```

Firewall rules:

```bash
sudo iptables -S
```

Listening ports:

```bash
sudo ss -lntp
```

Final security audit:

```bash
./bin/harden.sh
```

---

# Key Security Lessons

1. Always keep a second SSH session open before changing SSH settings.

2. Never restart or reload SSH before validating configuration with `sshd -t`.

3. Test a completely new SSH connection before closing existing sessions.

4. Restrict AWS Security Group SSH access instead of exposing port 22 to the entire internet.

5. Use SSH drop-in configuration files when possible.

6. Back up important configuration files before modifying them.

7. Do not blindly apply generic security recommendations.

8. Check application dependencies before changing kernel networking settings.

9. Docker can manage iptables rules even when firewalld is inactive.

10. Existing user password policies may need to be updated separately using `chage`.

11. Do not modify system files that are already securely configured.

12. Maintain before-and-after evidence for troubleshooting and auditing.

---

# Interview Explanation

I implemented Linux server hardening on an AWS EC2 Amazon Linux 2023 server.

First, I performed a baseline security audit before making any configuration changes.

I hardened SSH by disabling direct root login, password authentication, X11 forwarding, and SSH agent forwarding. I also reduced the maximum authentication attempts from six to three and reduced the login grace time from 120 seconds to 30 seconds.

Before applying SSH changes, I created a backup, kept multiple SSH sessions open, and validated the SSH configuration using `sshd -t`. After reloading SSH, I opened a completely new SSH session to confirm that I had not locked myself out.

I also restricted AWS Security Group SSH access from `0.0.0.0/0` to a trusted `/32` public IP.

For account security, I configured password aging with a 90-day maximum password age, one-day minimum password age, 14-day warning period, and UMASK 027. I also updated the existing `ec2-user` policy using `chage`.

For kernel hardening, I disabled ICMP redirects, enabled reverse path filtering, enabled TCP SYN cookies, and verified ASLR. Because Docker was running on the server, I intentionally kept IP forwarding enabled to avoid breaking Docker bridge networking.

I audited sensitive system file permissions, checked for world-writable files, and verified that legacy services such as Telnet, rsh, FTP, and TFTP were not active.

Finally, I created a Bash audit script that validates the hardened configuration and generates a security scorecard.

The final security score was 6 out of 6.

---

# Short Interview Answer

> I hardened an Amazon Linux EC2 server by securing SSH, restricting AWS Security Group access, configuring password policies, applying kernel security settings, auditing filesystem permissions and unnecessary services, and creating a Bash-based security verification script. I followed a safety-first process by keeping multiple SSH sessions open, backing up configurations, validating `sshd_config` before reload, and testing a new SSH session after every critical change. The final security score was 6/6.

---

# Key Commands

SSH validation:

```bash
sudo sshd -t
sudo sshd -T
sudo systemctl reload sshd
sudo systemctl is-active sshd
```

Account policy:

```bash
sudo chage -m 1 -M 90 -W 14 ec2-user
sudo chage -l ec2-user
```

Kernel hardening:

```bash
sudo sysctl --system
```

Docker verification:

```bash
docker network ls
```

Firewall audit:

```bash
sudo iptables -S
```

Filesystem audit:

```bash
sudo stat -c '%a %U:%G %n' \
/etc/passwd \
/etc/shadow \
/etc/group \
/etc/gshadow \
/etc/ssh/sshd_config
```

World-writable file audit:

```bash
sudo find / -xdev \
-path /var/lib/docker -prune -o \
-type f -perm -0002 -print 2>/dev/null
```

Service audit:

```bash
sudo systemctl list-unit-files --type=service --state=enabled
```

Security audit:

```bash
./bin/harden.sh
```

---

# Final Result

The Linux server was successfully hardened while preserving:

- SSH access
- Docker networking
- Existing container services
- AWS EC2 connectivity

Final Security Score:

```text
6/6
```

---

## Status

Project 04 - Completed
