Option Explicit

Dim shellApp, fso, baseDir, psFile, args
Set shellApp = CreateObject("Shell.Application")
Set fso = CreateObject("Scripting.FileSystemObject")

baseDir = fso.GetParentFolderName(WScript.ScriptFullName)
psFile = baseDir & "\UniversalDLSS5Installer_v4_3_8.ps1"

If Not fso.FileExists(psFile) Then
    MsgBox "UniversalDLSS5Installer_v4_3_8.ps1 was not found beside this launcher.", 16, "Universal DLSS 5 Installer"
    WScript.Quit 1
End If

args = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File """ & psFile & """"

' Request elevation and keep PowerShell hidden.
' Windows can still show its normal UAC consent prompt.
shellApp.ShellExecute "powershell.exe", args, baseDir, "runas", 0
