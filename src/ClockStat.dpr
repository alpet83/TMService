program ClockStat;

uses
  Vcl.Forms,
  ClockStatForm in 'ClockStatForm.pas' {MainForm},
  TMSGlobals in 'TMSGlobals.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
