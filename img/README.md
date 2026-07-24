# Screenshots

Evidence and verification captures referenced from the docs.

| File | Doc | What it shows |
|---|---|---|
| `01-dc-server-manager.png` | [01](../docs/01-domain-controller.md) | Server Manager → Local Server after forest promotion. Domain field populated, Server 2022 Standard Evaluation on QEMU/KVM. |
| `03-gpo-creation-powershell.png` | [03](../docs/03-group-policy.md) | Programmatic GPO creation. `Remove-GPO` then re-run of the build script; incrementing `UserVersion`/`ComputerVersion` per policy setting applied. |
| `03-gpo-gpupdate-applied.png` | [03](../docs/03-group-policy.md) | Final GPO state (ComputerVersion 3) followed by a successful `gpupdate /force`. |
| `04-aduc-domain-joined-computers.png` | [04](../docs/04-domain-join-and-siem.md) | ADUC → `team17.lab` → Computers. SIEM host and Windows workstation both present as domain-joined computer objects. |
| `04-wazuh-endpoints-summary.png` | [04](../docs/04-domain-join-and-siem.md) | Wazuh endpoints dashboard — 2 agents active, 0 disconnected/pending/never-connected. |
| `04-wazuh-agents-list.png` | [04](../docs/04-domain-join-and-siem.md) | Agent detail: Windows 10 LTSC workstation (172.16.17.3) and Server 2022 DC (172.16.17.1), both v4.14.3, both reporting to `node01`. |
| `06-eventviewer-powershell-600.png` | [06](../docs/06-windows-incident-response.md) | **Primary IR evidence.** Windows PowerShell log, Event ID 600, 1/21/2026 11:06:54 AM. `HostApplication` captures the full malicious invocation including `-ExecutionPolicy Bypass -WindowStyle Hidden` and the payload path. |
| `06-autoruns-funbat-persistence.png` | [06](../docs/06-windows-incident-response.md) | **Persistence confirmation.** Autoruns → Logon tab. `fun.bat` in the per-user Startup folder, flagged `(Not Verified)` and highlighted, alongside legitimate signed entries for contrast. |
