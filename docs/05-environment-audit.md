# 05 — Environment Audit

Ten findings across the Windows and Linux hosts, with impact and remediation for each.

The environment was handed over deliberately misconfigured. The task was to find what was
wrong, explain why it mattered, and specify the fix.

---

## Findings

### 1. Microsoft Defender Antivirus disabled

**Impact:** Malware executes and persists with no detection or blocking. Combined with
finding 8, an attacker has an indefinite window.

**Fix:** `Computer Configuration → Policies → Administrative Templates → Windows
Components → Microsoft Defender Antivirus` → set **Turn off Microsoft Defender Antivirus**
to Disabled.

---

### 2. Anonymous FTP enabled

**Impact:** Unauthenticated read access to the FTP server. Anyone who can reach the port
can enumerate and pull files without credentials.

**Fix:** In `/etc/vsftpd.conf`, change `anonymous_enable=YES` → `anonymous_enable=NO`,
then `sudo systemctl restart vsftpd`.

---

### 3. Apache serving HTTP instead of HTTPS

**Impact:** All web traffic — including any credentials submitted through it — travels in
cleartext and is readable or modifiable by anyone on the path.

**Fix:** Edit `/etc/apache2/sites-available/000-default.conf` to listen on 443, enable
`mod_ssl` and a certificate, and redirect 80 → 443 rather than leaving both open.

---

### 4. SSH banner set to `/etc/shadow`

**Impact:** The worst finding on the Linux side. `Banner` contents are displayed to any
client **before authentication**, so every password hash on the system is handed to
anyone who opens a TCP connection to port 22. Those hashes go straight into offline
cracking with no rate limit and no lockout.

**Fix:** In `/etc/ssh/sshd_config`, remove the `Banner /etc/shadow` line or repoint it at
a static legal notice. Then rotate **every** password on the system — the hashes must be
assumed compromised.

---

### 5. User-provisioning script left on the domain controller

**Impact:** The script contains every account's logon name and the plaintext password
they were all created with. A single readable file yields the full credential set.

**Fix:** Remove the script from the DC. Longer term, don't hardcode credentials — prompt
at runtime (see [docs/02](02-identity-provisioning.md)).

---

### 6. Password reuse across all users and admins

**Impact:** Every account, privileged and unprivileged, shares one password. Compromise of
any single account is compromise of the domain. There is no lateral movement to perform —
the attacker already has everything.

**Fix:** Force a reset on all accounts with `-ChangePasswordAtLogon $true`, and enforce a
password policy with history, complexity, and minimum length actually configured — the
current policy has minimum length at 0 and complexity disabled.

---

### 7. Domain controller missing security updates

**Impact:** Known, published vulnerabilities remain exploitable. Public exploit code for
DC-class vulnerabilities tends to be reliable and lead directly to domain compromise.

**Fix:** Patch the DC and establish a maintenance cycle.

---

### 8. Automatic updates not configured

**Impact:** Patch application depends on someone remembering. Gaps between disclosure and
patching stretch indefinitely.

**Fix:** `Computer Configuration → Policies → Administrative Templates → Windows
Components → Windows Update` → enable **Configure Automatic Updates**, option 4 (auto
download and schedule install), daily, 08:00.

---

### 9. Users can pause updates

**Impact:** Undercuts finding 8's fix. A user who pauses updates re-opens the exposure
window on their own machine, and it stays open silently.

**Fix:** Enable **Remove access to "Pause updates" feature** in the same Windows Update
policy node.

---

### 10. SSH permits root login

**Impact:** `PermitRootLogin yes` exposes the account with the highest privilege on the
system to direct brute-force. Attackers don't have to guess a username. It also destroys
accountability — root actions can't be attributed to a person.

**Fix:** Set `PermitRootLogin no` in `/etc/ssh/sshd_config` and restart `sshd`. Administrators
log in as themselves and escalate via `sudo`, which is both safer and auditable.

---

## Detection coverage added

Fixing the misconfigurations closes the current holes. Audit logging is what makes the
next intrusion visible. Enabled via `scripts/Set-AuditPolicy.ps1`:

**PowerShell logging**

| Policy | Why |
|---|---|
| Turn On Module Logging | Records pipeline execution for loaded modules |
| Turn On Script Block Logging | Captures the actual script content executed — including deobfuscated blocks, which is what catches encoded payloads |

**Advanced audit policy**

| Subcategory | Setting | Catches |
|---|---|---|
| Credential Validation | Success + Failure | Password spraying, brute force |
| Computer Account Management | Success + Failure | Rogue machine accounts |
| Other Account Management Events | Success + Failure | Password-policy tampering |
| Security Group Management | Success + Failure | Privilege escalation via group membership |
| User Account Management | Success + Failure | Account creation, enable/disable, resets |
| Process Creation | Success + Failure | Execution chains — the backbone of IR timelines |
| Account Lockout | Success | Brute-force attempts hitting the threshold |
| Logon / Logoff | Success + Failure | Authentication baseline |
| Other Logon/Logoff Events | Success + Failure | RDP sessions, lock/unlock, Kerberos events |
| Special Logon | Success | Privileged account use |
| Audit Policy Change | Success + Failure | Attacker disabling the logging itself |
| Authentication Policy Change | Success + Failure | Kerberos and trust modification |
| Other System Events | Success + Failure | Firewall service state, crypto key operations |
| Security State Change | Success + Failure | Boot, shutdown, time change, crash recovery |

**Audit Policy Change** deserves specific attention: a competent attacker turns off logging
early. Auditing changes to the audit policy is what turns that action from invisible into
an alert.

**Sysinternals deployed:** Autoruns, Process Explorer, Process Monitor, Sysmon, Handle,
ListDLLs, LogonSessions, PsTools suite, Sigcheck, AccessChk, AccessEnum, TCPView, WinObj.
Sysmon in particular closes the gap between what Windows logs natively and what you
actually want during an investigation — process creation with full command lines, network
connections per process, and image loads.
