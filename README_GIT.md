# Universal DLSS 5 Installer

Current release line: **v1.0**

This repository contains the editable PowerShell/WinForms source and Windows release-build scripts for Universal DLSS 5 Installer.

## Main source

- `UniversalDLSS5Installer_v1_0.ps1`

## Build

On Windows, run:

- `BUILD RELEASE v1.0.bat`

This builds the application EXE and then the installable Inno Setup package.

## Release lineage

The v1.0 branch is based on the locked **SR2 Neural Rendering Settings UI + Mini Debug Console** baseline. Experimental Natural Pipeline / automatic iMMERSE / release-resolver branches are intentionally excluded.

See `CHANGELOG.txt` for the reconstructed development history.
