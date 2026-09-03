; ═══════════════════════════════════════════════════════════════
; Portal Pilot - Inno Setup Script (Premium Installer)
; Compile with: iscc setup.iss
; ═══════════════════════════════════════════════════════════════

#define MyAppName "Portal Pilot"
#define MyAppVersion "0.1.3"
#define MyAppPublisher "sarch-codelab"
#define MyAppURL "https://github.com/sarch-codelab/portalpilot-app"
#define MyAppExeName "PortalPilotWorkspace.exe"
#define MyAppDescription "ERP offline-first con IA integrada"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
LicenseFile=LICENSE.txt
OutputDir=dist
OutputBaseFilename=PortalPilot_Windows_x64_v{#MyAppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64
ArchitecturesAllowed=x64
PrivilegesRequired=admin

; ── Apariencia visual ──────────────────────────────────────
WizardSizePercent=120
WizardImageFile=assets\installer\wizard_image.bmp
WizardSmallImageFile=assets\installer\wizard_header.bmp

; ── Info del instalador ────────────────────────────────────
VersionInfoVersion={#MyAppVersion}.0
VersionInfoDescription={#MyAppName} - Instalador
VersionInfoCopyright=Copyright (c) 2026 {#MyAppPublisher}
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Messages]
WelcomeLabel1=Bienvenido al asistente de instalación de [Name]
WelcomeLabel2=Este programa instalará [Name] [Version] en tu computadora. Se recomienda cerrar todas las demás aplicaciones antes de continuar.
FinishedLabel=La instalación de [Name] se completó correctamente. Puedes iniciar la aplicación desde el escritorio o el menú Inicio.

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Comment: "{#MyAppDescription}"
Name: "{group}\Desinstalar {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; Comment: "{#MyAppDescription}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Code]
function InitializeSetup(): Boolean;
begin
  Result := True;
end;

function InitializeUninstall(): Boolean;
begin
  Result := True;
end;