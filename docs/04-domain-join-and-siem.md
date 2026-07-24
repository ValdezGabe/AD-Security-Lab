# 04 — Domain Join & SIEM Deployment

Joining Windows and Linux hosts to the same realm, then getting telemetry off both.

## Windows domain join

Standard path. The one prerequisite that actually matters is DNS — the client must resolve
the domain's SRV records, which means pointing it at the DC rather than a public resolver.

```powershell
Add-Computer -DomainName 'team17.lab' -Credential (Get-Credential) -Restart
```

Confirm from the DC:

```powershell
Get-ADComputer -Filter * | Select-Object Name, DNSHostName, Enabled
```

Both the workstation and the SIEM host showed up under `CN=Computers` once joined.

## Linux domain join

More interesting. Ubuntu 24.04 joins the AD realm as a Kerberos member using SSSD, which
means AD accounts can authenticate to the Linux box directly — no separate local user
database.

```bash
sudo apt install realmd sssd sssd-tools libnss-sss libpam-sss adcli samba-common-bin
sudo realm join --user=Administrator team17.lab
realm list
```

Result:

```
team17.lab
  type: kerberos
  realm-name: TEAM17.LAB
  domain-name: team17.lab
  configured: kerberos-member
  server-software: active-directory
  client-software: sssd
  login-formats: %U@team17.lab
  login-policy: allow-realm-logins
```

`login-formats: %U@team17.lab` is the part to note — realm accounts log in as
`user@team17.lab`, not bare usernames, unless you configure `use_fully_qualified_names =
False` in `sssd.conf`.

This is the same Kerberos-to-service-authentication pattern I've worked with elsewhere:
the KDC issues tickets, the service validates them, and the user never presents a password
to the service itself.

## Cross-platform access verification

The point of a single realm is that one identity works everywhere. Verified in three
directions:

| From | To | Method |
|---|---|---|
| Windows workstation | Linux SIEM | `ssh dada-student@172.16.17.2` |
| Windows workstation | DC | `Enter-PSSession -ComputerName 172.16.17.1 -Credential TEAM17\jtaylor` |
| DC | Windows workstation | `Enter-PSSession -ComputerName 172.16.17.3 -Credential TEAM17\jtaylor` |

Deliberately tested with `jtaylor` — a non-privileged account — rather than an admin, since
the question was whether ordinary domain users could reach these hosts, not whether
administrators could.

## Wazuh deployment

Wazuh manager on the Ubuntu host, agents on the DC and the Windows workstation.

**Ports:**

| Port | Purpose |
|---|---|
| 1514 | Agent → manager event forwarding |
| 1515 | Agent enrollment/registration |
| 55000 | Manager REST API |

**Linux agent:**

```bash
sudo systemctl daemon-reload
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent
sudo systemctl status wazuh-agent
```

Healthy output shows `wazuh-execd`, `wazuh-agentd`, `wazuh-syscheckd`, `wazuh-logcollector`,
and `wazuh-modulesd` all running under the `wazuh-agent.service` cgroup.

**Verification.** The manager dashboard confirmed both agents active — the Windows 10 LTSC
workstation and the Server 2022 DC, both on agent v4.14.3, both reporting to `node01`.

## Why this matters for the rest of the lab

Everything in [docs/05](05-environment-audit.md) and [docs/06](06-windows-incident-response.md)
depends on this layer existing. Without agents on the endpoints there's no centralized
telemetry, and incident response degrades into logging into each box individually and
reading local logs — which is exactly the failure mode I hit during the Windows IR
exercise, and called out in that write-up's lessons learned.
