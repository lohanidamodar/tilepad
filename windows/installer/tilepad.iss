; Inno Setup script for the Tilepad desktop server (Windows installer).
;
; Build locally:
;   flutter build windows --release -t lib/src/server/main.dart
;   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" /DMyAppVersion=1.0.0 windows\installer\tilepad.iss
;
; The release workflow passes the version from the git tag. Output goes to
; windows/installer/output/Tilepad-Setup-<version>.exe.

#define MyAppName "Tilepad"
#define MyAppPublisher "Tilepad"
#define MyAppURL "https://github.com/lohanidamodar/macro-deck-updated"
#define MyAppExeName "tilepad.exe"

#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

; Folder holding the `flutter build windows --release` output (the .exe, DLLs
; and the data/ bundle). Overridable from the command line for CI.
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif

[Setup]
; A fixed AppId keeps upgrades/uninstall stable across versions.
AppId={{B7E4B2A0-1C3D-4E5F-9A8B-0C1D2E3F4A5B}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir=output
OutputBaseFilename=Tilepad-Setup-{#MyAppVersion}
SetupIconFile=..\..\assets\tray_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
