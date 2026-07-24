<#
.SYNOPSIS
    Create and populate a baseline GPO via registry-backed policy settings.

.DESCRIPTION
    Demonstrates programmatic GPO creation with Set-GPRegistryValue rather than
    clicking through the Group Policy Management Editor, so the configuration is
    reproducible and diffable.

    *** WARNING - INTENTIONALLY INSECURE ***

    The -DisableFirewall switch turns off the Windows Firewall across the Domain,
    Private, and Public profiles. This exists because the lab requires a deliberately
    vulnerable target to audit and run incident response against.

    This is NOT a recommended configuration. It appears as a finding in
    docs/05-environment-audit.md. Do not run this against production.

.EXAMPLE
    .\Set-CoreGpo.ps1 -GpoName 'core-baseline' -Domain 'team17.lab'

.EXAMPLE
    .\Set-CoreGpo.ps1 -GpoName 'lab-target' -Domain 'team17.lab' -DisableFirewall
#>

#Requires -Modules GroupPolicy

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$GpoName,
    [Parameter(Mandatory)] [string]$Domain,

    [string]$WallpaperPath = 'C:\Windows\Web\Wallpaper\Windows\img0.jpg',

    # Disables the Windows Firewall on all three profiles. Lab targets only.
    [switch]$DisableFirewall
)

Import-Module GroupPolicy

if (Get-GPO -Name $GpoName -Domain $Domain -ErrorAction SilentlyContinue) {
    Write-Warning "GPO '$GpoName' already exists. Remove it first with: Remove-GPO -Name '$GpoName'"
    return
}

New-GPO -Name $GpoName -Domain $Domain | Out-Null
Write-Host "Created GPO: $GpoName"

# --- Desktop wallpaper (user configuration) -------------------------------
Set-GPRegistryValue -Name $GpoName -Domain $Domain `
    -Key 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\System' `
    -ValueName 'Wallpaper' `
    -Type String `
    -Value $WallpaperPath | Out-Null
Write-Host "  Set wallpaper policy"

# --- Hardening: remove Run from Start menu --------------------------------
Set-GPRegistryValue -Name $GpoName -Domain $Domain `
    -Key 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' `
    -ValueName 'NoRun' `
    -Type DWord `
    -Value 1 | Out-Null
Write-Host "  Removed Run from Start menu"

# --- Hardening: block registry editing tools ------------------------------
Set-GPRegistryValue -Name $GpoName -Domain $Domain `
    -Key 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\System' `
    -ValueName 'DisableRegistryTools' `
    -Type DWord `
    -Value 1 | Out-Null
Write-Host "  Blocked registry editing tools"

# --- INTENTIONALLY INSECURE: disable firewall on all profiles -------------
if ($DisableFirewall) {
    Write-Warning 'Disabling Windows Firewall on all profiles. Lab environments only.'

    $FirewallBase = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy'

    foreach ($Profile in @('DomainProfile', 'StandardProfile', 'PublicProfile')) {
        Set-GPRegistryValue -Name $GpoName -Domain $Domain `
            -Key "$FirewallBase\$Profile" `
            -ValueName 'EnableFirewall' `
            -Type DWord `
            -Value 0 | Out-Null
        Write-Host "  [INSECURE] Disabled firewall: $Profile"
    }
}

Write-Host "`nGPO '$GpoName' configured. Link it to a target OU, then run 'gpupdate /force' on clients."
Write-Host "Verify application on a client with: gpresult /h report.html"

Get-GPO -Name $GpoName -Domain $Domain
