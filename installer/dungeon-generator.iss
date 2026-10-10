; Installateur Windows de Dungeon Generator (Inno Setup 6). Généré par le workflow de publication :
;   ISCC /DAppVersion=1.31.4 installer\dungeon-generator.iss        (après avoir préparé build\payload-windows avec tools/pack_manifest.py)
; Installation par défaut dans %LocalAppData%\Programs : aucun droit administrateur, et le jeu peut se mettre à jour lui-même.
; Disposition : « Dungeon Generator.exe » (moteur) + « Dungeon Generator.pck » (code, données, polices, interface)
;               + « packs\ » (thèmes, monstres, audio) + « install.json » (état des fichiers pour les mises à jour partielles).
; Les sauvegardes sont dans le profil de l'utilisateur (Godot\app_userdata) : elles sont conservées à la désinstallation.

#define AppName "Dungeon Generator"
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{6C5A7B0E-3D1F-4B7E-9E3A-5D6E1A0F7C21}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Nydaunvan
AppPublisherURL=https://github.com/Nydaunvan/Dungeon-Generator
DefaultDirName={localappdata}\Programs\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=..\dist
OutputBaseFilename=Dungeon-Generator-{#AppVersion}-setup
Compression=lzma2/normal
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=app.ico
UninstallDisplayIcon={app}\app.ico
UninstallDisplayName={#AppName}
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\payload-windows\Dungeon Generator.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\payload-windows\Dungeon Generator.pck"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\payload-windows\packs\*"; DestDir: "{app}\packs"; Flags: ignoreversion recursesubdirs
Source: "..\build\payload-windows\install.json"; DestDir: "{app}"; Flags: ignoreversion
; icône des raccourcis et de la désinstallation (aussi présente dans l'exécutable ; ici, une copie qui ne dépend de rien)
Source: "app.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\Dungeon Generator.exe"; WorkingDir: "{app}"; IconFilename: "{app}\app.ico"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\Dungeon Generator.exe"; WorkingDir: "{app}"; IconFilename: "{app}\app.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\Dungeon Generator.exe"; Description: "{cm:LaunchProgram,{#AppName}}"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; fichiers que le jeu ou ses mises à jour ont pu écrire après l'installation
Type: filesandordirs; Name: "{app}\packs"
Type: files; Name: "{app}\install.json"
Type: files; Name: "{app}\.write_test"
