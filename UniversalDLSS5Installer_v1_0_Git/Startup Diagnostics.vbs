Option Explicit

Dim shell, fso, baseDir, psFile, logFile, cmd
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

baseDir = fso.GetParentFolderName(WScript.ScriptFullName)
psFile = baseDir & "\UniversalDLSS5Installer_v4_3_8.ps1"
logFile = baseDir & "\UniversalDLSS5Installer-Startup.log"

If fso.FileExists(logFile) Then
    On Error Resume Next
    fso.DeleteFile logFile, True
    On Error GoTo 0
End If

cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -Command " & _
      """try { & '" & Replace(psFile,"'","''") & "' } catch { $_ | Format-List * -Force | Out-File -Encoding UTF8 '" & Replace(logFile,"'","''") & "'; exit 1 }"""

shell.Run cmd, 0, True

If fso.FileExists(logFile) Then
    MsgBox "A startup diagnostic log was created:" & vbCrLf & logFile, 48, "Universal DLSS 5 Installer"
End If
