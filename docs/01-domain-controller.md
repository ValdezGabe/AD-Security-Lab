# 01 — Domain Controller

Standing up the forest root from a bare Windows Server 2022 VM.

## Build

| | |
|---|---|
| Hypervisor | QEMU/KVM (Q35 + ICH9) |
| Guest OS | Windows Server 2022 Standard Evaluation |
| Resources | 8 GB RAM, ~50 GB disk |
| Domain | `team17.lab` |
| Address | 172.16.17.1 (static) |

## Steps

1. **Install the OS.** Server 2022 Standard, Desktop Experience. Set a static address
   before promotion — a DC that changes IP mid-flight causes DNS problems that are
   annoying to unwind.

2. **Add the AD DS role.** Server Manager → Add Roles and Features → Active Directory
   Domain Services. Or:

   ```powershell
   Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
   ```

3. **Promote to domain controller.** This creates a new forest, so the server becomes the
   forest root, the first DC, and — because no other DNS server exists yet — the DNS
   server for the domain.

   ```powershell
   Install-ADDSForest `
     -DomainName "team17.lab" `
     -DomainNetbiosName "TEAM17" `
     -InstallDns `
     -SafeModeAdministratorPassword (Read-Host -AsSecureString "DSRM password")
   ```

   The server reboots. On the way back up it's a DC.

4. **Verify.** Server Manager → Local Server should show the domain populated rather than
   a workgroup, and an **AD DS** node should now appear in the left rail alongside **DNS**.

   ```powershell
   Get-ADDomain
   Get-ADDomainController
   Resolve-DnsName team17.lab
   ```

## Notes

**DNS is the part that bites you.** AD is entirely dependent on DNS SRV records for
domain controller location. If clients can't resolve `_ldap._tcp.dc._msdcs.team17.lab`,
domain join fails with errors that don't obviously point at DNS. Every domain member —
including the DC itself — must point at the DC for DNS, not at a public resolver.

**`.lab` is fine here, but not a great habit.** A non-routable made-up TLD works for an
isolated lab. In production you'd use a subdomain of a domain you actually own
(`ad.example.com`) to avoid collisions if the TLD is ever delegated for real.

**The DSRM password matters.** Directory Services Restore Mode is how you recover a DC
whose directory database is corrupted. It's set once at promotion and then forgotten
until the day you desperately need it.
