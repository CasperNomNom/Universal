param()
$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$appBuilder = Join-Path $here "Build-EXE-v1.0.ps1"
$appExe = Join-Path $here "Universal DLSS 5 Installer.exe"
$iss = Join-Path $here "Installer\UniversalDLSS5Installer_v1_0.iss"

Write-Host ""
Write-Host "============================================================"
Write-Host " Universal DLSS 5 Installer v1.0 - Full Release Builder"
Write-Host "============================================================"
Write-Host ""

Write-Host "[1/4] Building application EXE..."
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $appBuilder
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $appExe)) {
    throw "Application EXE build failed."
}

Write-Host "[2/4] Locating Inno Setup compiler..."
$candidates = @(
    "$env:ProgramFiles(x86)\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
)
$iscc = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $iscc) {
    Write-Host "[INFO] Inno Setup 6 was not found."
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($winget) {
        Write-Host "[3/4] Installing Inno Setup 6 with winget..."
        & winget.exe install --id JRSoftware.InnoSetup --exact --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) {
            throw "winget could not install Inno Setup."
        }
        $iscc = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    } else {
        throw "Inno Setup 6 is required and winget is unavailable. Install Inno Setup 6, then run this builder again."
    }
} else {
    Write-Host "[3/4] Inno Setup already installed."
}

if (-not $iscc) {
    throw "Inno Setup compiler ISCC.exe could not be located after installation."
}

Write-Host "[4/4] Building installable Setup EXE..."
Push-Location (Split-Path -Parent $iss)
try {
    & $iscc $iss
    if ($LASTEXITCODE -ne 0) {
        throw "Inno Setup compiler returned exit code $LASTEXITCODE."
    }
} finally {
    Pop-Location
}

$setup = Join-Path $here "Installer\Output\Universal_DLSS5_Installer_Setup_v1.0.exe"
if (-not (Test-Path $setup)) {
    throw "Setup build completed but the expected installer was not found: $setup"
}

Write-Host ""
Write-Host "============================================================"
Write-Host " RELEASE BUILD COMPLETE"
Write-Host "============================================================"
Write-Host ""
Write-Host "Application:"
Write-Host "  $appExe"
Write-Host ""
Write-Host "Installable setup:"
Write-Host "  $setup"
Write-Host ""
Write-Host "You can distribute the Setup EXE to install/uninstall the application"
Write-Host "through Windows normally."
Write-Host ""
Read-Host "Press Enter to close"
