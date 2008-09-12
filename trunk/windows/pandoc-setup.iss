; Script generated by the Inno Setup Script Wizard.
; SEE THE DOCUMENTATION FOR DETAILS ON CREATING INNO SETUP SCRIPT FILES!

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
; Do not use the same AppId value in installers for other applications.
; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)
AppId={{3CEE7B38-B19D-4980-9CAD-DF53600BD4CA}
AppName=Pandoc
AppVerName=Pandoc 1.0
AppPublisher=John MacFarlane
AppPublisherURL=http://johnmacfarlane.net/pandoc/
AppSupportURL=http://johnmacfarlane.net/pandoc/
AppUpdatesURL=http://johnmacfarlane.net/pandoc/
DefaultDirName={pf}\Pandoc
DefaultGroupName=Pandoc
AllowNoIcons=yes
LicenseFile=C:\Documents and Settings\John MacFarlane\My Documents\src\pandoc\COPYING.txt
OutputBaseFilename=setup
Compression=lzma
SolidCompression=yes
ChangesEnvironment=yes

[Tasks]
Name: modifypath; Description: Add application directory to your system path

[Code]
function ModPathDir(): TArrayOfString;
var
    Dir: TArrayOfString;
begin
    setArrayLength(Dir, 1)
    Dir[0] := ExpandConstant('{app}');
    Result := Dir;
end;
#include "modpath.iss"

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "basque"; MessagesFile: "compiler:Languages\Basque.isl"
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "catalan"; MessagesFile: "compiler:Languages\Catalan.isl"
Name: "czech"; MessagesFile: "compiler:Languages\Czech.isl"
Name: "danish"; MessagesFile: "compiler:Languages\Danish.isl"
Name: "dutch"; MessagesFile: "compiler:Languages\Dutch.isl"
Name: "finnish"; MessagesFile: "compiler:Languages\Finnish.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "german"; MessagesFile: "compiler:Languages\German.isl"
Name: "hebrew"; MessagesFile: "compiler:Languages\Hebrew.isl"
Name: "hungarian"; MessagesFile: "compiler:Languages\Hungarian.isl"
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"
Name: "norwegian"; MessagesFile: "compiler:Languages\Norwegian.isl"
Name: "polish"; MessagesFile: "compiler:Languages\Polish.isl"
Name: "portuguese"; MessagesFile: "compiler:Languages\Portuguese.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "slovak"; MessagesFile: "compiler:Languages\Slovak.isl"
Name: "slovenian"; MessagesFile: "compiler:Languages\Slovenian.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Files]
Source: "..\dist\build\pandoc\pandoc.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.html"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\COPYRIGHT.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\COPYING.txt"; DestDir: "{app}"; Flags: ignoreversion
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{group}\{cm:UninstallProgram,Pandoc}"; Filename: "{uninstallexe}"
Name: "{group}\Pandoc User's Guide"; Filename: "{app}\README.html"

