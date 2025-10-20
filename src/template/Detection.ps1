# ------------------------------------------------------------------------------
# Detection script to check if a WinGet package is installed and whether it needs
# to be updated or repaired using PowerShell v7.
# 
# This script addresses the issue that WinGet cmdlets do not work properly when
# run under SYSTEM context in PowerShell v5 (see https://github.com/microsoft/winget-cli/issues/4820).
#
# The script:
# - Uses PowerShell 7 explicitly to run WinGet commands.
# - Checks if the required PowerShell 7 executable is present.
# - Attempts to import or install/update the Microsoft.WinGet.Client module.
# - Repairs the WinGet Package Manager if necessary.
# - Retrieves the currently installed package info by ID.
# - Compares installed version with desired version or checks for updates.
# - Outputs status messages with timestamps.
# - Uses transcript logging for detailed record of execution.
# ------------------------------------------------------------------------------

# ---------------------------
# Define the WinGet package ID and version to check
# Set $Id to the WinGet package identifier (e.g., 'notepad++.notepad++'). Use winget search <AppName> to get the ID
# Set $Version to the specific version string or 'Latest' to always check for updates.
# ---------------------------
$Id = '<Replace me:Id>' #this is replaced by the form with the winget ID from the app they choose on the form.
$Version = '<Replace me:Version>' # Example: '8.7.8' or 'Latest'

# ---------------------------
# Function: Get-IntuneTenantName
# Attempts to retrieve the Intune tenant name for the current user by querying
# the registry path where enrollment information is stored.
# Returns the tenant name or $null if not found or on error.
# ---------------------------
function Get-IntuneTenantName {
    try {
        $enrollmentsPath = "HKLM:\\SOFTWARE\\Microsoft\\Enrollments"
        $enrollmentKeys = Get-ChildItem -Path $enrollmentsPath -ErrorAction SilentlyContinue

        foreach ($key in $enrollmentKeys) {
            # Try to read the UPN property which contains the user principal name (email)
            $upn = (Get-ItemProperty -Path $key.PSPath -Name "UPN" -ErrorAction SilentlyContinue).UPN

            if ($upn) {
                # Extract the domain part of the UPN which corresponds to the tenant name
                $tenantName = $upn -replace '.*@', ''
                return $tenantName
            }
        }

        # Tenant name not found in registry
        Write-Output "Could not find Intune tenant name in registry"
        return $null
    }
    catch {
        # Log error and return null
        Write-Output "Error getting Intune tenant name: $_"
        return $null
    }
}

# ---------------------------
# Retrieve and store the Intune tenant name for use in log paths
# ---------------------------
$intuneTenantName = Get-IntuneTenantName
if ([string]::IsNullOrWhiteSpace($intuneTenantName)) {
    $intuneTenantName = "<Replace me:Organization>" # This is replaced by the domain prompt on the form
}

# ---------------------------
# Start transcript logging to capture detailed output and errors
# Log file path includes tenant name, computer name, and Id for uniqueness.
# Transcript overwrites the log file each time instead of appending.
# ---------------------------
$logPath = "C:\ProgramData\$intuneTenantName\$env:COMPUTERNAME"
if (-not (Test-Path -Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath -Force | Out-Null
}
$transcriptFile = Join-Path -Path $logPath -ChildPath "$($Id)detection.txt"

# Remove existing log file if it exists to avoid appending
if (Test-Path -Path $transcriptFile) {
    Remove-Item -Path $transcriptFile -Force
}

Start-Transcript -Path $transcriptFile -Force

# ---------------------------
# Verify that PowerShell 7 (pwsh.exe) exists in the expected location
# If missing, log error and exit with code 1 to indicate failure
# ---------------------------
if (-not (Test-Path -LiteralPath 'C:\Program Files\PowerShell\7\pwsh.exe')) {
    Write-Host ("{0} - PowerShell v7 was not found at 'C:\Program Files\PowerShell\7\pwsh.exe', exiting..." -f $(Get-Date -Format "dd-MM-yy HH:mm"))
    Stop-Transcript
    exit 1
}

# ---------------------------
# Function: Search-RegistryForApp
# Searches registry uninstall keys for an app by display name
# Returns $true if found, $false otherwise
# ---------------------------
function Search-RegistryForApp {
    param(
        [string]$AppName
    )
    $foundKeys = @()
    $uninstallPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($path in $uninstallPaths) {
        $keys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
        foreach ($key in $keys) {
            $displayName = (Get-ItemProperty -Path $key.PSPath -Name 'DisplayName' -ErrorAction SilentlyContinue).DisplayName
            if ($displayName -and $displayName -like "*$AppName*") {
                $foundKeys += $key.PSPath
            }
        }
    }
    return $foundKeys
}

# ---------------------------
# Function: Search-FileSystemForApp
# Checks common install locations for a folder or executable matching the app name
# Returns $true if found, $false otherwise
# ---------------------------
function Search-FileSystemForApp {
    param(
        [string]$AppName
    )
    $foundPaths = @()
    $locations = @(
        "$env:ProgramFiles",
        "$env:ProgramFiles (x86)",
        "$env:LOCALAPPDATA",
        "$env:ProgramFiles\WindowsApps"
    )
    foreach ($loc in $locations) {
        if (Test-Path $loc) {
            $items = Get-ChildItem -Path $loc -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$AppName*" }
            foreach ($item in $items) {
                $foundPaths += $item.FullName
            }
            $exes = Get-ChildItem -Path $loc -Recurse -Filter "*.exe" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$AppName*.exe" }
            foreach ($exe in $exes) {
                $foundPaths += $exe.FullName
            }
        }
    }
    return $foundPaths
}

# ---------------------------
# Pre-WinGet detection: Try to get Name from WinGet, else fallback to Id
# ---------------------------
$Name = $null
$software = & 'C:\Program Files\PowerShell\7\pwsh.exe' -MTA -Command {
    try {
        if (Get-Module Microsoft.WinGet.Client -ListAvailable) {
            $latestAvailable = (Find-Module Microsoft.WinGet.Client).Version
            $installedVersion = (Get-Module Microsoft.WinGet.Client -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version
            if ($installedVersion -lt $latestAvailable) {
                Update-Module Microsoft.WinGet.Client -Force:$true -Confirm:$false -Scope AllUsers
            }
        }
        Import-Module Microsoft.WinGet.Client -ErrorAction Stop
    } catch {
        Install-Module Microsoft.WinGet.Client -Force:$true -Confirm:$false -Scope AllUsers
        Import-Module Microsoft.WinGet.Client
    }
    try {
        Assert-WinGetPackageManager -ErrorAction Stop
    } catch {
        Repair-WinGetPackageManager -AllUsers -Force:$true -Latest:$true
    }
    Get-WinGetPackage -Source WinGet
} | Where-Object Id -EQ $Id

if ($null -ne $software) {
    $Name = $software.Name
} else {
    $Name = $Id
}

# ---------------------------
# Check registry and file system for app presence using $Name
# If found, log and exit 0 (treat as installed)
# ---------------------------
$foundRegistryKeys = @()
$foundFSPaths = @()
if ($Name) {
    $foundRegistryKeys = Search-RegistryForApp -AppName $Name
    $foundFSPaths = Search-FileSystemForApp -AppName $Name
}
if ($foundRegistryKeys.Count -gt 0 -or $foundFSPaths.Count -gt 0) {
    if ($foundRegistryKeys.Count -gt 0) {
        Write-Host ("{0} - {1} was found in the registry at the following keys:" -f $(Get-Date -Format "dd-MM-yy HH:mm"), $Name)
        foreach ($key in $foundRegistryKeys) {
            Write-Host $key
        }
    }
    if ($foundFSPaths.Count -gt 0) {
        Write-Host ("{0} - {1} was found in the file system at the following paths:" -f $(Get-Date -Format "dd-MM-yy HH:mm"), $Name)
        foreach ($path in $foundFSPaths) {
            Write-Host $path
        }
    }
    Stop-Transcript
    exit 0
}

# ---------------------------
# Compare the installed package version with the desired version
# Two scenarios:
# - Specific version requested (not 'Latest')
# - Latest version requested
# Depending on comparison, exit with code 0 (no action needed) or 1 (install/update needed)
# ---------------------------

if ($Version -ne 'Latest') {
    # Convert versions to [version] type for accurate comparison
    if ([version]$Version -le [version]$software.InstalledVersion) {
        # Installed version is same or newer than requested - no update needed
        Write-Host ("{0} - Installed version {1} of {2} is higher or equal than specified version {3}, nothing to do..." -f $(Get-Date -Format "dd-MM-yy HH:mm"), [version]$software.InstalledVersion, $Id, [version]$Version)
        Stop-Transcript
        exit 0
    }
    if ([version]$Version -gt [version]$software.InstalledVersion) {
        # Installed version is older than requested - update required
        Write-Host ("{0} - {1} version is {2}, which is lower than specified {3} version, updating now..." -f $(Get-Date -Format "dd-MM-yy HH:mm"), $Id, $software.InstalledVersion, $Version)
        Stop-Transcript
        exit 1
    }
}

if ($Version -eq 'Latest') {
    if ($software.IsUpdateAvailable -eq $false) {
        # Latest version is already installed - no update needed
        Write-Host ("{0} - {1} version is current (Version {2}), nothing to do..." -f $(Get-Date -Format "dd-MM-yy HH:mm"), $Id, $software.InstalledVersion)
        Stop-Transcript
        exit 0
    }
    else {
        # Update available - install the update
        Write-Host ("{0} - {1} was found with version {2}, but there's an update available for it ({3}), updating now..." -f $(Get-Date -Format "dd-MM-yy HH:mm"), $Id, $software.InstalledVersion, $($software.AvailableVersions | Select-Object -First 1))
        Stop-Transcript
        exit 1
    }
}
