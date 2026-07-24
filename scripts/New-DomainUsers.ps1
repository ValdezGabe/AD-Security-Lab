<#
.SYNOPSIS
    Bulk-provision Active Directory users from a data table.

.DESCRIPTION
    Creates domain user accounts with display name, logon name, and job description,
    then grants elevated group membership to a declared subset.

    The password is prompted for at runtime rather than stored in the script.
    Accounts are created with ChangePasswordAtLogon enabled, so the initial password
    is a one-time value the user replaces on first logon.

.NOTES
    Run on a domain controller, or on a host with RSAT-AD-PowerShell installed.
#>

#Requires -Modules ActiveDirectory

[CmdletBinding()]
param(
    # Target OU. Defaults to the domain's Users container, but a purpose-built OU is
    # strongly preferred — GPOs cannot be linked to CN=Users.
    [string]$TargetOU
)

Import-Module ActiveDirectory

# Prompt rather than hardcode. Never commit a credential to source control.
$Password = Read-Host -AsSecureString -Prompt 'Initial password for new accounts'

$Users = @(
    @{ DisplayName = 'Dave Mitchell';    LogonName = 'dmitchell'; Description = 'Chief Executive Officer' },
    @{ DisplayName = 'Bob Rodriguez';    LogonName = 'brodriguez'; Description = 'Chief Information Officer' },
    @{ DisplayName = 'Brandon Davis';    LogonName = 'bdavis';    Description = 'IT Director' },
    @{ DisplayName = 'David Thompson';   LogonName = 'dthompson'; Description = 'HR Manager' },
    @{ DisplayName = 'Emily Parker';     LogonName = 'eparker';   Description = 'Operations Manager' },
    @{ DisplayName = 'Robert Williams';  LogonName = 'rwilliams'; Description = 'Sales Director' },
    @{ DisplayName = 'Amanda Foster';    LogonName = 'afoster';   Description = 'Marketing Manager' },
    @{ DisplayName = 'James Anderson';   LogonName = 'janderson'; Description = 'Senior Developer' },
    @{ DisplayName = 'Lisa Nguyen';      LogonName = 'lnguyen';   Description = 'Senior Developer' },
    @{ DisplayName = 'Christopher Lee';  LogonName = 'clee';      Description = 'Junior Developer' },
    @{ DisplayName = 'Rachel Martinez';  LogonName = 'rmartinez'; Description = 'Junior Developer' },
    @{ DisplayName = 'Kevin Brown';      LogonName = 'kbrown';    Description = 'Help Desk Technician' },
    @{ DisplayName = 'Michelle Davis';   LogonName = 'mdavis';    Description = 'Accountant' },
    @{ DisplayName = 'Daniel Harris';    LogonName = 'dharris';   Description = 'Customer Service Representative' },
    @{ DisplayName = 'Jessica Taylor';   LogonName = 'jtaylor';   Description = 'Administrative Assistant' }
)

# NOTE: This elevated list reflects the lab's intentionally over-permissioned design.
# In practice, administrative rights should go to separate privileged accounts
# (e.g. 'bdavis-adm') rather than to daily-driver accounts, and developers and
# operations staff should not hold domain-level admin at all.
$Elevated = @('dmitchell', 'brodriguez', 'bdavis', 'eparker', 'janderson', 'lnguyen', 'clee')

foreach ($User in $Users) {

    if (Get-ADUser -Filter "SamAccountName -eq '$($User.LogonName)'" -ErrorAction SilentlyContinue) {
        Write-Warning "Skipping $($User.LogonName) - account already exists."
        continue
    }

    $Params = @{
        Name                  = $User.DisplayName
        SamAccountName        = $User.LogonName
        DisplayName           = $User.DisplayName
        Description           = $User.Description
        AccountPassword       = $Password
        ChangePasswordAtLogon = $true
        Enabled               = $true
        ErrorAction           = 'Stop'
    }

    if ($TargetOU) { $Params['Path'] = $TargetOU }

    try {
        New-ADUser @Params
        Write-Host "Created $($User.LogonName) - $($User.Description)"

        if ($Elevated -contains $User.LogonName) {
            Add-ADGroupMember -Identity 'Administrators' -Members $User.LogonName -ErrorAction Stop
            Write-Host "  -> added to Administrators"
        }
    }
    catch {
        Write-Error "Failed to create $($User.LogonName): $_"
    }
}

Write-Host "`nVerification:"
Get-ADUser -Filter * -Properties Description |
    Select-Object Name, SamAccountName, Description |
    Format-Table -AutoSize
