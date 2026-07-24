<#
.SYNOPSIS
    Enable PowerShell logging and advanced audit policy for detection coverage.

.DESCRIPTION
    Configures the logging that makes incident response possible. Two parts:

    1. PowerShell Module Logging and Script Block Logging, applied via GPO registry
       values. Script Block Logging is the important one - it captures deobfuscated
       script content, which is what catches encoded payloads and, critically, records
       scripts that delete themselves after execution.

    2. Advanced audit policy subcategories, applied locally with auditpol.exe.

    Rationale for each subcategory is in docs/05-environment-audit.md.

.NOTES
    The auditpol section configures the LOCAL policy on the machine where it runs.
    For domain-wide deployment, configure the equivalent settings under
    Computer Configuration -> Policies -> Windows Settings -> Security Settings ->
    Advanced Audit Policy Configuration in a GPO.

    Requires elevation.
#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [string]$GpoName,
    [string]$Domain,

    # Skip the GPO portion and only configure local audit policy.
    [switch]$LocalOnly
)

# ==========================================================================
# PowerShell logging (via GPO)
# ==========================================================================

if (-not $LocalOnly) {
    if (-not $GpoName -or -not $Domain) {
        throw 'GpoName and Domain are required unless -LocalOnly is specified.'
    }

    Import-Module GroupPolicy

    $PsPolicyBase = 'HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\PowerShell'

    # Module Logging - records pipeline execution events for loaded modules
    Set-GPRegistryValue -Name $GpoName -Domain $Domain `
        -Key "$PsPolicyBase\ModuleLogging" `
        -ValueName 'EnableModuleLogging' -Type DWord -Value 1 | Out-Null

    Set-GPRegistryValue -Name $GpoName -Domain $Domain `
        -Key "$PsPolicyBase\ModuleLogging\ModuleNames" `
        -ValueName '*' -Type String -Value '*' | Out-Null

    Write-Host 'Enabled PowerShell Module Logging'

    # Script Block Logging - records actual script content, including deobfuscated blocks
    Set-GPRegistryValue -Name $GpoName -Domain $Domain `
        -Key "$PsPolicyBase\ScriptBlockLogging" `
        -ValueName 'EnableScriptBlockLogging' -Type DWord -Value 1 | Out-Null

    Write-Host 'Enabled PowerShell Script Block Logging'
}

# ==========================================================================
# Advanced audit policy (local)
# ==========================================================================

# Subcategory => audit setting
$AuditPolicy = [ordered]@{
    'Credential Validation'          = '/success:enable /failure:enable'
    'Computer Account Management'    = '/success:enable /failure:enable'
    'Other Account Management Events'= '/success:enable /failure:enable'
    'Security Group Management'      = '/success:enable /failure:enable'
    'User Account Management'        = '/success:enable /failure:enable'
    'Process Creation'               = '/success:enable /failure:enable'
    'Account Lockout'                = '/success:enable'
    'Logoff'                         = '/success:enable'
    'Logon'                          = '/success:enable /failure:enable'
    'Other Logon/Logoff Events'      = '/success:enable /failure:enable'
    'Special Logon'                  = '/success:enable'
    'Audit Policy Change'            = '/success:enable /failure:enable'
    'Authentication Policy Change'   = '/success:enable /failure:enable'
    'Other System Events'            = '/success:enable /failure:enable'
    'Security State Change'          = '/success:enable /failure:enable'
}

foreach ($Subcategory in $AuditPolicy.Keys) {
    $Flags = $AuditPolicy[$Subcategory]
    $Command = "auditpol /set /subcategory:`"$Subcategory`" $Flags"

    try {
        Invoke-Expression $Command | Out-Null
        Write-Host "Audit enabled: $Subcategory"
    }
    catch {
        Write-Error "Failed to set audit policy for '$Subcategory': $_"
    }
}

# Include command line in process creation events (4688).
# Without this, Process Creation events record the executable but not its arguments -
# which means you lose exactly the detail that mattered most in the Windows IR
# investigation (the -ExecutionPolicy Bypass -WindowStyle Hidden flags).
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit' `
    -Name 'ProcessCreationIncludeCmdLine_Enabled' -Value 1 -Type DWord -Force `
    -ErrorAction SilentlyContinue
Write-Host 'Enabled command-line capture in process creation events'

Write-Host "`nCurrent audit policy:"
auditpol /get /category:* | Select-String -Pattern 'Success|Failure'
