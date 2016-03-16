unit TMSvc;

interface

{.$D-}
uses
  Forms, Windows, Messages, SysUtils, StrUtils, Classes, Graphics, Controls, Perf, SyncObjs, ContNrs, TMSGlobals,
  SvcMgr, Dialogs, ExtCtrls, IdTCPConnection, IdTCPClient, IdExplicitTLSClientServerBase, IdMessageClient, IdNNTP, IdGlobalProtocols, StrClasses,
  Misc, DateTimeTools, IdUDPBase, IdUDPClient, IdSNTPX, IniFiles, Math, IdBaseComponent, IdComponent, IdContext, IdCustomTCPServer, IdTCPServer, IdCmdTCPServer, IdNNTPServer;

const
  // ONE_HOUR    = 1.0 / 24; // 1/24
  // ONE_MINUTE  = ONE_HOUR / 60;
  // ONE_SECOND  = ONE_MINUTE / 60;
  // ONE_MSEC    = ONE_SECOND / 1000.0;
  MSEC_IN_MIN    = 60000.0;
  MSEC_IN_HOUR   = MSEC_IN_MIN * 60.0;

  VTT_PERIOD     = 4;
  VTT_PREC       = 7;
  PS_LIVE_TIME   = 8;
  VTT_LAST_START = 9;
  VTT_TIMER      = 11;
  VTT_TIMER2     = 12;
  VTT_SYNC       = 13;
  VTT_HOURS      = 25;

  VTT_LAST_CHECK = 28;
  VTT_LAST_SYNC  = 29;
  VTT_PWM        = 30;


  def_rates: array [1..5] of Integer = ( 240, 120, 30, 15, 5 );


type
  TRQThread = class (TThread)
  protected
   procedure    Execute; override;
  public
  end;

  TTextFileObj = class
  private
    FFileName: String;
    FError: Integer;
    FOpened: Boolean;
  protected
    FRec: Text;
    last_flush: WORD;
  public

   { props }
   property FileName: String read FFileName;
   property Error: Integer read FError;
   property Opened: Boolean read FOpened;


   { C & D }
   constructor  Create (AFileName: String);
   destructor   Destroy; override;

   { methods }
   procedure    Close;
   procedure    PutStr (const s: String);

  end; // TTextFileObj


  TDiffCell = class
  public
    value: Double;
    dev_sum: Double;
  end;

  TDataStatVector = class
  private
   FData: array of Double;
   FSize: Integer;
   FCount: Integer;
    FLast: Double;
  protected
  public

   { props }
   property Count: Integer read FCount;
   property Size: Integer read FSize;
   property Last: Double read FLast;        // последнее из всех значений

   { C & D }
   constructor Create (ASize: Integer);
   destructor  Destroy; override;

   { methods }

   procedure Add (v: Double); // добавление, с возможностью сдвига элементов
   procedure Clear;


   function  Median: Double;      // среднее из всех значений
   function  StatMedian: Double;  // статистическое среднее упрощеное

  end; // TDataStatVector



  TsvcTime = class(TService)
    tmrCheck: TTimer;
    tmrFast: TTimer;
    procedure ServiceStart(Sender: TService; var Started: Boolean);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
    procedure ServicePause(Sender: TService; var Paused: Boolean);
    procedure ServiceContinue(Sender: TService; var Continued: Boolean);
    procedure tmrCheckTimer(Sender: TObject);
    procedure tmrFastTimer(Sender: TObject);
    procedure ServiceShutdown(Sender: TService);
    procedure ServiceCreate(Sender: TObject);
  private
    { Private declarations }
    accuracy: Double;
    n_ticks: Integer;

    cfg_file: String;

    auto_qrate: TStrMap;

    timer_loops: Integer;
      no_dialog: Boolean;

    q_rate, min_qrate, max_qrate: Integer;

    v_rate: Integer;
    ntp_hosts: TStrings;
    ban_times: array [0..255] of TDateTime;

    min_dvg, max_dvg: TDateTime; // test bounds
    max_rqt: Double;
    cum_dvg: Double;
    sync_cnt: Integer;
    sync_ofs: Integer;           // Смещение в минутах фазы квантования
    ntp_sync_cnt: Integer;
    aprox_fact: Double;
    pfc_save: Boolean;
    pfc_adjust: Double;
    pfc_adjust_lv: CHAR;
    st_adjust: Integer;
    hw_adjust: Boolean;

         mcorr: SmallInt;
     clock_res: Integer;
    target_res: DWORD;
    st_adjust_cnt: Integer;

    lst_cpu_load: array [0..255] of Double;
    cnt_cpu_load: Integer;
    avg_cpu_load: Double;
    sta_cpu_ratio: Double;


    prv_dta_ms: Double;

    pwm_allow: Boolean;
    pwm_range: Integer;
    pwm_split: Integer;
    pwm_split_ema: Double;
    pwm_side: Integer;
    min_st_adjust: Integer;
    max_st_adjust: Integer;
    clock_adjust: Boolean;
    ema_delta: Double;

    pfca_low, pfca_high, pfca_tresh: Double;
    pfc_errors: Integer;
    hTok: THandle;
    have_privileges: Boolean;
    auto_pfc_adjust: Boolean;
    sorter: TList;
    IdSNTP1: TIdSNTP;            // need to access for disconnect
    IdSNTPSrv: TIdSNTPServer;
    check_delay: DWORD;
    sync_timeout: DWORD;
    term_timeout: DWORD;
    prv_dev: Double;
    ref_time, ref_time2: TDateTime;
    ntp_dt, prv_ntp_time: TDateTime;
    ntp_disp: Double;

    clock_coef: Double;

    rqThread: TRQThread;


    stats_path, stats_file, nosync_log, psync_log: String;
    last_pl: Integer;
    logs: TStrMap; // Список объектов-файлов

    pt: TProfileTimer;
    prv_minute: Integer;
    min_date: TDateTime;
    last_time: TDateTime;
    FShowLogConsole: Boolean;
    enable_srv: Boolean;
    enable_sst: Boolean;
    my_stratum: Integer;
    psync_cnt: Integer;
    rsync_cnt: Integer;
    sync_break, sync_now, sync_flag: Boolean;


    have_cpu_stat: Boolean;
    show_cpu_stat: Boolean;

    need_drift_stat: Boolean;

    drift_ema, drift_l, drift_h: Double;
    drift_stat: String;
       bind_ip: String;

    scl: TSystemCountersList; // для замера нагрузки процессора


    procedure   LoadConfig;
    procedure   ToggleShowLogConsole(const Value: Boolean);
    function    QueryNTPPool: TDateTime;
    function    CompareVirtualTimer(idt: Integer): TDateTime;
    procedure   SaveToLog(const filename, msg: String);
    procedure   CheckCompleteSync (tout: DWORD);
    procedure   OnSyncStat(const ip: String; port: WORD; ot, dt: TDateTime);
    procedure   UpServer;
    function    UpdateSTA (bMsg: Boolean): Boolean;
    procedure   DoAsyncTimeCheck;
    procedure   CollectCPUStat;
    function    AutoQueryRate(value: Double): Integer;
    procedure   AdjustPFCTimerSpeed ( ntp_dv: TDateTime );

  protected
    pfc_ntp_dev: TDataStatVector;
    clk_ntp_dev: TDataStatVector;
    clk_pfc_dev: TDataStatVector;
  public
    { Public declarations }

    { props }

    property    ShowLogConsole: Boolean read FShowLogConsole write ToggleShowLogConsole;

    { C & D }

    constructor CreateNew(AOwner: TComponent; Dummy: Integer = 0); override;
    destructor  Destroy; override;

    { methods }
    procedure  CheckTime;
    function   GetServiceController: TServiceController; override;
    function   GetPFCTime( main: Boolean ): TDateTime;

  end;

var
  svcTime: TsvcTime;

implementation
uses ModuleMgr, madExcept;
{$R *.dfm}

resourcestring
 DEF_NTP_HOSTS = '0.ru.pool.ntp.org;1.ru.pool.ntp.org;2.ru.pool.ntp.org;time.nist.gov;time.windows.com';


function PrecLevel (value: Double): Integer;
begin
 result := 0;
 value := Abs (value);
 if value <= 1 then exit;
 result := 5;
 if value <= 30 then result := 4;
 if value <= 15 then result := 3;
 if value <= 1  then result := 2;
 if value <= 2  then result := 1;
end; // PrecLevel


function LocalTime: TSystemTime; inline;
begin
 GetLocalTime (result);
end;

function LocalDateTime: TDateTime; inline;
begin
 result := SystemTimeToDateTime(LocalTime);
end;

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  svcTime.Controller(CtrlCode);
end;


function ReferNow: TDateTime;
begin
 if Assigned (svcTime) then
    result := svcTime.GetPFCTime (TRUE)
 else
    result := CurrentDateTime;
end;


function SuperNow: TDateTime;
begin
 if Assigned (svcTime) then
    result := svcTime.GetPFCTime (TRUE)
 else
    result := Now;
end;


{var
   SetCurrentConsoleFontEx: function (hOutput: THandle; bMaximumWindow: Boolean; pInfo: PConsoleFontIndex): Boolean; stdcall;}

constructor TsvcTime.CreateNew(AOwner: TComponent; Dummy: Integer);
var
   elp: Double;
begin
 inherited;

 ntp_hosts := TStringList.Create;
 min_dvg := 0;
 max_dvg := 1800 * 1000;
 auto_qrate := TStrMap.Create (self);
 q_rate := 1;
 logs := TStrMap.Create (self);
 logs.OwnsObjects := TRUE;
 pfc_ntp_dev := TDataStatVector.Create ( 4 );
 clk_ntp_dev := TDataStatVector.Create ( 4 );
 clk_pfc_dev := TDataStatVector.Create ( 4 );
 StartLogging('');
 LoadConfig;
 ODS( CFormat('[~d ~T]. #DBG: LocalTime service initializing. Version: %s, ServiceObject at: $%p ', '~C07', [GetFileVersionStr (''), Pointer(self)]) );

 {s := '#TEST_UNICODE: ';
 for n := $A0 to $FF do
    s := s + WideChar (n) + ' ';
 ODS (s);}

 pfc_adjust_lv := ' ';

 scl := TSystemCountersList.Create;
 scl.AddCPUCounters ('% Processor Time');

 pt := TProfileTimer.Create;
 g_timer.TestPrecision (5000);
 pt.UpdateCalibration(TRUE);
 pt.Start ($FFFFFFFF);
 pt.PFCRatio := ( MSEC_IN_HOUR + pfc_adjust ) / MSEC_IN_HOUR;
 g_timer.DiffTimer.PFCRatio := pt.PFCRatio;
 with g_timer.ActiveSlot^ do
  begin
    pfc_corr := pt.PFCRatio;
    ODS('[~d ~T]. #DBG: VirtualTimeData structure size = ' + IntToStr ( sizeof (TVirtualTimerData) ) );
   end;
 Assert ( Abs (pt.PFCRatio - 1) < 0.1, ftow ( pt.PFCRatio, 'Dangerous PFCRatio value = %.3f ' ) );
 sorter := TList.Create;
 Sleep (100);
 elp := pt.Elapsed (1);
 Assert ( elp < 1000, Format ( 'Dangerous result for PFC-timer = %f, ratio = %.8f, coef = %.9f, adj_coef = %.9f ', [ elp, pt.PFCRatio, pt.Coef, pt.AdjustedCoef ] ) );
 ODS ('[~d ~T]. #DBG: PFCRatio = ~C0D' + FormatFloat('0.00000###', pt.PFCRatio) + '~C07');
 ref_time := Now;
 pt.StartOne (VTT_TIMER, $F); // initial
 psync_log := CorrectFilePath (ExePath + '..\logs\peersync ' + FormatDateTime('yyyy-mm-dd@hh_mm', ref_time) + '.log');
 madExcept.NameThread(GetCurrentThreadId, AnsiString ('ServiceMain') );

 UpdateSTA (TRUE);
 last_pl := 5;
 // pwm_split := pwm_range div 2;
 pwm_side := 0;

 have_cpu_stat := ( scl.CollectQueryData (5) = ERROR_SUCCESS );



 if not g_timer.OwnRights then
    PrintError ('VirtualTimer has no owner rights for shared section');

  if clock_res > 0 then
   begin
    ODS ('[~d ~T]. #DBG: Executing NtSetTimerResolution with DesiredResolution =~C0D ' + IntToStr (clock_res) + '~C07' );
    SetTimerResolution ( clock_res, TRUE, target_res )
   end
  else
    SetTimerResolution ( 10064, FALSE, target_res );

 ODS ('[~d ~T]. #DBG: system timer resolution =~C0D ' + IntToStr (target_res) + '~C07');

 if g_timer.OwnRights then
    g_timer.ActiveSlot.clock_res := target_res;

 g_timer.ActiveSlot.Hash;

 // prv_ntp_time := Now;
 // TODO: check other copies TMService in memory
end; // Create

destructor TsvcTime.Destroy;
begin
 OnShutdown (self);
 ODS ('[~d ~T]. #DBG: Destroying service object.');
 Sleep (10);
 FreeAndNil ( IdSNTPSrv );
 scl.Free;
 pt.Free;
 ntp_hosts.Free;
 sorter.Free;
 auto_qrate.Free;

 pfc_ntp_dev.Free;
 clk_ntp_dev.Free;
 clk_pfc_dev.Free;

 inherited;
 FinalizeModule ('~ALL');
 logs.Clear;
 logs.Free;
 FreeConsole;
end;

function TsvcTime.GetPFCTime(main: Boolean): TDateTime;
var
    tmr: Integer;
    rft: TDateTime;
   elps: Double;
begin
 // для основного таймера, надо выбрать 3
 tmr := IfV ( main, VTT_TIMER, VTT_TIMER2);
 rft := IfV ( main, ref_time, ref_time2);
 elps   := pt.Elapsed (tmr);
 result := rft + elps * DT_ONE_MSEC;
end; // GetPFCTime

function TsvcTime.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure TsvcTime.LoadConfig;
var
   fini: TIniFile;
   s: String;
   pp: TProgramParams;
begin
 cfg_file := FindConfigFile ('tmservice.conf');
 if cfg_file = '' then exit;

 Randomize;
 pp := TProgramParams.Create;
 fini := TIniFile.Create ( cfg_file );
 try
  accuracy := 1000.0 / 64.0;
  ntp_hosts.Delimiter := ';';
  //
  bind_ip                 := fini.ReadString('config', 'BindIP', '0.0.0.0');

  ntp_hosts.DelimitedText := fini.ReadString ('config', 'NTPServers', DEF_NTP_HOSTS );

  q_rate := Max (1, fini.ReadInteger ('config', 'NTPQueryRate', 120));
  min_qrate := Max (1, fini.ReadInteger ('config', 'MinQueryRate', 1));
  max_qrate := Max (1, fini.ReadInteger ('config', 'MaxQueryRate', 60 * 24));
  s :=  fini.ReadString ('config', 'AutoQueryRate', '15@120,50@30,250@15,1000@5,3000@2,10000@1');
  auto_qrate.CommaText := AnsiReplaceStr (s, '@', '=');

  v_rate := Max (1, fini.ReadInteger ('config', 'VTSyncRate', 1));

  mcorr := fini.ReadInteger ('config', 'MicroCorr', -20);

  pfc_adjust :=   fini.ReadFloat   ('config', 'PFCAdjust', 0);
  pfc_save   :=   fini.ReadBool    ('config', 'PFCAdjustSave', FALSE);
  pfca_low   :=   fini.ReadFloat   ('config', 'PFCAdjustLow', pfc_adjust);
  pfca_high  :=   fini.ReadFloat   ('config', 'PFCAdjustHigh', pfc_adjust);
  pfca_tresh :=   fini.ReadFloat   ('config', 'PFCAdjustTreshold', 2);

  st_adjust  :=   fini.ReadInteger   ('config', 'HWClockAdjust', 0);
  clock_res  :=   fini.ReadInteger   ('config', 'HWClockRes', 0);
  hw_adjust  := st_adjust <> 0;
  sta_cpu_ratio := fini.ReadFloat    ('config', 'HWAdjustByCPULoad', 0);
  pwm_range  :=    fini.ReadInteger  ('config', 'PWMRange', 50000);
  pwm_split  :=    fini.ReadInteger  ('config', 'PWMSplit', pwm_range div 2);
  min_st_adjust := fini.ReadInteger ('config', 'MinClockAdjust', st_adjust - 250);
  max_st_adjust := fini.ReadInteger ('config', 'MaxClockAdjust', st_adjust + 250);
  clock_adjust := st_adjust <> 0;
  // hour clock dev = 240 msec, = 240 000 mcs, = 2 400 000 x 100ns units
  auto_pfc_adjust := fini.ReadBool ('config', 'AutoPFCAdjust', True);
  aprox_fact :=   fini.ReadFloat   ('config', 'AproxFactor', 0.9);

  sync_ofs     := fini.ReadInteger ('config', 'SyncOffset',  Random(q_rate)); // flood protection in minuts
  sync_timeout := fini.ReadInteger ('config', 'SyncTimeout', 25) * 1000;
  term_timeout := fini.ReadInteger ('config', 'TermTimeout', 2) * 1000;
  check_delay :=  fini.ReadInteger ('config', 'CheckDelay',  500);
  enable_srv :=   fini.ReadBool    ('config', 'EnableNTPServer', True);
  enable_sst :=   fini.ReadBool    ('config', 'EnableSyncStat',  False);
  my_stratum :=   fini.ReadInteger ('config', 'MyStratum', 2);

  s := pp.Values['show_console'];
  ODS('[~T]. #DBG: EXE paramers = ' + pp.CommaText + ', show_console = ' + s);

  ShowLogConsole := fini.ReadBool  ('config', 'ShowConsole', TRUE) or ( s <> '' );
  show_cpu_stat  := fini.ReadBool  ('config', 'ShowCPUStat', FALSE);





  stats_path := CorrectFilePath (ExePath + '..\logs\');
  stats_file := Trim ( fini.ReadString ('config', 'StatsFile', stats_path + 'timestats.csv') );
  nosync_log := Trim ( fini.ReadString ('config', 'StatsFile', stats_path + 'nosync.csv') );

  need_drift_stat := fini.ReadBool ('config', 'SaveDriftStat', False);

  s := fini.ReadString ('bounds', 'min_date', '');

  FormatSettings.ShortDateFormat := 'dd.mm.yy';

  if s <> '' then
     min_date := StrToDate (s)
  else
     min_date := Trunc (Now);

  SetPriorityClass ( GetCurrentProcess(), fini.ReadInteger('config', 'ProcessPriority', ABOVE_NORMAL_PRIORITY_CLASS));
  min_dvg := fini.ReadInteger ('bounds', 'min_dvg', 0);
  max_dvg := fini.ReadInteger ('bounds', 'max_dvg', 1800 * 1000);
  max_rqt := fini.ReadInteger ('bounds', 'max_rqt', 1000);

  ODS ( CFormat('[~d ~T]. #LOADCFG: NTPQueryRate = %d, VTSyncRate = %d, SyncOffset = %d, AproxFactor = %.4f, AutoPFCAdjust = %s, EnableNTPServer = %s', '~C07',
                [q_rate, v_rate, sync_ofs, aprox_fact, IfV(auto_pfc_adjust, 'True', 'False'), IfV(enable_srv, 'True', 'False')] ));

 finally
  fini.Free;
  pp.Free;
 end;
end;


procedure TsvcTime.UpServer;
begin
  if IdSNTPSrv <> nil then exit;
  try
    ODS('~C0B[~d ~T]. #DBG: NTP Server activation...~C07');
    IdSNTPSrv := TIdSNTPServer.Create (nil);
    IdSNTPSrv.TimeFunc := SuperNow;
    IdSNTPSrv.OnSyncStat := OnSyncStat;
    IdSNTPSrv.Stratum := my_stratum;

    with IdSNTPSrv.Binding do
     begin
       wprintf('[~d ~T]. #DBG: Listen on IP %s ', [bind_ip]);
       IP := bind_ip;
       IdSNTPSrv.Active := TRUE;
     end;
  except
   on E: Exception do
    begin
     PrintError('Exception catched while SNTPSrv.Binding ' + E.Message );
     ODS('[~d ~T]. #WARN: NTPServer feature switched off - may be UDP port 123 already used.');
     FreeAndNil (IdSNTPSrv);
     enable_srv := FALSE;
    end;
  end;
end;

procedure TsvcTime.SaveToLog(const filename, msg: String);
var
   fobj: TTextFileObj;
begin
 if filename = '' then exit;
 {$I-}

 fobj := TTextFileObj ( logs.FindObject (filename, TRUE) );
 if fobj = nil then
   begin
    fobj := TTextFileObj.Create (filename);
    logs.AddObject ( HideSP (filename), fobj );
   end;

 fobj.PutStr ( InfoFmt(msg) );
end;


procedure TsvcTime.ServiceContinue(Sender: TService; var Continued: Boolean);
begin
 ODS('[~d ~T]. #DBG: LocalTime service continued...');
 tmrCheck.Enabled := TRUE;
 Continued := TRUE;
 if Assigned ( IdSNTPSrv ) then
    IdSNTPSrv.Active := TRUE;

end;

procedure TsvcTime.ServiceCreate(Sender: TObject);
begin
 no_dialog := TRUE;
end;

procedure TsvcTime.ServicePause(Sender: TService; var Paused: Boolean);
begin
 ODS('[~d ~T]. #DBG: LocalTime service paused...');
 if Assigned ( IdSNTPSrv ) then
    IdSNTPSrv.Active := FALSE;
 tmrCheck.Enabled := FALSE;
 Paused := TRUE;
end;

procedure TsvcTime.ServiceShutdown(Sender: TService);
var
   elps: Double;
begin
 elps := pt.Elapsed (VTT_TIMER);
 if ( ref_time > 0 ) and ( ref_time < Now ) and ( elps > 10000 ) then
   begin
    ODS('[~d ~T]. #DBG: Last time synchronization...');
    IndySetLocalTime (  ref_time + elps * DT_ONE_MSEC );
   end;
 logs.Clear;
end;

procedure TsvcTime.ServiceStart(Sender: TService; var Started: Boolean);
begin
 // LoadConfig;
 ODS('[~d ~T]. #DBG: LocalTime service started...');
 if Assigned ( IdSNTPSrv ) then
    IdSNTPSrv.Active := TRUE;

 tmrCheck.Enabled := TRUE;

 Started := TRUE;
end;

procedure TsvcTime.ServiceStop(Sender: TService; var Stopped: Boolean);
begin
 ODS('[~d ~T]. #DBG: LocalTime service stopped...');
 OnShutdown (self);
 if sync_now then CheckCompleteSync (100);


 if Assigned ( IdSNTPSrv ) then
    IdSNTPSrv.Active := FALSE;
 tmrCheck.Enabled := FALSE;
 Stopped := TRUE;

 while sync_now do
  begin
   CheckCompleteSync(sync_timeout);
   Sleep (1000);
  end;
 logs.Clear;

end;


procedure TsvcTime.CheckCompleteSync;
var
   wr: DWORD;
   h: THandle;
begin
 if ( pt.Elapsed (VTT_SYNC) < tout ) and ( not sync_flag ) then exit;

 sync_now := FALSE;
 if rqThread = nil then exit;

 h := rqThread.Handle;
 wr := WaitForSingleObject (h, 100);


 if ( wr = WAIT_TIMEOUT )  then
    begin
     sync_break := TRUE;
     PrintError ('RQThread timeout execution complete for ' + IntToStr(tout) + ' msec');
     if IdSNTP1 <> nil then
        IdSNTP1.Disconnect;

     if WaitForSingleObject (h, term_timeout) = WAIT_TIMEOUT then
       begin
        PrintError ('Forced terminating RQThread');
        TerminateThread (h, 300);
        WaitForSingleObject (h, 1500);
       end;
     FreeAndNil (IdSNTP1);
     rqThread := nil;
     sync_flag := FALSE;
    end; // if timeout


end; // CheckSyncTimeout


procedure TsvcTime.CollectCPUStat;
var
   load: Single;
   sco: TSystemCounter;
   fmv: PDH_FMT_COUNTERVALUE;
   sz, i, cc: Integer;
   by_core: String;
   sum: Double;

begin
 load := 0;
 cc := 0;
 by_core := '';

 for i := 0 to scl.Count - 1 do
  begin
   sco := scl.items [i];
   if sco = nil then continue;
   fmv := sco.GetFmtValue (PDH_FMT_DOUBLE);
   if fmv.cStatus <> ERROR_SUCCESS then continue;
   fmv.doubleValue := fmv.doubleValue / 100;
   load := load + fmv.doubleValue;
   by_core := by_core + Format (' %d @ %.2f |', [i, fmv.doubleValue]);


   Inc (cc);
  end;

 if cc = 0 then exit;
 load := load / cc;

 sz := High (lst_cpu_load) + 1;
 if cnt_cpu_load < sz then
    Inc (cnt_cpu_load)
 else
    Move ( lst_cpu_load[1], lst_cpu_load[0], sizeof(Double) * (sz - 1) );
 lst_cpu_load [cnt_cpu_load - 1] := load;
 sum := 0;
 for i := 0 to cnt_cpu_load - 1 do
     sum := sum + lst_cpu_Load [i];

 avg_cpu_load := sum / cnt_cpu_load;




 if ( log_verbose >= 3 ) and ( show_cpu_stat ) then
    ODS( CFormat('[~d ~T]. #DBG: median CPU load = %.4f, by core = {%s }', '~C07', [load, by_core]));

end;


procedure TsvcTime.tmrCheckTimer(Sender: TObject);

begin
 tmrCheck.Enabled := FALSE;
 try
  DoAsyncTimeCheck;
 finally
  tmrCheck.Enabled := TRUE;
 end;
end;


procedure TsvcTime.DoAsyncTimeCheck;
begin
 if (n_ticks > 5) and (prv_minute = LocalTime.wMinute) then exit;


 if rqThread <> nil then exit;
 if (n_ticks = 5) or (n_ticks = 3) and IsDebuggerPresent then
   begin
    tmrCheck.Interval := 30000; // 30 second
    tmrFast.Interval := 50;

    if enable_srv then
       UpServer;
   end;

 // creating independed thread for actioning
 sync_flag := FALSE;
 rqThread := TRQThread.Create (TRUE);
 try
  SetThreadAffinityMask (rqThread.Handle, 1); // only one core allowed!
  rqThread.Priority := tpHigher;
  rqThread.FreeOnTerminate := TRUE;
  sync_now := TRUE;
  pt.StartOne (VTT_SYNC);
  rqTHread.Start;
 finally
  Inc (n_ticks);
  pt.StartOne (VTT_LAST_START);
 end;

end;

procedure TsvcTime.tmrFastTimer(Sender: TObject);
var
    dsw: Integer;
   elps: Double;
     ch: CHAR;
     ct: TDateTime;
      s: String;
begin

 g_timer.GetTime;
 Inc ( timer_loops );

 if IsKeyPressed( Ord('A') ) and IsKeyPressed ( VK_CONTROL ) and IsKeyPressed ( VK_MENU ) and ( no_dialog ) then
    begin
     no_dialog := FALSE;
     s := InputBox('Pls enter new value', 'HWClockAdjust ms/h', IntToStr ( st_adjust ) );
     no_dialog := TRUE;
     dsw := Abs ( atoi (s) );
     if Abs ( dsw - st_adjust ) > 100000 then
        PrintError ('Value vs previuous must be diff. less whan 100k')
     else
       begin
        st_adjust := dsw;
        ODS( ftow( st_adjust, '[~T]. #DBG: st_adjust assigned value = %.1f' ) );
        UpdateSTA ( TRUE );
       end;
    end;



 if timer_loops mod 10 <> 0 then exit;

 if sync_now then
    CheckCompleteSync(sync_timeout)
 else
   begin
     if have_cpu_stat and ( scl.Count > 0 ) and ( scl.QueryEvent.WaitFor (250) = wrSignaled ) then
       begin
        scl.QueryEvent.ResetEvent;
        CollectCPUStat;
       end;


    if (pwm_range > 0) and (pwm_allow) then
     begin
      // выбор периода быстрого/медленного времени
      dsw := IfV (pwm_side = 0, pwm_split, pwm_range - pwm_split);
      elps := pt.Elapsed (VTT_PWM);

      if (elps < dsw) and (dsw - elps < 500) then
         begin
          Sleep ( Round (dsw - elps) + 16 );
          elps := pt.Elapsed (VTT_PWM);
         end;


      if elps >= dsw then
       begin
        pt.StartOne (VTT_PWM);
        pwm_side := pwm_side xor 1;

        if pwm_side = 0 then
           Inc (st_adjust, 25)
        else
           Dec (st_adjust, 25);

        UpdateSTA ( log_verbose >= 7 );

       end;



     end;

    {coef := pt.UpdateCalibration;
    if coef <> prv_coef then
       ODS(CFormat('[~d ~T]. #DBG: PFC main coef (x1e9) = %.5f, prv_coef (x1e9) = %.5f', '~C07',  [coef * 1e9, prv_coef * 1e9]));
    prv_coef := coef;}
   end;

 if need_drift_stat and (ref_time > 0) then
  begin
   ct := CompareVirtualTimer (0);
   if drift_stat = '' then
      drift_stat := InfoFmt ('~D ~T', Now);
   if drift_ema = 0 then
     begin
      drift_ema := ct;
      drift_l := ct;
      drift_h := ct;
     end;


   drift_ema := drift_ema * 0.9 + ct * 0.1;
   drift_l := Min (drift_l, ct);
   drift_h := Max (drift_h, ct);

   ct := ct / DT_ONE_MSEC;
   drift_stat := drift_stat + ftow (ct * 1000, ';%.0f '); // microseconds
  end;

 ch := UpCase (ReadKey);
 if CharInSet ( ch, ['E', 'У'] ) then
   begin
    ODS('[~d ~T]. #DBG: Shutdown initiated by keyboard...');
    tmrCheck.Enabled := FALSE;

    while sync_now do
     begin
      CheckCompleteSync(sync_timeout);
      Sleep (1000);
     end;
    logs.Clear;
    // Application.ExecuteAction
    // self.Free;
    Forms.Application.Terminate;

    // DoShutdown;
    // self.Free;
    exit;
   end;
 if CharInSet ( ch, ['V', 'М'] ) then
  begin
   Inc (p_shared_vars.log_verbose_level);
   if log_verbose > 7 then
      p_shared_vars.log_verbose_level := 0;

   ODS('[~d ~T]. #DBG: Verbosity changed by keyboard =~C0D ' + IntToStr (log_verbose) + '~C07');
  end;

 if CharInSet ( ch, ['+', '-'] ) then
  begin
   st_adjust := st_adjust + IfV ( ch = '+', +15, -15 );
   UpdateSTA (TRUE);
  end;


end;

procedure TsvcTime.OnSyncStat (const ip: String; port: WORD; ot, dt: TDateTime);
begin
 if n_ticks < 5 then
   SetThreadPriority (GetCurrentThread, THREAD_PRIORITY_ABOVE_NORMAL);

 if enable_sst then
   begin
    if dt > 0 then
      begin
       Inc ( psync_cnt );
       SaveToLog (psync_log, '[~d ~T]. #STAT: '  + IfV( Pos('192.168.', ip) = 1, 'LocalPeer ', 'Peer ') +
                              ip + ' org_ts { ' + FormatDateTime ('dd mmm yyyy hh:mm:ss.zzz', ot) + ' }.' +
                                   ' ret_ts { ' + FormatDateTime ('dd mmm yyyy hh:mm:ss.zzz', dt) + ' }. Sync count = ' + IntToStr(psync_cnt) +
                              ', rate = ' + ftow (1000.0 * psync_cnt / Max (1, pt.Elapsed (PS_LIVE_TIME) ), '%.1f') + ' per/sec.')
      end
    else
       ODS('[~d ~T].~C0C #WARN:~C07 Peer ~C0F' + ip + '~C07 not served. Incoming [S]NTP DATAGRAM to small/wrong: ' +
           IntToStr (port) + ' vs real ' + IntToStr (sizeof (TNTPGram)) );
   end;
end;

procedure TsvcTime.ToggleShowLogConsole(const Value: Boolean);
begin
 FShowLogConsole := Value;
 if Value then
  begin
   ShowConsole (SW_SHOW);
   SendMessage (hWndCon, WM_SETFONT, hConFont, 1);
  end
 else
   ShowConsole (SW_HIDE);
end;


type
   TDVGREC = record
     prior: Double;
       rqt: Double;
       rtd: Double;
       dvg: Double;
      disp: Double;
    weight: Double;
   end;

   PDVGREC = ^TDVGREC;

function cmpAbsDouble (a, b: Pointer): Integer;
var
   av: PDouble absolute a;
   bv: PDouble absolute b;
begin
 result := Sign ( Abs (av^) - Abs (bv^) );
end;


function cmpDisp (a, b: Pointer): Integer;
var
   av: PDVGREC absolute a;
   bv: PDVGREC absolute b;
begin
 result := 0;
 if av.disp > bv.disp then result := +1;
 if av.disp < bv.disp then result := -1;
end;

procedure SetLocalTimeDT (dt: TDateTime);
var
   st: TSystemTime;
begin
 DateTimeToSystemTime (dt, st);
 SetLocalTime (st);
end;

function FmtDelay (f: Double; min_chars: Integer = 7; const flags: String = 's'): String; // 0.00
const
    MSEC_IN_HR = 3600 * 1000;
    MSEC_IN_DAY = 24 * MSEC_IN_HR;
var
   sfx, col: Boolean;
   dt: TDateTime;
   st, cc: String;
begin
 result := '';
 sfx := ( Pos ('s', flags) > 0 );
 col := ( Pos ('c', flags) > 0 );
 cc := IfV (col, '~C07', '');

 if sfx then
  begin
   dt := Frac ( f * DT_ONE_MSEC );
   st := FormatDateTime ('hh:nn:ss', dt);
   if ( Abs (f) >= MSEC_IN_DAY ) then
     result := IfV(col, '~CCF', '') + IfV(f > 0, '+', '-') + ftow ( Trunc (f / MSEC_IN_DAY), '%.0f days ') + st + ' '
   else
   if Abs (f) >= MSEC_IN_HR then
     result := IfV(col, '~C0C', '') + st // FormatFloat('0.000', f / MSEC_IN_HR) + ' hrs'
   else
   if Abs (f) >= 500 then
     result := IfV(col, '~C0E', '') + FormatFloat('0.0000', f / 1000.0) + ' sec'
   else
   if Abs (f) < 10.0 then
     result := IfV(col, '~C0A', '') + FormatFloat('0', f * 1000.0) + ' µs'
   else
     result := IfV(col, '~C0A', '') + FormatFloat('0.00', f) + ' ms'

  end;

 if result = '' then
   result := IfV(col, '~C0A', '') + FormatFloat('0.00', f) + cc + '';


 while ( Length(result) < min_chars + IfV(col, 3, 0) + IfV(sfx, 4, 0) ) do
         result := ' ' + result;


 if col then
   begin
    result := AnsiReplaceStr (result, ' µs', ' ~C0Fµs');
    result := result + cc;
   end;
end;


function TsvcTime.QueryNTPPool: TDateTime;


var
    i, n, ccnt: Integer;
   max_url_len: Integer;
   svd: TDateRec32;
   svt: TTimeRec32;
   ct, dt, clock_div, dvg_sum: TDateTime;
   dvg_rec, ref_rec: PDVGREC;
   dvg_lst: array [0..15] of TDVGREC;
   s, msg, tt, dbg: String;
   rqt: Double;
    st: TSystemTime;

begin
 result := 0;
 i := 0;
 ccnt := 0;
 dvg_sum := 0;


 sorter.Clear;

 while ntp_hosts.Count > 16 do
       ntp_hosts.Delete (0);

 if ntp_hosts.Count = 0 then exit;

 ntp_dt := 0;
 // --------------- MAINS LOOP ---------------- //
 IdSNTP1 := TIdSNTP.Create (nil);
 IdSNTP1.Active := FALSE;
 IdSNTP1.ReceiveTimeout := 2000;
 IdSNTP1.TimeFunc := ReferNow;
 IdSNTP1.mcs := mcorr;
 FillChar (dvg_lst[0], sizeof(TDVGREC) * 16, 0);
 try
   max_url_len := 5;
   for n := 0 to ntp_hosts.Count - 1 do
       max_url_len := Max ( max_url_len, Length (ntp_hosts[n]) );


   for n := 1 to Max(5, ntp_hosts.Count) do
   begin
    if ( n_ticks <= 2 ) or (IdSNTP1 = nil) or (sync_break) then break;


    s := Trim (ntp_hosts [i]);

    Inc (i);
    if i >= ntp_hosts.Count then i := 0;

    if s = '' then continue;

    if i > 255 then break;

    if Now < ban_times [i] then continue; // ignored by ban




    IdSNTP1.Host := s;

    // ODS('[~d ~T]. #DBG: Connecting NTP server ~C0A' + s + '~C07...');
    rqt := 0;
    dt := 0;
    ct := 0;

    // ================================== NTP TRANSACTION =========================== //
    try
     Sleep (100);
     // TickAdjust (1);
     ct := GetPFCTime ( TRUE );


     DateTimeToSystemTime ( ct + 2 * DT_ONE_MSEC, st );
     dt := SystemTimeToDateTime ( st ); // округленно до мс.
     // подгонка к мс
     repeat
      asm
       pause
       pause
       pause
      end;
      ct := GetPFCTime ( TRUE );
     until ct >= dt;


     p_shared_vars.local_dt := ct;

     pt.StartOne (2, 1);

     dt := IdSNTP1.DateTime;        // <<<<<<<<<<<<<<<<<============================

     svt := IdSNTP1.ServerTime;
     svd := IdSNTP1.ServerDate;
     rqt := pt.Elapsed (2);         // время полное запроса в миллисекундах
    except
     on E: Exception do
      begin
       ODS('[~d ~T]. #DBG: Exception catched while executing IdSNTP1.DateTime: ' + E.Message );
      end;
    end;
    // ============================================================================== //



    ct := ct + ( rqt * DT_ONE_MSEC ); // precision time with delay

    if dt = 0 then
      begin
       ODS('[~d ~T]. #MSG: Query to NTP Server ~C0E[' + IdSNTP1.Host + ']~C07 -~C0C failed~C07');
       continue;
      end;

    ntp_dt := dt + (rqt / 2) * DT_ONE_MSEC; // average server time

    if svd.date32 <> 0 then
       ntp_dt := EncodeDate ( svd.yyyy, svd.mm, svd.dd ) + EncodeTime ( svt.hh, svt.mm, svt.ss, 0 );



    // target time, by TIdSNTP.Sync source code also includes
    { if rqt * 3 < IdSNTP1.RoundTripDelay then // the lower measure - true
       dt := IdSNTP1.OriginateTimestamp + rqt + IdSNTP1.AdjustmentTime
    else }

    dt := IdSNTP1.OriginateTimestamp + IdSNTP1.RoundTripDelay + IdSNTP1.AdjustmentTime;

    if ( Abs (ntp_dt - dt) > 5 * DT_ONE_SECOND ) then
        begin
         ODS(CFormat('[~d ~T].~C0C #WARN:~C07 Time response %s overrides with %s, due 5 seconds error', '~C07',
                 [FormatDateTime('hh:nn:ss.zzz', dt), FormatDateTime('hh:nn:ss.zzz', ntp_dt) ]) );
         dt := ntp_dt;
        end;

    clock_div := (dt - ct); // положительное, если текущие часы отстают от источника



    if rqt < max_rqt then
     begin
      dvg_lst [ccnt].rtd := IdSNTP1.RoundTripDelay;
      dvg_lst [ccnt].rqt := rqt; // используется для оценки толерантности
      dvg_lst [ccnt].dvg := clock_div;
      dvg_lst [ccnt].disp := 0;
      dvg_lst [ccnt].weight := 100 / Max (1, IdSNTP1.Stratum * 10 + rqt);
      dvg_lst [ccnt].prior := Abs (clock_div) + Abs (IdSNTP1.RoundTripDelay * 0.1);

      sorter.Add ( @dvg_lst [ccnt] ); // в сортировку
      dvg_sum := dvg_sum + clock_div; // накопление дистанции
      Inc (ccnt);
     end;

    while Length (s) < max_url_len do s := s + ' ';

    if IsKeyPressed (VK_CONTROL) and IsKeyPressed (VK_MENU) then
       tt := TimeToStrMS ( idSNTP1.OriginateTimestamp, 6 ) + ' / ' + TimeToStrMS ( idSNTP1.TransmitTimestamp, 6 )
    else
       tt := TimeToStrMS ( dt, 6 );

     msg := Format('~C0F[~d ~TL]. #NTP(%d): NTPS ~C0E%s]~C07 ret ~C0A { %s }~C07, diver. = %s,' +
                  'RTD = %s, AJT = %s, RQT = %s, STR =~C0D %d ',
                  [i, s,
                  FormatDateTime ('dd mmm yyyy ', dt) + tt,
                  FmtDelay (clock_div / DT_ONE_MSEC, 7, 'cs'),
                  FmtDelay (IdSNTP1.RoundTripDelay / DT_ONE_MSEC, 7, 'cs'),
                  FmtDelay (IdSNTP1.AdjustmentTime / DT_ONE_MSEC, 7, 'cs') ,
                  FmtDelay (rqt, 7, 'cs'),
                  IdSNTP1.Stratum]);

     if (i and 1 = 0) then
        msg := AnsiReplaceStr(msg, '~C0', '~C8');
     ODS(msg + '~C07');

    // Sleep( 1 );
   end;
 finally
  FreeAndNil (IdSNTP1);
 end;

 if ccnt = 0 then exit;
 sorter.Sort ( cmpAbsDouble );

 result := dvg_sum / ccnt; // грубый результат

 s := '';

 ccnt := Max ( Min (sorter.Count, 4), sorter.Count - 2); // отбросить самые худшие результаты по Roundtrip Delay

 if ccnt < 3 then
    ccnt := sorter.Count;
 for n := sorter.Count - 1 downto ccnt do
     sorter.Delete (n); // подчистка списка

 // подсчет квадрата отклонения каждого значения, относительно каждого
 for n := 0 to ccnt - 1 do
  for i := 0 to ccnt - 1 do
   begin
    if i = n then continue;
    dvg_rec := sorter [n];
    ref_rec := sorter [i];
    dt := Sqr( dvg_rec.dvg / DT_ONE_MSEC - ref_rec.dvg / DT_ONE_MSEC );
    dvg_rec.disp := dvg_rec.disp + dt;
   end;

 sorter.Sort ( cmpDisp );

 i := Max ( Min (sorter.Count - 2, 2), sorter.Count - 3); // отбросить самые худшие результаты по отклонению

 ccnt := 0;

 dvg_sum := 0;
 // пропорциональное разделения веса оставшихся
 for n := 0 to i do
  begin
   dvg_rec := sorter [n];
   dvg_sum := dvg_sum + dvg_rec.weight;
  end;

 if dvg_sum <= 0 then exit;
 dvg_sum := dvg_sum / (i + 1);


 // преобразование в долевой вес
 for n := 0 to i do
  begin
   dvg_rec := sorter [n];
   dvg_rec.weight := dvg_rec.weight / dvg_sum
  end;


 dvg_sum := 0;


 // формирование сальдо дивергенции, из самых лучших результатов
 for n := 0 to i do
  begin
   dvg_rec := sorter [n];
   s := s + FmtDelay ( dvg_rec.dvg / DT_ONE_MSEC ) + ':' + FormatFloat('0.000 ', dvg_rec.weight);
   dvg_sum := dvg_sum + dvg_rec.weight *  dvg_rec.dvg;
   Inc (ccnt);
  end;

 if ccnt = 0 then exit;
 if dvg_sum <> 0 then
    result := dvg_sum / ccnt;

 ntp_disp := 0;
 for n := 0 to ccnt - 1 do
   begin
    dvg_rec := sorter [n];
    ntp_disp := Max (ntp_disp, Abs(dvg_rec.dvg - result));
   end;

 ODS ('[~d ~T]. #DBG(' + IntToStr(n_ticks) + '): Stricted dvg:weight list =~C0A { ' + s + ' }~C07, ntp_diver = ~C0D' +
       FmtDelay ( result / DT_ONE_MSEC ) + '~C07, max_error = ~C0D' + FmtDelay ( ntp_disp / DT_ONE_MSEC ) + '~C07');
end; // QueryNTPPool


function TsvcTime.CompareVirtualTimer(idt: Integer): TDateTime;
var
   ct, dt: TDateTime;
   r1, r2: TDateTime;
begin
 TickAdjust (2);
 ct := CurrentDateTime;
 dt := GetPFCTime( TRUE );
 r1     := ( dt - ct );
 result := ( dt - LocalDateTime );
 if Abs(r1) > Abs(result) then
    result := r1;
end;

function TsvcTime.AutoQueryRate (value: Double): Integer;
var
   ex: Double;
   n: Integer;
   s: String;
begin
 result := IfV (auto_qrate.Count > 0, 0, 15);
 for n := 0 to auto_qrate.Count - 1 do
  begin
   s := auto_qrate.names [n];
   ex := auto_qrate.FloatValues [s];
   if value < ex then continue;

   result := atoi (s);
   result := Max (result, min_qrate);
   result := Min (result, max_qrate);
   exit;
  end;

 if result = 0 then
    result := atoi (auto_qrate.Names [0]);

 result := Max (result, min_qrate);
 result := Min (result, max_qrate);
end;


procedure TsvcTime.AdjustPFCTimerSpeed;
var
   deviation, dt, pfc_period,
    diver_ms, diver_per_hr,
    ntp_period: Double;
     real_time: TDateTime;
      pfc_time: TDateTime;
      ntp_time: TDateTime;
        g_diff: TDateTime;
       g_ratio: Double;
       t_ratio: Double;
         afact: Double;
          fini: TIniFile;
          slot: TVirtualTimerRecord;
         ticks: TPFCValue;

             i: Integer;
begin // ntp_dv == расхождение серверного и опорного периода в сутках
  diver_ms := ntp_dv / DT_ONE_MSEC;
  Sleep (1); // чтобы был квантик
  afact := g_timer.ActiveSlot.aprox_pfc;
  // pt.UpdateCalibration(TRUE); // пересчет AdjustedCoef исходя из частоты
  // TickAdjust(2);
  ticks      := pt.GetTimeStamp - pt.TimerStarted(VTT_TIMER);
  pfc_period := pt.Elapsed ( VTT_TIMER );
  pfc_time   :=  GetPFCTime ( TRUE ); // ref_time + pfc_period


  pt.StartOne (VTT_TIMER, $F);       // MAIN SYNC.1
  ntp_time   := pfc_time + ntp_dv;    // используется просто задержка опорного времени от серверного

  // замеряется точное время = системное время - ошибка системного времени (апрокс.), и включается отсчет точным таймером
  wprintf('[~d ~T].~C0E #PFC_DBG:~C07 ticks elapsed =~C0D %d~C07, AdjustedCoef =~C0D %.11f~C07',
                  [ticks, pt.AdjustedCoef]);

  ODS ( CFormat ('[~d ~T].~C0F #PROF(sync): ref_time = %s, pfc_time = %s, ntp_time = %s ~C07', '~C0F',
                     [TimeToStrMS ( ref_time, 6 ), TimeToStrMS ( pfc_time, 6 ), TimeToStrMS ( ntp_time, 6 ) ] ) );

  ref_time := ntp_time; // MAIN SYNC.2
  if prv_ntp_time > 0 then
     ntp_period := (ntp_time - prv_ntp_time) / DT_ONE_MSEC // оценка времени от предыдущего запроса в мс.
  else
     ntp_period := pfc_period;

  // ntp_period    := pfc_period + diver_ms;
  t_ratio := ntp_period / pfc_period * pt.PFCRatio;  // целевой коэффициент PFCRatio

  // ratio := 0;
  prv_ntp_time := ntp_time;

  if ntp_period < 10 then exit;

  // рассчет реалистичного значения коэффициента PFC, через значения NTP ответов

  if ntp_period > 1000 then
     deviation := ( ntp_period - pfc_period ) // если виртуальный таймер быстрее атомных часов (.300 vs .200), будет минусовая разница
  else
     deviation := diver_ms;


  dt           := MSEC_IN_HOUR * deviation / ntp_period; // первод в формат "расхождение в час"
  diver_per_hr := MSEC_IN_HOUR * diver_ms  / ntp_period;

  if ( Abs (dt) > 500 ) or ( pfc_period < 20000 ) then
      begin
       clk_pfc_dev.Clear;   // статистика ложная
       pfc_ntp_dev.Clear;
      end;



  //  if Abs (dt) > 10 * MSEC_IN_MIN  then exit; // какое-то несусветное расхождение однако (10 min)


  ODS( Format('[~d ~T]. #PROF:~C0E DIFF~C0F ( NTP period (%s~C0F ) - PFC period (%s~C0F ) )~C07 = %s (~C0F%.4f~C07 %%), ' +
              ' diver/h =~C0F %.2f~C07 ms, PFCAdjust(' +
                 pfc_adjust_lv + ') =~C0D %.4f~C07, PFCRatio = ~C0D %.7f~C07 ',
            [FmtDelay (ntp_period, 7, 'sc'),
             FmtDelay (pfc_period, 7, 'sc'),
             FmtDelay (deviation, 7, 'sc'),  // расхождение за период
             100 * deviation / ntp_period,
             diver_per_hr,
             pfc_adjust,
             pt.PFCRatio]) +
                ' VTT~C0E ' + IfV (pfc_period < ntp_period, 'slower', 'faster') + '~C07 than NTP source' );


  // стабилизация скорость виртуальных часов, и подгонка времени... все ещё не понятно что к чему.
  dt := dt * 0.9 + diver_per_hr * 0.1;

  if g_timer.OwnRights then
   begin
    diver_ms  := g_timer.DiffTimer.Elapsed(1);
    real_time := pfc_time + pt.Elapsed(VTT_TIMER) * DT_ONE_MSEC; // идеально точное время на сейчас
    // GetTime использует (pfc_current - active_slot.pfc_base) со всеми коэффициентами
    g_diff    := g_timer.GetTime(TRUE) - real_time;
    g_diff    := g_diff / DT_ONE_MSEC;

    if ( Abs (g_diff) >= 1 ) then
      begin
       g_ratio  := g_timer.DiffTimer.PFCRatio;

       if Abs(g_diff) > 1000 then // слишком большое расхождение
          g_timer.SyncWith ( pt, VTT_TIMER, ref_time );

       slot      := g_timer.ActiveSlot^;
       // slot.base     := real_time;
       // slot.pfc_coef := pt.Coef;
       // slot.pfc_base := g_timer.DiffTimer.GetTimeStamp;
       if  (pfc_period > 20000) then
         begin
           // за следующий период желательно сократить разницу в 2 раза, необходимо повысить/понизить скорость
           // разница добавляется с запасом в %
           deviation := (pt.PFCRatio - g_ratio) * 1.01 ; // положительно, при условии большей скорости опорного
           if (g_diff > 0) then
               // при спешке ведомого таймера, лучше использовать минимальную скорость из возможных
               g_ratio := Min (g_ratio, g_ratio + deviation - 0.000001)
           else // при отставании ведомого, соответственно наоборот
               g_ratio := Max (g_ratio, g_ratio + deviation + 0.000001);

           wprintf('[~d ~T].~C0C #WARN:~C07 g_timer not sync, hurry diff = %.1f ms, elapsed from last = %.1f ms,'
                 + ' ratio =~C0D %.11f~C07, bearing ratio =~C0D %.11f~C07, used diff = ~C0D %.11f~C07'  ,
                 [g_diff, diver_ms, g_ratio, pt.PFCRatio, deviation]);


           g_timer.DiffTimer.PFCRatio := g_ratio;
           slot.pfc_corr := g_ratio;
           // g_timer.DiffTimer.StartOne(1);
           g_timer.Update ( slot );
         end;
       g_timer.DiffTimer.StartOne(1);
      end;
    slot.pfc_dvg := dt; // расхождение периодов, статистическое значение и только
   end
  else
   ODS('[~T].~C0C #WARN:~C07 g_timer.OwnRights = false ');

  // если скорость расходится 16 мс в час, это погрешность измерений
  if  ( pfc_period < 20000 ) or ( Abs(diver_per_hr) < 16 ) then
    begin
     pt.StartOne (VTT_PERIOD, $F);
     exit;
    end;
  pfc_ntp_dev.Add ( dt );
  // статистически высчитанная погрешность виртуального таймера за один час
  dt := pfc_ntp_dev.StatMedian;
  // dt := dt / ONE_MSEC;                 // превратить в миллисекунды
  ODS( ftow(dt, '[~d ~T]. #PROF: Median divergence calculated as~C0D %.3f~C07 ms/h ') );
  if ( pfc_ntp_dev.Count < pfc_ntp_dev.Size ) then
      dt := dt * 0.1
  else
      dt := dt * afact;




  pfc_adjust := pfc_adjust + dt;
  pfc_adjust := Min (pfc_adjust, pfca_high);
  pfc_adjust := Max (pfc_adjust, pfca_low);

  ODS( Format('~C0F[~d ~T]. #DBG:~C0A pfc_adjust~C0F corrected with value~C0D %.3f~C0F ms/h =~C0D %.1f~C0F ms/h ~C07', [dt, pfc_adjust] ) );
  pt.PFCRatio := ( MSEC_IN_HOUR + pfc_adjust ) / MSEC_IN_HOUR;
  pt.UpdateCalibration(TRUE);
  ODS( Format (#9#9'       #DBG: PFCRatio normalized = ~C0D%.11f~C07, target =~C0D %.11f~C07,  corrected period = %s, ActiveSlot.index =~C0D %d ~C07',
                          [pt.PFCRatio, t_ratio, FmtDelay ( pt.Elapsed (VTT_PERIOD), 7, 'sc'), g_timer.ActiveSlot.slot_idx ] ) );
  pt.StartOne (VTT_PERIOD, $F);  // MAIN SYNC

  i := q_rate;

  if (pfc_ntp_dev.Count = pfc_ntp_dev.Size) and (Abs(g_diff) < 1.0) then
    begin
     pfc_ntp_dev.Clear;
     i := AutoQueryRate ( Abs(dt) );
    end;

  if i <> q_rate then
    begin
     q_rate := i;
     ODS('[~d ~T]. #DBG: NTPQueryRate changed to ~C0D' + IntToStr(i) + '~C07 min.');
     if log_verbose >= 7 then Windows.Beep (1000, 100);
    end;

 if pfc_save and ( cfg_file <> '' ) then
  begin
   fini := TIniFile.Create ( cfg_file );
   fini.WriteFloat ('config', 'PFCAdjust', pfc_adjust);
   fini.Free;
  end;
end;


procedure TsvcTime.CheckTime;

var
   st: TSystemTime;
   minutes: Integer;
   add, calct, ct, ctc, dt, dta: TDateTime;
   ntp_diver, ref_dta, accel: Double;
   n, pwm_step: Integer;
   // max_v, min_v: Double;
   dta_ms, abs_ms, last_sync_elps, last_chk_elps: Double;
   sync_expected: Boolean;
   ntp_sync, stab_cross: Boolean;
   slot: TVirtualTimerRecord;
   s: String;



begin
 sync_break := FALSE;

 if n_ticks = 1 then
   begin
    ODS ('[~d ~T]. #DBG: Detecting system timer precision...');
    TickAdjust(1);
    pt.StartOne (VTT_PREC, $F);
    ct := TickAdjust (100) / 100000.0;
    dt := pt.Elapsed (VTT_PREC);
    clock_coef := pt.ClocksElapsed (VTT_PREC);  ; // must be 1 / (mega-clocks in millisecond)
    if clock_coef > 0 then
       clock_coef := dt / clock_coef;

    accuracy :=  Round ( dt * 100 ) / 10000; // round to 4 digits

    if min_dvg <= 0 then
       min_dvg := accuracy;
    ODS ( CFormat ('[~d ~T]. #DBG:~C0E 100~C07 timer ticks requires about %.2f msec, so 1 tick = %.4f msec, loops/tick = %.3f K ', '~C07', [dt, accuracy, ct]) );

   end;



 TickAdjust(2);
 ref_time2 := CurrentDateTime;
 pt.StartOne (VTT_TIMER2);
 GetLocalTime (st);

 dt := ref_time2; // SystemTimeToDateTime (st);

 if n_ticks > 2 then
  begin
   dta := Abs (dt - last_time);
   if dta > 1 then
    begin
     PrintError ('Extremal time divergence detected, last_time = ' + FormatDateTime('dd.mm.yyyy hh:nn:ss.zzz', last_time ) +
                 ', Local time = ' + FormatDateTime('dd.mm.yyyy hh:nn:ss.zzz', dt ) +
                 ', Abs diver. = ' + FormatFloat ('0.##', dta ) + ' days');

     last_time := last_time + pt.Elapsed * DT + DT_ONE_MSEC;

     DateTimeToSystemTime (last_time, st);

     SetLocalTime (st);
     exit;
    end;
  end;


 last_time := dt;
 pt.StartOne (1, 1);


 if (n_ticks > 5) and (prv_minute = st.wMinute) then exit;

 prv_minute := st.wMinute;

 ODS('[~d ~T].~C08 #DBG(SyncFrame): -------------------------------------------------------------------------------------------------~C07');

 if ( prv_minute mod 10 = 0 ) and Assigned (IdSNTPSrv) then
    ODS( CFormat('[~d ~T].~C0E #STAT: Summary traffic, incoming = %.1f KiB, outcoming = %.1f KiB ~C07', '~C07',
                [IdSNTPSrv.InTraffic / 1024.0, IdSNTPSrv.OutTraffic / 1024.0]) );

 Sleep (check_delay);

 dta := 0;


 ntp_sync := FALSE;

 minutes := ( st.wHour * 60 + st.wMinute + sync_ofs ); // время с заданной защитой от флуда


 if drift_stat <> '' then
   begin
    SaveToLog (stats_path + 'vtdrift.stat', drift_stat);
    drift_stat := '';
   end;


 ct := 0;

 ntp_diver := 0;
 // ******************************************************************************************************************************* //
 // ==================================== Запрос времени у пула серверов =========================================================== //
 // Buzzz                                                                                                                           //

 if ( ( minutes mod q_rate = 0) or (n_ticks <= 5) or ( Abs (ct) >= 10 * min_dvg ) ) and
      ( ref_time <> 0 )  then
     begin
      ntp_diver := QueryNTPPool;                 // получение расхождения времени системного(?) таймера и серверов источников.
      if ( ntp_dt = 0 ) or ( ntp_diver = 0 ) then exit;
      ntp_sync := TRUE;
      DateTimeTools.ps_start_time := ntp_dt - pt.Elapsed (PS_LIVE_TIME) - 0.1; // подавление ругани
      wprintf('~C0B[~d ~T]. #DBG(ntp/sys):~C07 ntp_time = %s, precise = %s, local = %s ',
                [FormatDateTime('hh:nn:ss.zzz', ntp_dt + pt.Elapsed(2) * DT_ONE_MSEC) ,
                 FormatDateTime('hh:nn:ss.zzz', PreciseTime),
                 FormatDateTime('hh:nn:ss.zzz', LocalDateTime)]);


      // clk_ntp_dev.Add (ntp_dev);

      if Abs (ntp_diver) > 7 then
         begin
          ODS('[~d ~T].~C0C #WARN: Hard time syncrhonizing - more than one week delta correction. ntp_date =~C0F { ' +
                FormatDateTime('dd mmm yyyy hh:nn:ss.zzz }', ntp_dt) + '~C07 ');
          SetLocalTimeDT (ntp_dt);
          last_time := ntp_dt;
          ref_time := ntp_dt;
          pt.startOne (VTT_TIMER, $F); // HARDSYNC
          pt.startOne (VTT_PERIOD, $F);
          n_ticks := 0;
          exit;
         end;
     end;




 /// =================================== СИНХРОНИЗАЦИЯ ВИРТУАЛЬНОГО ТАЙМЕРА С СЕТЕВЫМ ВРЕМЕНЕМ =========================
 if ntp_sync and ( Abs (ntp_diver / DT_ONE_MSEC) > 0.01 ) then
  begin
   // ======================================== Автоподстройка виртуального таймера =================================================== //
   AdjustPFCTimerSpeed ( ntp_diver );
   Inc (rsync_cnt);

   // sys_pfc_dev.Clear;  // чтобы статистика не сбивалась

   if rsync_cnt > 2 then
      SaveToLog ( stats_file, InfoFmt ('~D ~t;') + FormatFloat('0.00', ntp_diver / DT_ONE_MSEC) + ';' + FormatFloat('0.00', ct / DT_ONE_MSEC) + ';' +
                  FormatFloat('0.0', (ntp_diver + cum_dvg) / DT_ONE_MSEC) + ';' +
                  FormatFloat('0.0', pfc_ntp_dev.Last) + ';' + FormatFloat ('0.0000', pfc_adjust) );

   if Assigned (IdSNTPSrv) then
      IdSNTPSrv.RefTimeStamp := self.prv_ntp_time;

   drift_ema := 0;
  end;


 ctc := pt.Elapsed (VTT_TIMER);
 // ctc := 0;

 if ( minutes mod v_rate = 0) and (ref_time <> 0) and ( ctc > 1000 ) then
     begin

      // получение оценки расхождения виртуального и системного времени

      if drift_ema <> 0 then
       begin
        ct := drift_ema;
        if (drift_l < drift_h) and (drift_l <> 0) then
          wprintf ('~C09[~d ~T]. #DBG:~C07 VTT drift stat, low = %s, high = %s',
                      [ FmtDelay (drift_l / DT_ONE_MSEC), FmtDelay(drift_h / DT_ONE_MSEC)] );

        drift_l := ct;
        drift_h := ct;
       end
      else
       begin
        // локальное усреднение
        ct := 0;
        for n := 1 to 5 do
            ct := ct + CompareVirtualTimer (0); // сравнивать с виртуальным
        ct := ct / 5;
       end;

      calct := ct / DT_ONE_MSEC;              // приведение к миллисекундам
      calct := MSEC_IN_HOUR * calct / ctc; // экстраполированное расхождение в час
      // если период замера более 30 секунд, надо добавить в статистику
      if ( ctc > 30000) then
          clk_pfc_dev.Add ( calct );

      if (rsync_cnt <= 2) then
          pwm_allow := TRUE;
      // ctc := CompareVirtualTimer (1);
     end;

 // основным расхождением является sys<->pfc
 if pfc_errors > 0 then exit;


 dta := IfV ( n_ticks <= 4, CompareVirtualTimer (0), ct ); // clk<->pfc diff

 if dta = 0 then exit; // половина микросекунды не стоит корректировки скорости?


 stab_cross := FALSE;
 dta_ms := dta / DT_ONE_MSEC;
 wprintf('[~d ~T]. #DBG: system clock <-> PF clock diff = %.1f ms', [dta_ms]);

 abs_ms := Abs (dta_ms);

 if (prv_dta_ms <> 0) then
     stab_cross := ( Sign (dta_ms) <> Sign (prv_dta_ms) );  // пересечение нуля - приближение к точке стабильности


 prv_dta_ms := dta_ms;

 last_sync_elps := pt.Elapsed (VTT_LAST_SYNC);
 last_chk_elps := pt.Elapsed (VTT_LAST_CHECK);

 sync_expected := (n_ticks <= 4) or (( Abs (dta) >= min_dvg * DT_ONE_MSEC) and ( Abs(dta) <= max_dvg * DT_ONE_MSEC));

 // ========================= МЯГКАЯ СИНХРОНИЗАЦИЯ: ПОДГОНКА СКОРОСТИ СИСТЕМНОГО ТАйМЕРА к ВИРТУАЛЬНОМУ ==============================
 // Этот подход используется при отсутствии необходимости синхронизировать большую разницу.

 if ( last_chk_elps > 10000 ) and ( hw_adjust ) and ( clk_pfc_dev.Count <> 0 ) and ( not sync_expected ) then
   begin
    pt.StartOne (VTT_LAST_CHECK);
    // рассчет дельта-значений в час
    calct := MSEC_IN_HOUR * dta_ms / last_chk_elps;

    if g_timer.OwnRights then
      begin
       slot := g_timer.ActiveSlot^;
       slot.clock_dvg := calct; // расхождение периодов
       g_timer.Update ( slot );
      end
    else
      begin
       ODS('[~T].~C0C #WARN:~C07 not have rights for g_timer');
      end;

    // calct := sys_pfc_dev.Last;
    // calct := dta_ms;

    if prv_dev = 0 then
       prv_dev := calct;


    accel := Abs (calct) - Abs (prv_dev);

    ref_dta := Abs (accel) * Sign (calct);
    // then zero-line cross
    if stab_cross then
      begin
       prv_dev := 0;
       drift_ema := 0;
       ref_dta := - ref_dta + calct * 0.9; // smart brake
       s := '0x';
      end
    else
    // then deviation growth
    if ( accel >= 0 ) then
      begin
       if ref_dta = 0 then ref_dta := calct;

       if not sync_expected then ref_dta := ref_dta * 2;
       s := '++';
      end
    else
    // then deviation down
      begin
       s := '--'; // braking
       if abs_ms > 100 then
          ref_dta := - ref_dta * 0.1 else
       if abs_ms > 050 then
          ref_dta := - ref_dta * 0.3 else
       if abs_ms > 030 then
          ref_dta := - ref_dta * 0.5 else
       if abs_ms > 010 then
          ref_dta := - ref_dta * 0.9 else
          ref_dta := - ref_dta * 0.99;
      end;


    if ( Abs(dta_ms) < 1 ) and ( Abs(ref_dta) < 100 )  then clk_pfc_dev.Clear;

    pwm_allow := Abs ( calct ) < 150;

    if ( Abs (calct) > 0.1  ) and  ( Abs (ref_dta) > 0.01 ) then
       begin
        drift_ema := 0; // reset allocation
        ODS('~C0E[~d ~T]. #DBG: Stat. timer drift = ' + FmtDelay (calct, 7, 'sc') + '~C0F / h' +
            '~C0E, previous = ' + FmtDelay (prv_dev, 7, 'sc') +
            '~C0F / h~C0E, used accel(' + s + ') = ' + FmtDelay (ref_dta, 7, 'sc') + '~C0F / h~C07' );

        pwm_allow := FALSE;
        if ( Abs (ref_dta) > 25 ) or ( Abs (st_adjust) > 5000 ) then // PWM
          begin
           if Abs (ref_dta) > 100 then
              st_adjust := st_adjust + Round ( ref_dta ) // смещение корректора
           else
              st_adjust := st_adjust + Round ( Sign(ref_dta) * 25 );
          end;

        if ( Abs(dta_ms) < 5 ) then
          begin
           pwm_allow := TRUE;
           pwm_step := pwm_range div 100;
           if pwm_split_ema = 0 then
              pwm_split_ema := pwm_split
           else
              pwm_split_ema := pwm_split_ema * 0.99 + pwm_split * 0.01;


           if ( Abs(dta_ms) < 30) then
            begin
             if ( Abs(ref_dta) < 500 ) then
               pwm_step := pwm_step div 10;
             if ( Abs(ref_dta) < 100 ) then
               pwm_step := IfV ( Abs(dta_ms) < 1, 5, 20 );
            end;


           if (ref_dta < 0) then pwm_split := pwm_split - pwm_step; // увеличение периода медленного хода часов, если наблюдается спешка системного таймера

           if (ref_dta > 0) then pwm_split := pwm_split + pwm_step; // увеличение периода быстрого хода часов


           if pwm_split <= 0 then
             begin
              pwm_split := pwm_range - pwm_step;
              Dec (st_adjust, 25);
             end;
           if pwm_split >= pwm_range then
             begin
              pwm_split := 0 + pwm_step;
              Inc (st_adjust, 25);
             end;

           // отработка смещения к средней
           {
           if stab_cross and ( Abs(ref_dta) > 100 ) then
            begin
             if ((dta_ms < 0) and (pwm_split_ema < pwm_split)) or
                ((dta_ms > 0) and (pwm_split_ema > pwm_split)) then pwm_split := Round (pwm_split_ema);
            end; // }


           ODS (#9#9#9'~C0A pwm_split changed to ~C0D' + IntToStr(pwm_split) + '~C07' );
          end; // PWM


        st_adjust := Min (st_adjust, max_st_adjust);
        st_adjust := Max (st_adjust, min_st_adjust);
        UpdateSTA ( log_verbose >= 5 );
       end;

    if sync_expected then
      begin
       prv_dev := 0;
       drift_ema := 0;
      end
    else
       prv_dev := calct;
   end;


 ////////////////////////////////////////////////////////////////////////////////////////////////////////
 /////                  Отработка синхронизации  системных часов WINDOWS                           //////
 ////////////////////////////////////////////////////////////////////////////////////////////////////////

 if sync_expected then
    begin
     Inc (sync_cnt);

     if Abs (dta_ms) > 80 then dta_ms := Sign (dta_ms) * 80; // strict

     if (ema_delta = 0) then
        ema_delta := dta_ms * 0.9
     else
       begin
        if ( Abs(dta_ms) < Abs (ema_delta) ) then
           ema_delta := (ema_delta * 0.3) + dta_ms * 0.7
        else
           ema_delta := (ema_delta * 0.9) + dta_ms * 0.1;
       end;




     // ' + IfV (ntp_sync, 'NTP servers pool', '
     s := '-------------------------------------------------------------------------------------------------------------------------'#13#10;
     s := s + '[~d ~T].~C0F #MSG(Sync): Synсhronizing clocks with ~C0E PFC timer' +
              '~C0F, correcting delta(sec) ' + IfV (dta > 0, '~C0A', '~C0C') +
               FormatFloat('0.###', dta / DT_ONE_SECOND) + '~C0F';


     if ( last_sync_elps >= 50000 ) and ( ema_delta <> 0 ) then
      begin

       cum_dvg := cum_dvg + dta;
       calct := cum_dvg / DT_ONE_SECOND;

       ct := (MSEC_IN_HOUR / last_sync_elps);
       add := ema_delta *  ct * 0.75;

       dta := dta * aprox_fact; // применить коэффициент приближения

       //
       s := s + ', with value ' + IfV (dta > 0, '~C0A', '~C0C') + FormatFloat('0.###', dta / DT_ONE_SECOND) + '~C0F';
       s := s + ', cumulative delta(sec) ' + IfV (calct > 0, '~C0A', '~C0C') + FormatFloat('0.###', calct) + ' ~C0F';

       s := s + #13#10#9#9'       ~C0E#DBG(Sync): ema_delta =~C0D ' + ftow(ema_delta, '%.5f') +
                  '~C0E msec,~C0F (' + FormatFloat('0.###', ema_delta * ct ) +  ' ms/h) ~C0E' +
                  ' ratio for dta = ~C0D' + ftow(ct, '%.5f') + '~C0E, add =~C0D ' + ftow(add, '%.5f');

      end;

     s := s + '~C0B'#13#10#9#9'       ';
     s := s + '#DBG(Sync): sync_cnt =~C0D ' + IntToStr (sync_cnt) + '~C0B';
     s := s + ', local timer ticks ~C0E' + IfV (dta > 0, 'slower', 'faster') + '~C0B';
     s := s + ', from last sync elapsed = ~C0D' + FmtDelay ( last_sync_elps, 7, 's') + '~C0B';


     ODS(s + '~C07');
     if Abs (dta) > 1000 then
       begin
        // большая дельта
        Windows.Beep (1000, 230);
        Windows.Beep (600, 230);
        Windows.Beep (1300, 230);
       end;

     TickAdjust (2);
     dt := CurrentDateTime + dta;
     pt.StartOne (VTT_LAST_SYNC);
     // DateTimeToSystemTime (dt, st);
     clk_pfc_dev.Clear;                 // <<<<<<<<<<<<<<< при синхронизации статистика портится
     IndySetLocalTime (dt);

     if g_timer.OwnRights then
       begin
        slot := g_timer.ActiveSlot^;
        slot.clock_syn := DateTimeToTimeStamp (dt).Time; // расхождение периодов
        g_timer.Update ( slot );
       end;

     last_time := dt;
     if ntp_sync then Inc (ntp_sync_cnt);
    end
  else
   // отклонение синхронизации
     begin
      last_sync_elps := pt.Elapsed (VTT_LAST_SYNC);
      ct := last_sync_elps / 1000;   // сколько прошло с последней синхронизации
      if ct <= 500 then exit;
      ctc := dta / DT_ONE_MSEC;         // расхождение в мсек
      calct := ( ctc /  ct * 3600.0 ); // дельта в час  { 200 / 60 * 3600  }

      ODS( CFormat ('[~d ~T]. #DBG: Sync delta %s, is outbound settings %.1f - %.1f, from last sync elapsed = %s, stable dev = %7.1f ms/h',
          '~C07', [FmtDelay (ctc), min_dvg, max_dvg, FmtDelay(last_sync_elps), calct]) );

      ct := ntp_diver / DT_ONE_MSEC;
      s := InfoFmt('~D ~T;', g_timer.GetTime) + Format('%.3f;%.3f;%d;%d;', [ctc, ct, st_adjust, pwm_split] );
      SaveToLog(nosync_log, s);
       // calct := dta_ms / last_sync_elps * 3600 * 1000; // расхождение за час оценочное
     end;

end;


function TsvcTime.UpdateSTA;
var
   ucnt: Int64;
   lcnt, tinc: DWORD;
   tick_size: Double;
   tick_corr: Double;
   ticks_hr: Double;
     st_dev: Double;
   tad, res: LongBool;
       slot: TVirtualTimerRecord;
      s, rv: String;
        act: DWORD;



begin
 lcnt := 0;
 result := FALSE;
 if ( not have_privileges ) then
      have_privileges := AdjustPrivileges (hTok);

 if ( not have_privileges ) then
      exit;
 SetTimerResolution ( 0, FALSE, act );

 if ( clock_res > 0 ) and ( act <> target_res ) then
   begin
    ODS( CFormat('[~T]. #DBG: updating timer resolution from %d to %d', '~C07', [act, target_res]) );
    SetTimerResolution ( target_res, TRUE, act );
   end;

 // res := FALSE;

 try
   GetSystemTimeAdjustment (lcnt, tinc, tad);
   tick_size := tinc / 10000.0;
   if tick_size < 1 then
      tick_size := 1000 / 64;

   {tick_size := 1000 / tick_size;
   tick_pwr := Log2 ( tick_size );
   tick_pwr := Round (tick_pwr);
   tick_size := Power (2, tick_pwr);
   if tick_size <= 0 then exit;
   tick_size := 1000 / tick_size;}
   st_dev := st_adjust + sta_cpu_ratio * avg_cpu_load;

   s := ftow (tick_size, '%.3f');
   ticks_hr := (3600 * 1000) / tick_size;  // сколько тиков в час
   tick_corr := st_dev / ticks_hr; // из часового разбегания, в тиковое
   // если программа добавляет дельту (системные часы тормозят), то нужно увеличить размер тика
   if Abs (tick_corr) < Abs(tick_size) then
      tick_size := tick_size + tick_corr;


   // получить, сколько 100-нс единиц добавляется каждый к системному времени тик(sic!);
   ucnt := Round (tick_size * 10000.0);
   if ucnt <= 0 then exit;
   if ucnt <> lcnt then
    begin
     TickAdjust(2);
     SetSystemTimeAdjustment ( DWORD(lcnt), TRUE ); // disable
     if st_dev = 0 then exit;

     Sleep(300);
     TickAdjust(2);
     result :=  SetSystemTimeAdjustment ( DWORD(ucnt), FALSE ); // 10 = 1 mcs, = 0.001
     rv := IfV (result, ' success', '~C0C failed ~C0F' + Err2Str (GetLastError) );
     if result then
       begin

        Inc (st_adjust_cnt);
        if g_timer.OwnRights then
          begin
           slot := g_timer.ActiveSlot^;
           slot.clock_adj := ucnt; // расхождение периодов
           g_timer.Update ( slot );
          end;
       end;

     if bMsg then
        ODS( CFormat('[~d ~T].~C0B #DBG: tick set to %d nsu(%.3f ms), ' +
                  'base = %s ms, last = %d nsu (%s), TI = %d, sta/h = %.0f, cpu = %.4f, side = %d, swcnt = %d, result =%s', '~C07',
                   [ucnt, ucnt / 10000.0,
                    s,    lcnt, IfV (tad, 'disabled', 'enabled'),
                    tinc, st_dev, avg_cpu_load, pwm_side, st_adjust_cnt, rv]));
    end
   else
    begin
      if bMsg then
       ODS( CFormat('[~d ~T]. #DBG: Clock adjustment value is equal previous (%d), sta/h = %d', '~C07', [lcnt, st_adjust]) );
     result := TRUE;
    end;
 except
  on E: Exception do
     PrintError ('Exception catched in UpdateSTA: ' + E.Message);
 end;

 //if hTok <> 0 then CloseHandle (hTok);

end;

{ TRQThread }

procedure TRQThread.Execute;
begin
 try
  madExcept.NameThread(GetCurrentThreadId, AnsiString ('SyncThread') );
  svcTime.CheckTime;
 except
  on E: Exception do
    OnExceptLog (ClassName + '.Execute', E);
 end;
 svcTime.rqThread := nil;
 svcTime.sync_flag := TRUE;
 svcTime.sync_now := FALSE;
end;

{ TTextFileObj }

procedure TTextFileObj.Close;
begin
 if Opened then
   CloseFile (fRec);
 FOpened := FALSE;
end;

constructor TTextFileObj.Create(AFileName: String);
begin
 FFileName := AFileName;
 try
  AssignFile (fRec, filename);
  if FileExists (filename) then
    Append (fRec)
  else
     ReWrite (fRec);
  FError := IOResult;
  FOpened := (0 = Error);
 except
  on E: Exception do
    PrintError ('Exception catched in ' + ClassName + '.Create: ' + E.Message);
 end;
end;

destructor TTextFileObj.Destroy;
begin
 if Opened then Close;
 inherited;
end;

procedure TTextFileObj.PutStr(const s: String);
var
   st: TSystemTime;
   mc: WORD;
begin
 if Opened then
  try
   WriteLn (fRec, s);
   GetLocalTime (st);
   mc := ( st.wMinute div 30 ) * 30;
   if mc <> last_flush then
    begin
     last_flush := mc;
     Sleep(1);
     Flush (fRec);
     ODS('[~d ~T]. #DBG: File ~C0A' + FileName + '~C07 flushed to disk');
    end;
  except
   on E: Exception do
      PrintError ('Exception catched in ' + ClassName + '.PutStr: ' + E.Message);
  end;
end;

{ TDataStatVector }

procedure TDataStatVector.Add(v: Double);
var
   n: Integer;
begin
 // добавление в конец массива
 if Count < Size then
    Inc (FCount)
 else
 // со смещением массива влево
   for n := 0 to Count - 2 do
       FData [n] := FData [n + 1];
 FData [Count - 1] := v;
 FLast := v;
end;

procedure TDataStatVector.Clear;
begin
 FCount := 0;
end;

constructor TDataStatVector.Create(ASize: Integer);
begin
 FSize := ASize;
 SetLength ( FData, Size );
end;

destructor TDataStatVector.Destroy;
begin
 SetLength ( FData, 0 );
  inherited;
end;

function TDataStatVector.Median: Double;
var
   n: Integer;
begin
 result := 0;
 for n := 0 to Count - 1 do
   result := result + FData [n];
 if Count > 0 then
    result := result / Count;
end;


function cmpDevSum (a, b: Pointer): Integer;
var
   dca, dcb: TDiffCell;
begin
 dca := a;
 dcb := b;

 result := 0;

 if dca.dev_sum > dcb.dev_sum then result := +1;
 if dca.dev_sum < dcb.dev_sum then result := -1;
end;


function TDataStatVector.StatMedian: Double;

var
   dvgl: TObjectList;
   dca, dcb: TDiffCell;
   n, i, cc: Integer;
   deviation: Double;

begin
 result := 0;

 if Count <= 2 then
  begin
   result := Median;
   exit;
  end;

 dvgl := TObjectList.Create (TRUE);
 try
  for n := 0 to Count - 1 do
   begin
    dca := TDiffCell.Create;
    dvgl.Add (dca);
    dca.value := FData [n];
    dca.dev_sum := 0;
   end;

  for n := 0 to Count - 1 do
   for i := 0 to Count - 1 do
   if n <> i then
    begin
     dca := TDiffCell ( dvgl [n] );
     dcb := TDiffCell ( dvgl [i] );
     deviation := Sqr ( dca.value - dcb.value );
     dca.dev_sum := dca.dev_sum + deviation;
    end;


  dvgl.Sort ( cmpDevSum );

  cc := dvgl.Count div 2;

  for n := 0 to cc - 1 do
   begin
    dca := TDiffCell ( dvgl [n] );
    result := result + dca.value;
   end;

  if cc > 0 then
     result := result / cc;

 finally
  dvgl.Free;
 end;
end;

end.
