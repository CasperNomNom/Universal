#define MyAppName "Universal DLSS 5 Installer"
#define MyAppVersion "1.11"
#define MyAppPublisher "Universal DLSS 5 Installer"
#define MyAppExeName "Universal DLSS 5 Installer.exe"

[Setup]
AppId={{4F3B54B1-7A0A-4B88-8CC2-11C09C53E510}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} v{#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\Universal DLSS 5 Installer
DefaultGroupName=Universal DLSS 5 Installer
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=Universal_DLSS5_Installer_Setup_v1.11
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayName={#MyAppName} v{#MyAppVersion}
UninstallDisplayIcon={app}\{#MyAppExeName}
VersionInfoVersion=1.11.0.0
VersionInfoProductVersion=1.11.0.0
VersionInfoDescription=Universal DLSS 5 Installer v1.11 Setup
VersionInfoProductName=Universal DLSS 5 Installer
ChangesAssociations=no
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "..\Universal DLSS 5 Installer.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\CHANGELOG.txt"; DestDir: "{app}"; Flags: ignoreversion; Check: FileExists(ExpandConstant('{src}\..\CHANGELOG.txt'))

[Icons]
Name: "{group}\Universal DLSS 5 Installer"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\Universal DLSS 5 Installer"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch Universal DLSS 5 Installer"; Flags: nowait postinstall skipifsilent runascurrentuser

[UninstallDelete]
Type: filesandordirs; Name: "{app}\Logs"
Type: filesandordirs; Name: "{app}\Tools"
