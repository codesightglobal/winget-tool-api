<#
.SYNOPSIS
    Install or uninstall a WinGet package with robust logging and optional extras.

.DESCRIPTION
    Intune-friendly script to manage an application via WinGet. It:
    - Accepts a package `Id` and `Version` (supports "Latest").
    - Runs in either install or uninstall mode.
    - Writes a transcript to C:\ProgramData\<tenant>\<device>\<id>_(install|uninstall).txt.
    - Attempts to detect the Intune tenant from the registry, with fallback.
    - Optionally executes a sibling Custom.ps1 for app-specific steps when present.
    - Optionally uploads the log file to Azure Blob Storage using AzCopy when configured.

.EXAMPLE
    .\WinGet.ps1 -Id "Vendor.App" -Version "Latest" -Install -Verbose

.NOTES
    Author: Damien Cresswell, Sistena LTD.
    Last Edit: 23-09-2025
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

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    # Don't try to write to log file during transcript - it's already being captured
}

$deviceName = $env:COMPUTERNAME

# start of section to be removed if they select to not use azure blob storage for their logs
$azCopyUrl = "https://aka.ms/downloadazcopy-v10-windows"
$azCopyExtractPath = "$env:TEMP\azcopy"
$azCopyExe = Join-Path $azCopyExtractPath "azcopy_windows_amd64_10.28.1\azcopy.exe"

<# If you would like to use azure blob storage for your logs, then this section needs to be uncommented and the variables populated

# Use URL-encoded container name to ensure proper parsing by AzCopy.
$blobBaseUrl = '<blob base url>' # <> This will be captured during the form and then changed to the captured information if they select to use azure blob storage for their logs   
$sasToken = "<sas token>" # <> This will be captured during the form and then changed to the captured information if they select to use azure blob storage for their logs

#>

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
    $intuneTenantName = "<tenant domain>" # <> This will be captured during the form and then changed to the captured information
}

# Construct log path based on action
if ($Install) {
    $logPath = "C:\ProgramData\$intuneTenantName\$env:COMPUTERNAME\$($Id)_install.txt"
    $blobOption = "_install"
} elseif ($Uninstall) {
    $logPath = "C:\ProgramData\$intuneTenantName\$env:COMPUTERNAME\$($Id)_uninstall.txt"
    $blobOption = "_uninstall"
} else {
    $logPath = "C:\ProgramData\$intuneTenantName\$env:COMPUTERNAME\$($Id)_log.txt"
    $blobOption = "_log"
}

# Ensure the directory exists
$logDir = Split-Path -Path $logPath -Parent
if (-not (Test-Path -Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

Start-Transcript -Path $logPath -Append -Force
$logFile = $logPath

Import-Module Microsoft.WinGet.Client -ErrorAction Stop
Write-Verbose ("{0} - Imported Microsoft.WinGet.Client module" -f (Get-Date -Format "dd-MM-yy HH:mm"))

$operationError = $null

Write-Log ("[DEBUG] Script started with parameters: Id=$Id, Version=$Version, Install=$Install, Uninstall=$Uninstall")
if ($Install) {
    Write-Log ("[DEBUG] Install mode selected")
    try {
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
                }
            } catch {
                # Continue retrying if not found yet
            }
        }

        if (-not $success) {
            Write-Verbose ("{0} - Package {1} not found after install retries" -f (Get-Date -Format "dd-MM-yy HH:mm"), $Id)
            # throw "Installation failed or package verification unsuccessful."
            Write-Log "[DEBUG] Installation failed or package verification unsuccessful."
            $operationError = "Installation failed or package verification unsuccessful."
        }

        Write-Verbose ("{0} - Successfully installed {1} version {2}" -f (Get-Date -Format "dd-MM-yy HH:mm"), $Id, $Version)
    } catch {
        $operationError = $_
        Write-Log ("[DEBUG] Exception occurred during install: $($_.Exception.Message)")
        Write-Verbose ("{0} - Exception occurred during install: $($_.Exception.Message)" -f (Get-Date -Format "dd-MM-yy HH:mm"))
    }
}

if ($Uninstall) {
    Write-Log ("[DEBUG] Uninstall mode selected")
    try {
        Write-Verbose ("{0} - Attempting to uninstall {1}" -f (Get-Date -Format "dd-MM-yy HH:mm"), $Id)
        Uninstall-WinGetPackage -Id $Id -Force -Mode Silent -ErrorAction Stop
        Write-Verbose ("{0} - Successfully uninstalled {1}" -f (Get-Date -Format "dd-MM-yy HH:mm"), $Id)
    } catch {
        $operationError = $_
        Write-Log ("[DEBUG] Exception occurred during uninstall: $($_.Exception.Message)")
        Write-Verbose ("{0} - Exception occurred during uninstall: $($_.Exception.Message)" -f (Get-Date -Format "dd-MM-yy HH:mm"))
    }
}

# Run custom script if present
if (Test-Path .\Custom.ps1) {
    try {
        Write-Log ("[DEBUG] Custom.ps1 found, attempting to run")
        if ($Install) {
            Write-Log ("[DEBUG] Running Custom.ps1 for install")
            .\Custom.ps1 -Id $Id -Install -Verbose
        } elseif ($Uninstall) {
            Write-Log ("[DEBUG] Running Custom.ps1 for uninstall")
            .\Custom.ps1 -Id $Id -Uninstall -Verbose
        }
    } catch {
        $operationError = $_
        Write-Log ("[DEBUG] Error running Custom.ps1: $($_.Exception.Message)")
        Write-Verbose ("{0} - Error running Custom.ps1: $($_.Exception.Message)" -f (Get-Date -Format "dd-MM-yy HH:mm"))
    }
}

Stop-Transcript
Start-Sleep -Seconds 5

<# If you would like to use azure blob storage for your logs, then this section needs to be uncommented

# Verify the log file exists before attempting upload if they select to not use azure blob storage for their logs, then this will not be used and needs to be removed
if (-not (Test-Path -Path $logFile)) {
    Write-host "ERROR: Log file $logFile does not exist. Upload will be skipped."
    exit 1
}

# Upload log via AzCopy
Write-host "----- Starting AzCopy log upload -----"

# Construct the target URL
$blobTarget = "$blobBaseUrl/$deviceName/$Id$blobOption.txt?$sasToken"
Write-host "Target URL: $blobTarget"
Write-host "AzCopy Exe Path: $azCopyExe"

# Download AzCopy if not available at the expected path
if (-not (Test-Path -Path $azCopyExe)) {
    Write-host "AzCopy not found at expected path. Downloading..."
    try {
        $azCopyZip = "$env:TEMP\azcopy.zip"
        Invoke-WebRequest -Uri $azCopyUrl -OutFile $azCopyZip -UseBasicParsing
        Expand-Archive -Path $azCopyZip -DestinationPath $azCopyExtractPath -Force
        Write-host "AzCopy downloaded and extracted."

        # Find azcopy.exe dynamically in the extraction path
        $foundAzCopy = Get-ChildItem -Path $azCopyExtractPath -Recurse -Filter "azcopy.exe" | Select-Object -First 1
        if ($foundAzCopy) {
            $azCopyExe = $foundAzCopy.FullName
            Write-host "AzCopy.exe found at: $azCopyExe"
        } else {
            Write-host "AzCopy.exe not found after extraction."
        }
    } catch {
        Write-host "AzCopy download or extraction failed: $_"
    }
}

# Recheck and upload if AzCopy exists
if (Test-Path -Path $azCopyExe) {
    $azCommand = "`"$azCopyExe`" copy `"$logFile`" `"$blobTarget`" --overwrite=true --log-level=INFO"
    # For even more details during troubleshooting, you could use: --log-level=DEBUG
    Write-host "Executing AzCopy upload command: $azCommand"

    try {
        $upload = Start-Process -FilePath $azCopyExe -ArgumentList @("copy", "$logFile", "$blobTarget", "--overwrite=true", "--log-level=INFO") -NoNewWindow -Wait -PassThru
        if ($upload.ExitCode -eq 0) {
            Write-host "AzCopy log upload successful."
        } else {
            Write-host "AzCopy failed with exit code $($upload.ExitCode)."
        }
    } catch {
        Write-host "AzCopy execution failed: $_"
    }
} else {
    Write-host "AzCopy not available. Log upload skipped. Final AzCopy path checked: $azCopyExe"
} # end of section to be removed if they select to not use azure blob storage for their logs

# Exit with appropriate code
if ($operationError) {
    Write-Host "not successful"
    exit 1
} else {
    Write-Host "successful"
    exit 0
}
    #>