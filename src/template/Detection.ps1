<# ------------------------------------------------------------------------------
# .SYNOPSIS
    Detection script for WinGet packages to be used with Microsoft Intune

.DESCRIPTION
    This script detects if a specified WinGet package is installed and at the correct version.
    It uses PowerShell v7 to interact with WinGet as the cmdlets don't work in SYSTEM context with PowerShell v5.
    The script will exit with code 1 if the package needs to be installed/updated, or 0 if no action is needed.

# .EXAMPLE
    .\testdet.ps1

# .NOTES
    Author: Damien Cresswell, Sistena LTD.
    Last Edit: 08-10-2025
------------------------------------------------------------------------------ #>

#Running Get-WinGetPackage and Repair-WinGetPackageManager in PowerShell v7 because the WinGet cmdlets don't work in SYSTEM context in PowerShell v5
#See https://github.com/microsoft/winget-cli/issues/4820
#Supply the ID and version of the WinGet package here, use Latest if version is not important
#For example $Id = 'notepad++.notepad++' / $Version = '8.7.8' or $Id = '7zip.7zip' / $Version = 'Latest'
$Id = '<Replace me:Id>'
$Version = '<Replace me:Version>'

 # Function to fetch intune enrolled tenant name
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

# Get tenant name (or fallback to 'AppLogs')
$intuneTenantName = Get-IntuneTenantName
if ([string]::IsNullOrWhiteSpace($intuneTenantName)) {
    $intuneTenantName = "<Replace me:Organization>" # replace with your tenant domain (e.g. 'contoso.onmicrosoft.com')
}

# Define product name for log path
$productName = $Id -replace '\.', '_'

# Construct log path based on action
$logPath = "C:\ProgramData\$intuneTenantName\$env:COMPUTERNAME\$($productName)_Detection.txt"
Start-Transcript -Path $logPath -Force

#Check if PowerShell v7 is installed before continuing the Detection
if (-not (Test-Path -LiteralPath 'C:\Program Files\PowerShell\7\pwsh.exe')) {
    Write-Host ("{0} - PowerShell v7 was not found at 'C:\Program Files\PowerShell\7\pwsh.exe', exiting..." -f $(Get-Date -Format "dd-MM-yy HH:mm"))
    Stop-Transcript
    exit 1
}

#Check if software is installed
Write-Host "Starting PowerShell v7 subprocess to check WinGet package..."
Write-Host "Checking for package ID: $Id"

# Create a temporary script file for PowerShell v7
$tempScript = @"
#Import the Microsoft.WinGet.Client module, install it if it's not found or update if outdated
try {
    if (Get-Module Microsoft.WinGet.Client -ListAvailable) {
        if ((Get-Module Microsoft.WinGet.Client -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version -lt (Find-Module Microsoft.WinGet.Client).Version) {
            Update-Module Microsoft.WinGet.Client -Force:`$true -Confirm:`$false -Scope AllUsers
        }
    }
    Import-Module Microsoft.WinGet.Client -ErrorAction Stop
    Write-Host `"Module loaded successfully`"
}
catch {
    Install-Module Microsoft.WinGet.Client -Force:`$true -Confirm:`$false -Scope AllUsers
    Import-Module Microsoft.WinGet.Client
    Write-Host `"Module installed and loaded`"
}

#Repair/Install WinGetPackagemanager if not found
try {
    Assert-WinGetPackageManager -ErrorAction Stop
    Write-Host `"WinGet package manager is working`"
}
catch {
    Repair-WinGetPackageManager -AllUsers -Force:`$true -Latest:`$true
    Write-Host `"WinGet package manager repaired`"
}

#Get the WinGetPackage details and return only the object
Write-Host `"Searching for package: '$Id'`"
`$allPackages = Get-WinGetPackage -Source WinGet -ErrorAction SilentlyContinue
Write-Host `"Total packages found: `$(`$allPackages.Count)`"

`$package = Get-WinGetPackage -Id '$Id' -Source WinGet -ErrorAction SilentlyContinue | Select-Object -First 1
Write-Host `"Package found: `$(`$package -ne `$null)`"

if (`$package) {
    Write-Host `"Package details: `$(`$package.Name) - Version: `$(`$package.InstalledVersion) - Update Available: `$(`$package.IsUpdateAvailable)`"
    # Return the object as JSON to preserve the object structure
    `$result = [PSCustomObject]@{
        InstalledVersion = `$package.InstalledVersion
        IsUpdateAvailable = `$package.IsUpdateAvailable
        AvailableVersions = `$package.AvailableVersions 
    }
    # Convert to JSON and return as string to preserve object structure
    ConvertTo-Json -InputObject `$result -Compress
} else {
    Write-Host `"No package found with ID: '$Id'`"
    `$null
}
"@

$tempScriptPath = [System.IO.Path]::GetTempFileName() + ".ps1" # Create a temporary script file for PowerShell v7
$tempScript | Out-File -FilePath $tempScriptPath -Encoding UTF8 # Write the script to the temporary file

try {
    $output = & 'C:\Program Files\PowerShell\7\pwsh.exe' -MTA -File $tempScriptPath # Run the script
    Write-Host "Raw output from PowerShell v7:"
    $output | ForEach-Object { Write-Host "  $_" }
    
    # Find the JSON string in the output and deserialize it back to an object
    $jsonString = $output | Where-Object { $_ -ne $null -and $_ -ne "" -and $_.StartsWith('{') -and $_.EndsWith('}') } | Select-Object -First 1 # Find the JSON string in the output
    
    if ($jsonString) {
        try {
            $software = $jsonString | ConvertFrom-Json # Convert the JSON string to an object
            Write-Host "Successfully deserialized JSON to object"
        } catch {
            Write-Host "Failed to deserialize JSON: $_"
            $software = $null # Set the software object to null
        }
    } else {
        Write-Host "No JSON string found in output"
        $software = $null # Set the software object to null
    }
} finally {
    # Clean up temp file
    if (Test-Path $tempScriptPath) { # Clean up temp file
        Remove-Item $tempScriptPath -Force
    }
}

Write-Host "PowerShell v7 subprocess completed."
if ($software) {
    Write-Host "Software object type: $($software.GetType().FullName)" # Write the software object type to the log
    Write-Host "Software object value: $software" # Write the software object value to the log
    if ($software.GetType().Name -eq 'PSCustomObject') {
        Write-Host "Software object properties: $($software | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)" # Write the software object properties to the log
        Write-Host "InstalledVersion: $($software.InstalledVersion)" # Write the installed version to the log
        Write-Host "IsUpdateAvailable: $($software.IsUpdateAvailable)" # Write the update available status to the log
    }
} else {
    Write-Host "Software object is null - package not found" # Write a message to the log if the software object is null
}

# Locate winget.exe path
$wingetPath = Get-ChildItem -Path "$Env:ProgramFiles\WindowsApps" -Directory | # Get the winget.exe path
    Where-Object { $_.Name -like "Microsoft.DesktopAppInstaller_*" } | # Where the name of the directory is like Microsoft.DesktopAppInstaller_*
    ForEach-Object { Join-Path $_.FullName "winget.exe" } | # Join the path to the winget.exe
    Where-Object { Test-Path $_ } | # Where the path exists
    Select-Object -First 1 # Select the first item

Write-Host "wingetPath resolved to: $wingetPath" # Write the winget.exe path to the log if it was found

if (-not $wingetPath) {
    Write-Error "winget.exe not found."
    Write-Host "Please install the Microsoft Desktop App Installer from the Microsoft Store." # Write a message to the log if the winget.exe path was not found
    Stop-Transcript
    exit 1
}

#If $Id was not found, stop and exit, and let Intune install it, or do nothing if it was uninstalled
Write-Host "Checking if software object is null..."
if ($software) {
    Write-Host "Software object type: $($software.GetType().FullName)" # Write the software object type to the log
    Write-Host "Software object properties: $($software | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)" # Write the software object properties to the log
} else {
    Write-Host "Software object is null - package not found" # Write a message to the log if the software object is null
}

if ($null -eq $software) {
    Write-Host ("{0} - {1} was not found on this system, installing now or doing nothing if it was uninstalled..." -f $(Get-Date -Format "dd-MM-yy HH:mm"), $Id) # Write a message to the log if the software object is null
    Stop-Transcript
    exit 1
}

# Check version and exit accordingly if the version is not the same as the installed version or when there's an update available, install it or do nothing if it was uninstalled
if ($Version -ne 'Latest') {
    # If a specific version is specified and package is installed, exit 0 (no action needed)
    Write-Host ("{0} - {1} is installed with version {2}. Specific version {3} was requested, no action needed..." -f $(Get-Date -Format "dd-MM-yy HH:mm"), $Id, $software.InstalledVersion, $Version) # Write a message to the log if the version is not the same as the installed version
    Stop-Transcript
    exit 0
}

if ($Version -eq 'Latest') {
    if ($software.IsUpdateAvailable -eq $false) {
        Write-Host $software.InstalledVersion # Write the installed version to the log
        Write-Host ("{0} - {1} version is current (Version {2}), nothing to do..." -f $(Get-Date -Format "dd-MM-yy HH:mm"), $Id, $software.InstalledVersion)
        Stop-Transcript
        exit 0
    }
    else {
        Write-Host ("{0} - {1} was found with version {2}, but there's an update available for it, updating now..." -f $(Get-Date -Format "dd-MM-yy HH:mm"), $Id, $software.InstalledVersion) # Write a message to the log if the version is not the same as the installed version
        Write-Host "Update initiated to version $Version." # Write a message to the log if the update is initiated
        Start-Process $wingetPath -ArgumentList "upgrade --id $Id --silent --accept-source-agreements --accept-package-agreements" -Wait -verbose
        Write-Host "Update completed." # Write a message to the log if the update is completed
        Stop-Transcript
        exit 0
    }
}
