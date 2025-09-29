# Ensure TLS 1.2 for PowerShell Gallery
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Install NuGet provider if needed
if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Install-PackageProvider -Name NuGet -Force
}

# Install Microsoft.Winget.Client module if not already present
if (-not (Get-Module -ListAvailable -Name Microsoft.Winget.Client)) {
    Install-Module -Name Microsoft.Winget.Client -Force -Scope AllUsers -AllowClobber
}
