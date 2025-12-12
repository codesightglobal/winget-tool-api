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

<# uncomment if you want to use AzCopy to upload the log file
$azCopyUrl = "https://aka.ms/downloadazcopy-v10-windows"
$azCopyExtractPath = "$env:TEMP\azcopy"
$azCopyExe = Join-Path $azCopyExtractPath "azcopy_windows_amd64_10.28.1\azcopy.exe"
# Use URL-encoded container name to ensure proper parsing by AzCopy
$blobBaseUrl = '<replace with blob base url>'
$sasToken = "<replace with sas token>" #>

# Enhanced logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    # Don't try to write to log file during transcript - it's already being captured
}

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

# Get tenant name (or fallback to '<Replace me:Organization>')
$intuneTenantName = Get-IntuneTenantName
if ([string]::IsNullOrWhiteSpace($intuneTenantName)) {
    $intuneTenantName = "<Replace me:Organization>"
}

# Construct log path based on action
if ($Install) {
    $logPath = "C:\ProgramData\$intuneTenantName\$env:COMPUTERNAME\$($Id)_install.txt"
    #$blobOption = "_install" uncomment if you want to use AzCopy to upload the log file
} elseif ($Uninstall) {
    $logPath = "C:\ProgramData\$intuneTenantName\$env:COMPUTERNAME\$($Id)_uninstall.txt"
    #$blobOption = "_uninstall" uncomment if you want to use AzCopy to upload the log file
} else {
    $logPath = "C:\ProgramData\$intuneTenantName\$env:COMPUTERNAME\$($Id)_log.txt"
    #$blobOption = "_log" uncomment if you want to use AzCopy to upload the log file
}

# Ensure the directory exists   
$logDir = Split-Path -Path $logPath -Parent
if (-not (Test-Path -Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

Start-Transcript -Path $logPath -Force
# $logFile = $logPath uncomment if you want to use AzCopy to upload the log file

# Locate winget.exe path
$wingetPath = Get-ChildItem -Path "$Env:ProgramFiles\WindowsApps" -Directory |
Where-Object { $_.Name -like "Microsoft.DesktopAppInstaller_*" } |
ForEach-Object { Join-Path $_.FullName "winget.exe" } |
Where-Object { Test-Path $_ } |
Select-Object -First 1

$operationError = $null
Write-Log ("[DEBUG] Script started with parameters: Id=$Id, Version=$Version, Install=$Install, Uninstall=$Uninstall")
if ($Install) {
    Write-Log ("[DEBUG] Install mode selected")
    try {
        if ($Version -eq 'Latest') {
            Write-Verbose ("{0} - Installing latest version of {1}" -f (Get-Date -Format "dd-MM-yy HH:mm"), $Id)
            Start-Process $wingetPath -ArgumentList "install --id $Id --exact --source winget --accept-source-agreements --disable-interactivity --scope machine --silent --accept-package-agreements --force" -NoNewWindow -Wait
            Write-Verbose ("{0} - Successfully installed {1} version {2}" -f (Get-Date -Format "dd-MM-yy HH:mm"), $Id, $Version)
        } else {
            Write-Verbose ("{0} - Installing version {1} of {2}" -f (Get-Date -Format "dd-MM-yy HH:mm"), $Version, $Id)
            Start-Process $wingetPath -ArgumentList "install --id $Id --exact --source winget --accept-source-agreements --disable-interactivity --scope machine --silent --accept-package-agreements --force" -NoNewWindow -Wait
            Write-Verbose ("{0} - Successfully installed {1} version {2}" -f (Get-Date -Format "dd-MM-yy HH:mm"), $Id, $Version)
        }
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
        Start-Process $wingetPath -ArgumentList "uninstall --id $Id --exact --source winget --accept-source-agreements --disable-interactivity --scope machine --silent" -Wait
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

<# uncomment if you want to use AzCopy to upload the log file
#Verify the log file exists before attempting upload
if (-not (Test-Path -Path $logFile)) {
    Write-Log "ERROR: Log file $logFile does not exist. Upload will be skipped."
    exit 1
}

# Upload log via AzCopy
Write-Log "----- Starting AzCopy log upload -----"

# Construct the target URL
$blobTarget = "$blobBaseUrl/$deviceName/$Id$blobOption.txt?$sasToken"
Write-Log "Target URL: $blobTarget"
Write-Log "AzCopy Exe Path: $azCopyExe"

# Download AzCopy if not available at the expected path
if (-not (Test-Path -Path $azCopyExe)) {
    Write-Log "AzCopy not found at expected path. Downloading..."
    try {
        $azCopyZip = "$env:TEMP\azcopy.zip"
        Invoke-WebRequest -Uri $azCopyUrl -OutFile $azCopyZip -UseBasicParsing
        Expand-Archive -Path $azCopyZip -DestinationPath $azCopyExtractPath -Force
        Write-Log "AzCopy downloaded and extracted."

        # Find azcopy.exe dynamically in the extraction path
        $foundAzCopy = Get-ChildItem -Path $azCopyExtractPath -Recurse -Filter "azcopy.exe" | Select-Object -First 1
        if ($foundAzCopy) {
            $azCopyExe = $foundAzCopy.FullName
            Write-Log "AzCopy.exe found at: $azCopyExe"
        } else {
            Write-Log "AzCopy.exe not found after extraction."
        }
    } catch {
        Write-Log "AzCopy download or extraction failed: $_"
    }
}

# Recheck and upload if AzCopy exists
if (Test-Path -Path $azCopyExe) {
    $azCommand = "`"$azCopyExe`" copy `"$logFile`" `"$blobTarget`" --overwrite=true --log-level=INFO"
    # For even more details during troubleshooting, you could use: --log-level=DEBUG
    Write-Log "Executing AzCopy upload command: $azCommand"

    try {
        $upload = Start-Process -FilePath $azCopyExe -ArgumentList @("copy", "$logFile", "$blobTarget", "--overwrite=true", "--log-level=INFO") -NoNewWindow -Wait -PassThru
        if ($upload.ExitCode -eq 0) {
            Write-Log "AzCopy log upload successful."
        } else {
            Write-Log "AzCopy failed with exit code $($upload.ExitCode)."
        }
    } catch {
        Write-Log "AzCopy execution failed: $_"
    }
} else {
    Write-Log "AzCopy not available. Log upload skipped. Final AzCopy path checked: $azCopyExe"
}

# Exit with appropriate code
if ($operationError) {
    Write-Log "not successful"
    exit 1
} else {
    Write-Log "successful"
    exit 0
} #>
