; GitManager 安装程序脚本
; 使用 Inno Setup 编译

[Setup]
AppName=GitManager
AppVersion=1.0.0
AppPublisher=GitManager Team
AppPublisherURL=https://example.com/
AppSupportURL=https://example.com/support
AppUpdatesURL=https://example.com/updates
DefaultDirName={autopf}\GitManager
DefaultGroupName=GitManager
AllowNoIcons=yes
OutputDir=f:\Project\GitManager\installer
OutputBaseFilename=GitManager_Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "chinese"; MessagesFile: "compiler:Default.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "f:\Project\GitManager\build\windows\x64\runner\Release\git_manager.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "f:\Project\GitManager\build\windows\x64\runner\Release\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "f:\Project\GitManager\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "f:\Project\GitManager\build\windows\x64\runner\Release\bitsdojo_window_windows_plugin.lib"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\GitManager"; Filename: "{app}\git_manager.exe"
Name: "{commondesktop}\GitManager"; Filename: "{app}\git_manager.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Run]
Filename: "{app}\git_manager.exe"; Description: "{cm:LaunchProgram,GitManager}"; Flags: nowait postinstall skipifsilent