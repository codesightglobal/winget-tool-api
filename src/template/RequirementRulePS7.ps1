<#
.SYNOPSIS
    Check if PowerShell 7 is installed for use as an Intune requirement rule.

.DESCRIPTION
    Detection script that verifies the presence of PowerShell 7 (`pwsh.exe`).
    Returns exit code 0 and a success string when PowerShell 7 is installed,
    otherwise returns exit code 1 and a not-found string. Intended for use in
    Microsoft Intune requirement rules or detection scenarios.

.EXAMPLE
    .\RequirementRulePS7.ps1
    # Outputs 'Required_PowerShell_v7_Found' and exits 0 when pwsh.exe exists.

.NOTES
    Author: Damien Cresswell, Sistena LTD.
    Last Edit: 23-09-2025
#>
if (Test-Path -LiteralPath 'C:\Program Files\PowerShell\7\pwsh.exe') {
    Write-Output 'Required_PowerShell_v7_Found'
    exit 0
}
else {
    Write-Output 'Required_PowerShell_v7_Not_Found'
    exit 1
}