# 02 — Identity Provisioning

Bulk-creating a realistic org chart in Active Directory with PowerShell.

## Goal

Populate the domain with 15 users spanning executive, IT, engineering, and support roles,
each with a display name, logon name, and job description, and grant elevated group
membership to the subset that should have it.

Doing this by hand in ADUC is fine for three users and miserable for fifteen. It's also
not reproducible — if the domain gets torn down and rebuilt, you want to re-run a script,
not repeat forty minutes of clicking.

## Approach

The script (`scripts/New-DomainUsers.ps1`) is built around a table of hashtables. Each
entry carries the three attributes that vary per user; everything else is constant and
applied in the loop.

```powershell
$Users = @(
    @{ DisplayName = 'Dave Mitchell';  LogonName = 'dmitchell'; Description = 'Chief Executive Officer' },
    @{ DisplayName = 'Bob Rodriguez';  LogonName = 'brodriguez'; Description = 'Chief Information Officer' },
    # ...
)
```

Elevated accounts are declared as a separate list of logon names, and membership is
applied conditionally inside the same loop:

```powershell
$Elevated = @('dmitchell','brodriguez','bdavis','eparker','janderson','lnguyen','clee')

foreach ($User in $Users) {
    New-ADUser -Name $User.DisplayName `
               -SamAccountName $User.LogonName `
               -DisplayName $User.DisplayName `
               -Description $User.Description `
               -AccountPassword $Password `
               -ChangePasswordAtLogon $true `
               -Enabled $true

    if ($Elevated -contains $User.LogonName) {
        Add-ADGroupMember -Identity 'Administrators' -Members $User.LogonName
    }
}
```

Verify:

```powershell
Get-ADUser -Filter * -Properties Description |
    Select-Object Name, SamAccountName, Description
```

## What I'd change

The original lab version of this script had three problems worth calling out, all of which
are fixed in the committed version:

**Hardcoded password.** The password was a plaintext string literal converted with
`ConvertTo-SecureString -AsPlainText -Force`. That defeats the point of a `SecureString`
and means the credential lives in the script file, in shell history, and in any backup of
either. The committed version prompts with `Read-Host -AsSecureString`.

**`-ChangePasswordAtLogon $false`.** Every account shipped with the same known password
and no requirement to change it. That's the single worst finding in the whole environment
audit (see [docs/05](05-environment-audit.md), finding 6) — compromise one account and
you have all fifteen. The committed version sets it to `$true`.

**Everything landed in `CN=Users`.** The default container can't have GPOs linked to it,
which means you can't apply differentiated policy by role. Users should be created into
purpose-built OUs (`OU=Engineering,DC=team17,DC=lab`) via the `-Path` parameter.

**On the elevated list itself:** seven of fifteen accounts in `Administrators` is a
deliberately bad ratio and part of the lab's vulnerable-by-design setup. In practice,
developers and an operations manager have no business holding domain-level admin. The
correct model is separate privileged accounts (`dmitchell-adm`) used only for
administrative tasks, with the daily-driver account staying unprivileged.
