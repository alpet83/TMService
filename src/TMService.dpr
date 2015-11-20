// Copyright © 2005-2015 Alexander Petrov aka alpet
// http://www.apache.org/licenses/LICENSE-2.0

program TMService;
{$APPTYPE CONSOLE}
uses
  madExcept,
  madLinkDisAsm,
  madListHardware,
  madListProcesses,
  madListModules,
  SvcMgr,
  Classes,
  SysUtils,
  TMSvc in 'TMSvc.pas' {svcTime: TService},
  ArrayTypes in '..\lib\ArrayTypes.pas',
  DateTimeTools in '..\lib\DateTimeTools.pas',
  FastSync in '..\lib\FastSync.pas',
  misc in '..\lib\misc.pas',
  PsUtils in '..\lib\PsUtils.pas',
  Perf in '..\lib\Perf.pas',
  IdUDPServer,
  TMSGlobals in 'TMSGlobals.pas';

{$D-}
{$R *.RES}

begin
  // Windows 2003 Server requires StartServiceCtrlDispatcher to be
  // called before CoRegisterClassObject, which can be called indirectly
  // by Application.Initialize. TServiceApplication.DelayInitialize allows
  // Application.Initialize to be called from TService.Main (after
  // StartServiceCtrlDispatcher has been called).
  //
  // Delayed initialization of the Application object may affect
  // events which then occur prior to initialization, such as
  // TService.OnCreate. It is only recommended if the ServiceApplication
  // registers a class object with OLE and is intended for use with
  // Windows 2003 Server.
  //
  // Application.DelayInitialize := True;
  //

  g_timer := TVirtualTimer.Create;

  if Application.Installing then
     WriteLn('Installing the LocalTimeSync service');

  if not Application.DelayInitialize or Application.Installing then  Application.Initialize;

  try
   Application.CreateForm(TsvcTime, svcTime);
  except
   on E: Exception do
     OnExceptLog ('Application.CreateForm', E);
  end;

  try
   Application.Run;
  except
   on E: Exception do
     OnExceptLog ('Application.Run', E);
  end;

  svcTime := nil;
end.
