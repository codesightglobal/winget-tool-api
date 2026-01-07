' ------------------------------------------------------------------------------
' .SYNOPSIS
'     Silent VBS launcher for PowerShell scripts (no console window shown)
'
' .DESCRIPTION
'     This script launches a PowerShell 7 script silently (no visible window),
'     passing parameters for installation or uninstallation, and waits for completion.
'     It assumes PowerShell 7 is installed and the script resides in the same folder.
'
' .NOTES
'     Author: Damien Cresswell, Sistena LTD.
'     Last Edit: 08-10-2025
------------------------------------------------------------------------------

Dim shell, powershellPath, scriptPath, command

' Create a WScript Shell object to run commands
Set shell = CreateObject("WScript.Shell")

' ------------------------------------------------------------------------------
' SETTING: Full path to PowerShell executable
' You MUST wrap it in triple quotes to produce a string like:
' "C:\Program Files\PowerShell\7\pwsh.exe"
' ------------------------------------------------------------------------------

powershellPath = """C:\Program Files\PowerShell\7\pwsh.exe"""

' ------------------------------------------------------------------------------
' SETTING: Path to the PowerShell script you want to run
' This assumes the script is in the same folder as the VBS file.
' Change this if your script resides elsewhere.
' ------------------------------------------------------------------------------

scriptPath = shell.CurrentDirectory & "\Winget.ps1"

' ------------------------------------------------------------------------------
' SETTING: Command-line arguments to pass to the PowerShell script
' Modify the ID, version, or any other parameter as needed per app.
' Note the correct PowerShell syntax: parameters use a single dash, e.g. -Id
' ------------------------------------------------------------------------------

command = powershellPath & " -ExecutionPolicy Bypass -MTA -File """ & scriptPath & """ -Install -Id <Replace me:Id> -Version <Replace me:Version> -Verbose"

' ------------------------------------------------------------------------------
' EXECUTE: Run the PowerShell command silently (no command prompt window)
' Parameters:
'   0 = Hide the window
'   True = Wait for completion before moving on
' ------------------------------------------------------------------------------

shell.Run command, 0, True
