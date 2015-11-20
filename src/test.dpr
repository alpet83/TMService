program test;

{$APPTYPE CONSOLE}

uses
  Forms,
  Windows,
  Messages,
  SysUtils,
  Registry,
  StrUtils,
  Classes,
  Graphics,
  Controls,
  SvcMgr,
  Dialogs,
  ExtCtrls,
  StrClasses,
  Misc,
  SyncObjs,
  DateTimeTools,
  Perf in '..\lib\Perf.pas',
  WThreads in '..\lib\WThreads.pas';


type
  TTestThread = class(TWorkerThread)
  protected
   procedure    ProcessInit; override;
   procedure    ProcessThreadStop; override;
  public
   ptsync: TProfileTimer;
   evt_sync: TEvent;

   procedure    WorkProc; override;
  end;

procedure TestMain;
var
   i, nn, maxn: Integer;
   idx: DWORD;
   scl: TSystemCountersList;
   sco: TSystemCounter;
   map: TStrMap;
   fmv: PDH_FMT_COUNTERVALUE;
   s: String;
   pt: TProfileTimer;

begin
 if ERROR_SUCCESS = PdhLookupPerfIndexByName (nil, 'Процессор', idx) then
    WriteLn(' index for "Processor.RU" = ' + IntToStr (idx));


 map := TStrMap.Create;
 scl := TSystemCountersList.Create;

 i := scl.IndexOfCounter ('Processor');

 WriteLn (' index for "Processor.EN" = ' + IntToStr(i) +
          ', name = ' + Wide2Oem (  scl.LookupCounterName (i, TRUE))  );



{ psn := scl.EnuToLocal ('Processor');
 pst := scl.EnuToLocal ('% Processor Time');
 psi := scl.EnuToLocal ('% Idle Time');}


 pt := TProfileTimer.Create;

 try
   scl.AddCPUCounters ('% Processor Time');

{   for i := 0 to 47 do
    begin
     root := '\' + psn + '(' + IntToStr (i) + ')\';
     //

     if scl.AddCounter (root + pst, 'LOAD_' + IntToStr(i)) = nil then break;
     // if scl.AddCounter (root + psi, 'IDLE_' + IntToStr(i)) = nil then break;

    end;}


   // попытка сбора инфы по счетчикам
   if scl.CollectQueryData (5) = ERROR_SUCCESS then

     for i := 0 to 4 do
      begin
       pt.StartOne(1);
       if scl.QueryEvent.WaitFor (10000) = wrTimeout then continue;
       scl.QueryEvent.ResetEvent;
       if i = 0 then continue;

       WriteLn ( Format('-------------- stamp #%d, time = %.2f ms', [i, pt.Elapsed (1)]) );
       maxn := ( scl.Count - 1 );
       for nn := 0 to maxn do
        begin
         Assert (nn < scl.Count, Format('nn (%d) >= scl.Count (%d), maxn = %d', [nn, scl.Count, maxn]) );
         s := scl [nn];
         sco := scl.items [nn];
         if sco = nil then break;
         fmv := sco.GetFmtValue (PDH_FMT_DOUBLE);

         if fmv.cStatus = ERROR_SUCCESS then
            WriteLn ( Wide2Oem ( s ) + ' = ' + ftow(fmv.doubleValue, '%.2f%%'));
        end; // for n


      end; // for i

 finally
  scl.Free;
  map.Free;
  pt.Free;
 end;

end;




{ TTestThread }

procedure TTestThread.ProcessInit;
begin
 inherited;
 ptsync := TProfileTimer.Create;
 evt_sync := TEvent.Create (nil, TRUE, FALSE, 'evt_sync');

 Garbage.Add (ptsync);
 Garbage.Add (evt_sync);
end;

procedure TTestThread.ProcessThreadStop;
begin
  inherited;
end;

procedure TTestThread.WorkProc;
begin
 inherited;

 if WaitForSingleObject (evt_sync.Handle, 1000) = WAIT_OBJECT_0 then
  begin
   ODS( Format('[~T/~B]. #DBG: event set about~C0D %.3f~C0F mcs~C07 ago', [ptsync.Elapsed (1) * 1000] ) );
   evt_sync.ResetEvent;
  end;



end;





var
     pv: Int64;
     ns: NTSTATUS;
     td: TTimeDeviator;
    bft: TFileTime;
     ft: TFileTime;
     dt: TDateTime;
     dr: TDateTime;
   prvf: TFileTime;
   prvt: TDateTime;
   prvp: TDateTime;
   diff: TDateTime;
   lcnt: Integer;
  tdiff: Int64;
    nsu: Int64;
      r: Integer;
      n: Integer;
   pt: TProfileTimer;
   tt: TTestThread;
   st: TSystemTime;
   lt: TSystemTime;
  sft: TSystemTime;

  lt_cc: Integer;
  ft_cc: Integer;

   tres: DWORD;



begin
  try
    StartLogging('');
    ShowConsole;
    // TestMain;

    SetPriorityClass (GetCurrentProcess, REALTIME_PRIORITY_CLASS);

    g_timer := TVirtualTimer.Create;

    {
    tt := TTestThread.Create (FALSE, 'TestThread');
    tt.WaitStart;
    tt.wait_time := 1;}

    WriteLn ('Press ESC for break...');


    pt := TProfileTimer.Create;
    pt.StartOne (1);
    // pt.UpdateCalibration ( TRUE );


    //
    td := TTimeDeviator.Create;

    Sleep (500);


    lcnt := 0;

    prvp := 0;

    diff := pt.Elapsed (1);

    PatchQPF;

    SetTimerResolution ( 50000, TRUE, tres );

    ODS ( '[~T/~B]. #DBG: 500 ms sleep = ' + ftow (diff, '%.3f ms') );

    pt.StartOne (2);

    for n := 1 to 100000 do
     begin
      {$IFDEF QPC}
      QueryPerformanceCounter ( pv );
      QueryPerformanceCounter ( pv );
      QueryPerformanceCounter ( pv );
      QueryPerformanceCounter ( pv );
      QueryPerformanceCounter ( pv );
      QueryPerformanceCounter ( pv );
      QueryPerformanceCounter ( pv );
      QueryPerformanceCounter ( pv );
      QueryPerformanceCounter ( pv );
      QueryPerformanceCounter ( pv );
      {$ELSE}
      pt.Elapsed (1);
      pt.Elapsed (1);
      pt.Elapsed (1);
      pt.Elapsed (1);
      pt.Elapsed (1);

      pt.Elapsed (1);
      pt.Elapsed (1);
      pt.Elapsed (1);
      pt.Elapsed (1);
      pt.Elapsed (1);
      {$ENDIF}
     end;


    dt := pt.Elapsed (2); // ms for 1 million loops

    // * 1e6 = ms, * 1000 = mcs
    ODS ( '[~T/~B]. #DBG: Actual timer resolution ' + IntToStr (tres) +
            ', QPC_call = ' + ftow (dt, '%.6f ns') );


    if diff > 100 then

    repeat

      if lcnt = 20 then
         td.Patch;
      Inc (lcnt);

      QueryPerformanceFrequency ( nsu );
      if nsu > 0 then
         ODS ( '[~T]. #DBG: QueryPerformanceFrequency returned ' + IntToStr (nsu) );

      // rt^ := 0;

      // if not WriteProcessMemory ( GetCurrentProcess, rt, @lt, 4, lt ) then           PrintError ('Cannot write: ' + err2str  );
      // if tf.Second < 30 then Inc (tf.Second) else tf.Second := 0;
      // if lt > 0 then lt := lt - Int64(10) * 1000;


      // tf.Milliseconds := Random (500);
      r := Random (5);

      lt_cc := 0;
      ft_cc := 0;

      for n := 0 to Random (10000) do
          g_timer.GetTime (FALSE);

      ODS ( '[~T]. #DBG: active_index = ' + IntToStr (g_timer.ActiveSlot.slot_idx) );


      prvt := g_timer.GetTime;
      if TRUE then
      repeat
       // g_timer.GetTime;
        for n := 0 to 1000 do
         asm
          pause
          pause
          pause
         end;
       diff := ( g_timer.GetTime (TRUE) - prvt ); // SyncPort.dt_last

       // g_timer.SyncPort.Fork;

       GetLocalTime (lt);

       if lt.wMilliseconds <> st.wMilliseconds then Inc (lt_cc);
       st := lt;

       GetSystemTimeAsFileTime ( ft );

       if ft.dwLowDateTime <> bft.dwLowDateTime then Inc (ft_cc);

       bft := ft;


      until ( diff >= ( DT_ONE_SECOND * 1.0 + r * DT_ONE_MCS * 10 ) )
      else
        Sleep (1000);



      td.DateTime := g_timer.GetTime (TRUE) - DT_ONE_MINUTE;
      GetLocalTime (lt);

      GetSystemTimeAsFileTime ( ft );
      FileTimeToSystemTime ( ft, sft );

      st := lt;
      st.wHour := 0;
      st.wMinute := 0;
      st.wSecond := 0;
      st.wMilliseconds := 0;
      SystemTimeToFileTime ( st, bft );




      diff := 0;
      dt := CurrentDateTime ( @ft );
      dr := Frac ( dt );

      dr := dr / DT_ONE_MSEC;

      nsu := Trunc ( dr * 10000 ) mod 10000000;

      dr := nsu / 10000;

      tdiff := FT64 (ft) - FT64 (bft);

      WriteLn ( ' #DBG: LocalTime = ' + FormatDateTime ('nn:ss.zzz', SystemTimeToDateTime (lt) ) +
                ', SystemTime(FT) = ' + FormatDateTime ('nn:ss.zzz', SystemTimeToDateTime (sft) ) +
                ', PrecDateTime   = ' + FormatDateTime ('nn:ss.zzz', dt ) +

            ' SharedTime = ' + FormatDateTime ( 'hh:nn:ss.zzz', g_timer.GetTime (TRUE) ) +
            ', updc = ' + IntToStr ( g_timer.ActiveSlot.upd_cnt ) +
            ', prec1 = ' + ftow ( ( tdiff mod 10000000 ) / 10000, '%8.3f' ) +
            ', prec2 = ' + ftow (  dr, '%8.3f' ) +
            Format (' ltc = %d, ftc = %d ', [lt_cc, ft_cc] ) );

      prvf := ft;



      // Sleep (1000);
      //WaitForSingleObject (he, 1000);




      if FALSE then
         ODS( CFormat ( '[~T/~B]. #DBG: g_timer.SyncPort.base = %s, last = %16x ', '~C07',
                     [ FormatDateTime ('hh:nn:ss.zzz', g_timer.ActiveSlot.base), g_timer.ActiveSlot.pfc_last] ) );

      // tt.ptsync.StartOne (1);
      // tt.evt_sync.SetEvent;
    until IsKeyPressed (VK_ESCAPE);

    //


    tt.StopThread;


    WriteLn ('Press ENTER for exit...');
    ReadLn;
    tt.WaitStop;
    tt.Free;

    { TODO -oUser -cConsole Main : Insert code here }
  except
    on E:Exception do
      Writeln(E.Classname, ': ', E.Message);
  end;
end.
