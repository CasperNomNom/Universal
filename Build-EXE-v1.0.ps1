param()
$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src  = Join-Path $here "UniversalDLSS5Installer_v1_0.ps1"
$out  = Join-Path $here "Universal DLSS 5 Installer.exe"

if (-not (Test-Path $src)) {
    throw "Source file not found: $src"
}

Write-Host ""
Write-Host "============================================================"
Write-Host " Universal DLSS 5 Installer v1.0 - Application EXE Builder"
Write-Host "============================================================"
Write-Host ""

if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Write-Host "[1/3] Installing PS2EXE for the current Windows user..."
    try {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        Install-Module ps2exe -Scope CurrentUser -Force -AllowClobber
    } catch {
        throw "Could not install PS2EXE. $($_.Exception.Message)"
    }
} else {
    Write-Host "[1/3] PS2EXE already installed."
}

Import-Module ps2exe -Force
$cmd = Get-Command Invoke-ps2exe -ErrorAction Stop

if (Test-Path $out) {
    Remove-Item $out -Force
}

Write-Host "[2/3] Compiling application..."

$args = @{
    InputFile   = $src
    OutputFile  = $out
    NoConsole   = $true
    STA         = $true
    RequireAdmin= $true
    Title       = "Universal DLSS 5 Installer"
    Description = "Universal DLSS 5 Installer"
    Product     = "Universal DLSS 5 Installer"
    Company     = "Universal DLSS 5 Installer"
    Version     = "1.0.0.0"
    Copyright   = "Universal DLSS 5 Installer"
}

# Newer PS2EXE versions support DPIAware. Add it only when available.
if ($cmd.Parameters.ContainsKey("DPIAware")) {
    $args["DPIAware"] = $true
}

Invoke-ps2exe @args

if (-not (Test-Path $out)) {
    throw "PS2EXE completed without creating the application executable."
}

Write-Host "[3/3] Application EXE created."
Write-Host ""
Write-Host "Built:"
Write-Host "  $out"
Write-Host ""
Write-Host "NOTE: The EXE requests Administrator privileges because the installer"
Write-Host "      installs/repairs files inside game folders such as Program Files."
Write-Host ""
