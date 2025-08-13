' :: Script for use by Damien.Cresswell@sistena.co.uk
' ------------------------------------------------------------------------------
' Silent VBS launcher for PowerShell scripts (no console window shown).
' This template can be reused to install any application silently using a 
' PowerShell script and Winget or other methods.
' ------------------------------------------------------------------------------
'
' This script launches a PowerShell 7 script silently (no visible window),
' passing parameters for installation or uninstallation, and waits for completion.
'
' It assumes:
' - PowerShell 7 is installed in the specified path
' - The PowerShell script resides in the same folder as this VBS file
' - Parameters such as App Id and Version can be modified per app requirements
'
' Usage:
' - Modify the PowerShell path if necessary
' - Modify the script path if your script location differs
' - Adjust the command-line arguments as needed for your app's installation
'
' ------------------------------------------------------------------------------

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

command = powershellPath & " -ExecutionPolicy Bypass -MTA -File """ & scriptPath & """ -Install -Id <Replace me> -Version Latest -Verbose"

' ------------------------------------------------------------------------------
' EXECUTE: Run the PowerShell command silently (no command prompt window)
' Parameters:
'   0 = Hide the window
'   True = Wait for completion before moving on
' ------------------------------------------------------------------------------

shell.Run command, 0, True
