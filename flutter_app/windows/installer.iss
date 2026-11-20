; Mus'haf for Windows (Quran Reader HD's app as Mushaf): a per-user installer. It installs into %LOCALAPPDATA%\Programs and the user's
; Start menu, so it never asks for administrator rights. Built by .github/workflows/release.yml:
;   iscc /DAppVersion=1.2.0 /DSourceDir=<flutter Release folder> /DOutputDir=<folder> installer.iss

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\build\installer"
#endif

[Setup]
; Keep this AppId: installing a newer version over an older one relies on it.
AppId={{6B0E3B52-8C1E-4A9C-9E57-2F4D3C7A9D10}
AppName=Mushaf - Madinah Quran
AppVersion={#AppVersion}
AppVerName=Mushaf - Madinah Quran {#AppVersion}
AppPublisher=Mushaf
AppPublisherURL=https://mushafapp.com
AppSupportURL=https://mushafapp.com
AppUpdatesURL=https://github.com/Mkuz1/Mushaf-releases/releases
PrivilegesRequired=lowest
DefaultDirName={localappdata}\Programs\Mushaf
DisableProgramGroupPage=yes
DisableDirPage=auto
OutputDir={#OutputDir}
OutputBaseFilename=Mushaf-{#AppVersion}-Setup
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\Mushaf.exe
UninstallDisplayName=Mushaf - Madinah Quran
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Updating while the app is open: close it, install, then start it again.
CloseApplications=yes
RestartApplications=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Mushaf - Madinah Quran"; Filename: "{app}\Mushaf.exe"
Name: "{autodesktop}\Mushaf - Madinah Quran"; Filename: "{app}\Mushaf.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\Mushaf.exe"; Description: "{cm:LaunchProgram,Mushaf}"; Flags: nowait postinstall skipifsilent

[InstallDelete]
; The shortcuts of versions before the app was named "Mushaf - Madinah Quran".
Type: files; Name: "{autoprograms}\Mus'haf.lnk"
Type: files; Name: "{autodesktop}\Mus'haf.lnk"
