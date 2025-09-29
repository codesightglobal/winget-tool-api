<#
.SYNOPSIS
    Run optional custom actions during install or uninstall phases.

.DESCRIPTION
    Companion script invoked by the main WinGet deployment script.
    Executes app-specific steps when present, such as creating or removing
    shortcuts, applying configuration, or cleanup tasks. Called with the
    package `Id` and either `-Install` or `-Uninstall` switches.

.EXAMPLE
    .\Custom.ps1 -Id "Vendor.App" -Install -Verbose

.NOTES
    Author: Damien Cresswell, Sistena LTD.
    Last Edit: 23-09-2025
#>

param (
    [string]$Id,
    [switch]$Install,
    [switch]$Uninstall
)

try {
    if ($Install) {
        Write-Verbose "Executing Custom install commands for $Id"
        # Custom install commands go here from the form
    }

    if ($Uninstall) {
        Write-Verbose "Executing Custom uninstall commands for $Id"
        # Custom uninstall commands go here from the form
    }
}
catch {
    Write-Verbose ("{0} - ERROR in Custom.ps1: $($_.Exception.Message)" -f (Get-Date -Format "dd-MM-yy HH:mm"))
    throw
}
