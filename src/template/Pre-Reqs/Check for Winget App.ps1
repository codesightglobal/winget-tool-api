# Check if App Installer is installed
$package = Get-AppxPackage -Name Microsoft.DesktopAppInstaller

if ($package) {
    Write-Host "App Installer is already installed. Version: $($package.Version)"
    exit 0
} else {
    Write-Host "App Installer not found. Downloading and installing..."

    # Define the URL for the App Installer package (MSIXBundle from Microsoft)
    $installerUrl = "https://aka.ms/getwinget"

    # Define a temporary path to save the installer
    $tempPath = "$env:TEMP\AppInstaller.msixbundle"

    # Download the installer
    Invoke-WebRequest -Uri $installerUrl -OutFile $tempPath

    # Install the package
    Add-AppxPackage -Path $tempPath

    # Confirm installation
    $installed = Get-AppxPackage -Name Microsoft.DesktopAppInstaller
    if ($installed) {
        Write-Host "App Installer successfully installed. Version: $($installed.Version)"
        exit 0
    } else {
        Write-Host "Installation failed."
        exit 1
    }
}
