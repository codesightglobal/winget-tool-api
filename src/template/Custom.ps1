# :: Script for use by Damien.Cresswell@sistena.co.uk
<#
.SYNOPSIS
[INSTRUCTION: Briefly describe the custom actions this script will perform during install/uninstall phases for the specific app.]

.DESCRIPTION
[INSTRUCTION: Describe the types of customizations this script should handle, such as:
- Creating or removing shortcuts
- Performing app-specific cleanup
- Any other install/uninstall logic unique to the app
Provide clear instructions for future script authors to tailor this section to the app's needs.]

.PARAMETER Id
[INSTRUCTION: Application ID. Replace this description if needed.]

.PARAMETER Install
[INSTRUCTION: Triggers install-time actions. Replace this description if needed.]

.PARAMETER Uninstall
[INSTRUCTION: Triggers uninstall-time actions. Replace this description if needed.]

.NOTES
Author: [Your Name or Team]
Last edit: [Date]
[INSTRUCTION: Update author and date as appropriate for each new app/script.]
#>

param (
    [string]$Id,
    [switch]$Install,
    [switch]$Uninstall
)

function Write-Log {
    param (
        [string]$Message
    )
    Write-Verbose ("{0} - {1}" -f (Get-Date -Format "dd-MM-yy HH:mm"), $Message)
}

try {
    if ($Install) {
        Write-Log "Executing Custom install commands for $Id"
        # Example: Create shortcut or other install-specific tasks
        # (Not implemented in current version)
    }

    if ($Uninstall) {
        Write-Log "Executing Custom uninstall commands for $Id"

        <# for example --- Remove desktop shortcut ---
        $desktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "$Id.lnk"
        if (Test-Path $desktopShortcut) {
            Remove-Item $desktopShortcut -Force -Confirm:$false -ErrorAction Stop
            Write-Log "Removed desktop shortcut: $desktopShortcut"
        } else {
            Write-Log "Desktop shortcut not found: $desktopShortcut"
        } #>
    }
}
catch {
    Write-Verbose ("{0} - ERROR in Custom.ps1: $($_.Exception.Message)" -f (Get-Date -Format "dd-MM-yy HH:mm"))
    throw
}
