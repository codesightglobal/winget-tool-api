<#
.SYNOPSIS
[INSTRUCTION: Briefly describe what this script will do for the specific application, e.g., "Installs or uninstalls <AppName> using WinGet, with detailed logging for Intune deployments."]

.DESCRIPTION
[INSTRUCTION: Provide a detailed description of the script's purpose and behavior. Include details such as:
- The app this script is for (replace <AppName> with the actual app name).
- How it determines the Intune tenant name and constructs log file paths.
- That it supports both installation and uninstallation actions.
- That it can invoke a Custom.ps1 script for additional logic if present.
- Any other app-specific logic or requirements.]

.NOTES
Author: [Your Name or Team]
Last edit: [Date]
[INSTRUCTION: Update author and date as appropriate for each new app/script.]
#>

[CmdletBinding(DefaultParameterSetName = 'None', SupportsShouldProcess = $true)]
param (
    [parameter(Mandatory = $true)][string]$Id,
    [parameter(Mandatory = $true, ParameterSetName = 'Install')][string]$Version,
    [parameter(Mandatory = $true, ParameterSetName = 'Install')][switch]$Install,
    [parameter(Mandatory = $true, ParameterSetName = 'Uninstall')][switch]$Uninstall
)

# Force terminating errors and enable WinGet diagnostics
$ErrorActionPreference = 'Stop'
$env:WINGET_DIAGNOSTICS = "1"

function Get-IntuneTenantName {
    try {
        $enrollmentsPath = "HKLM:\SOFTWARE\Microsoft\Enrollments"
        $enrollmentKeys = Get-ChildItem -Path $enrollmentsPath -ErrorAction SilentlyContinue
        foreach ($key in $enrollmentKeys) {
            $upn = (Get-ItemProperty -Path $key.PSPath -Name "UPN" -ErrorAction SilentlyContinue).UPN
            if ($upn) {
                return ($upn -replace '.*@', '')
            }
        }
        Write-Verbose "Could not find Intune tenant name in registry"
        return $null
    } catch {
        Write-Verbose "Error getting Intune tenant name: $($_ | Out-String)"
        return $null
    }
}

# Get tenant name (or fallback to 'UnknownTenant')
$intuneTenantName = Get-IntuneTenantName
if ([string]::IsNullOrWhiteSpace($intuneTenantName)) {
    $intuneTenantName = "<Replace me>"
}

# Construct log path based on action
if ($Install) {
    $logPath = "C:\ProgramData\$intuneTenantName\$env:COMPUTERNAME\$($Id)_install.txt"
} elseif ($Uninstall) {
    $logPath = "C:\ProgramData\$intuneTenantName\$env:COMPUTERNAME\$($Id)_uninstall.txt"
} else {
    $logPath = "C:\ProgramData\$intuneTenantName\$env:COMPUTERNAME\$($Id)_log.txt"
}

# Ensure the directory exists
$logDir = Split-Path -Path $logPath -Parent
if (-not (Test-Path -Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

Start-Transcript -Path $logPath -Append -Force

# Ensure winget packagemanager is fully working and set to use repository for module imports
$progressPreference = 'silentlyContinue'
Write-Host "Installing WinGet PowerShell module from PSGallery..."
Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery | Out-Null
Write-Host "Using Repair-WinGetPackageManager cmdlet to bootstrap WinGet..."
Repair-WinGetPackageManager -AllUsers
Write-Host "Done."

Import-Module Microsoft.WinGet.Client -ErrorAction Stop
Write-Verbose ("{0} - Imported Microsoft.WinGet.Client module" -f (Get-Date -Format "dd-MM-yy HH:mm"))

try {
    if ($Install) {
        if ($Version -eq 'Latest') {
            Write-Verbose ("{0} - Installing latest version of {1}" -f (Get-Date -Format "dd-MM-yy HH:mm"), $Id)
            Install-WinGetPackage -Id $Id -Force -MatchOption EqualsCaseInsensitive -ErrorAction Stop
        } else {
            Write-Verbose ("{0} - Installing version {1} of {2}" -f (Get-Date -Format "dd-MM-yy HH:mm"), $Version, $Id)
            Install-WinGetPackage -Id $Id -Version $Version -Force -Mode Silent -MatchOption EqualsCaseInsensitive -Scope SystemOrUnknown -Source WinGet -ErrorAction Stop
        }

        # Retry loop to verify package presence after install (5 attempts, 3 sec delay)
        $maxRetries = 5
        $success = $false
        for ($i = 0; $i -lt $maxRetries; $i++) {
            Start-Sleep -Seconds 3
            Write-Verbose ("{0} - Verifying installation attempt {1} for package {2}" -f (Get-Date -Format "dd-MM-yy HH:mm"), ($i+1), $Id)

            try {
                $pkg = Get-WinGetPackage -Id $Id -MatchOption EqualsCaseInsensitive -ErrorAction Stop
                if ($pkg) {
                    $success = $true
                    break
                }
            } catch {
                # Continue retrying if not found yet
            }
        }

        if (-not $success) {
            Write-Verbose ("{0} - Package {1} not found after install retries" -f (Get-Date -Format "dd-MM-yy HH:mm"), $Id)
            throw "Installation failed or package verification unsuccessful."
        }

        Write-Verbose ("{0} - Successfully installed {1} version {2}" -f (Get-Date -Format "dd-MM-yy HH:mm"), $Id, $Version)
    }

    if ($Uninstall) {
        Write-Verbose ("{0} - Attempting to uninstall {1}" -f (Get-Date -Format "dd-MM-yy HH:mm"), $Id)
        Uninstall-WinGetPackage -Id $Id -Force -Mode Silent -ErrorAction Stop
        Write-Verbose ("{0} - Successfully uninstalled {1}" -f (Get-Date -Format "dd-MM-yy HH:mm"), $Id)
    }

} catch {
    Write-Verbose ("{0} - Exception occurred: $($_.Exception.Message)" -f (Get-Date -Format "dd-MM-yy HH:mm"))
    Write-Verbose ("Full error: $($_ | Out-String)")
    Stop-Transcript
    exit 1
}

# Run custom script if present
if (Test-Path .\Custom.ps1) {
    try {
        if ($Install) {
            Write-Verbose ("{0} - Running Custom.ps1 for install" -f (Get-Date -Format "dd-MM-yy HH:mm"))
            .\Custom.ps1 -Id $Id -Install -Verbose
        } elseif ($Uninstall) {
            Write-Verbose ("{0} - Running Custom.ps1 for uninstall" -f (Get-Date -Format "dd-MM-yy HH:mm"))
            .\Custom.ps1 -Id $Id -Uninstall -Verbose
        }
    } catch {
        Write-Verbose ("{0} - Error running Custom.ps1: $($_.Exception.Message)" -f (Get-Date -Format "dd-MM-yy HH:mm"))
        Stop-Transcript
        exit 1
    }
}

Stop-Transcript
exit 0
