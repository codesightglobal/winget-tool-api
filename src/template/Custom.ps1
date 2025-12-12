<# ------------------------------------------------------------------------------
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
    Author: Damien Cresswell, Sistena LTD.
    Last edit: 08-10-2025
[INSTRUCTION: Update author and date as appropriate for each new app/script.]
------------------------------------------------------------------------------ #>

param (
    [string]$Id,
    [switch]$Install,
    [switch]$Uninstall
)

function Write-Log {
    param (
        [string]$Message
    )
    Write-Verbose ("{0} - {1}" -f (Get-Date -Format "dd-MM-yy HH:mm"), $Message) # Write a message to the log
}

try {
    if ($Install) {
        Write-Log "Executing Custom install commands for $Id" # Write a message to the log if the install is triggered
        <Replace me:CustomFileInstall>
    }

    if ($Uninstall) {
        Write-Log "Executing Custom uninstall commands for $Id" # Write a message to the log if the uninstall is triggered
		<Replace me:CustomFileUninstall>
    }
}
catch {
    Write-Verbose ("{0} - ERROR in Custom.ps1: $($_.Exception.Message)" -f (Get-Date -Format "dd-MM-yy HH:mm")) # Write a message to the log if an error occurs
    throw
}
