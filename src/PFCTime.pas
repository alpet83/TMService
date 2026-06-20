unit PFCTime;

{
  PFCTime.pas -- DLL unit providing high-precision time from the TMService
  PFC virtual timer.

  Uses TVirtualTimer from DateTimeTools.pas (the same class the service uses
  internally) to connect to the shared memory region 'Global\VIRTUALTIMER'.
  When the service is running it is the owner (OwnRights=TRUE); this DLL
  opens the same mapping in read-only mode (OwnRights=FALSE) and calls
  GetTime to obtain the calibrated virtual time.

  No formulas are duplicated here: all tick-to-time conversion is handled
  inside TVirtualTimer.GetTime, which uses the same logic the service uses.

  Exports:
    PFC_IsConnected  -- TRUE when connected to the service's virtual timer
    PFC_GetDateTime  -- current PFC time as TDateTime (Delphi/COM epoch)
    PFC_GetSystemTime(out st: TSystemTime) -- WinAPI SYSTEMTIME clone
    PFC_GetTimeOfDay(out tv: TTimeVal): Integer -- POSIX gettimeofday (0 = ok)

  Falls back to Now / system GetSystemTime when the service is not running,
  so callers do not need to handle the disconnected case specially.

  Build: Delphi 12, Win32, library PFCTimeDLL.dpr
}

interface

uses Windows, SysUtils, DateTimeTools;

const
  MS_PER_DAY       = 86400000.0;
  UNIX_EPOCH_DELTA = 25569.0;      // days: 30-Dec-1899 -> 01-Jan-1970

type
  // POSIX timeval (64-bit fields for compatibility)
  TTimeVal = record
    tv_sec  : Int64;   // seconds since Unix epoch
    tv_usec : Int64;   // microseconds remainder
  end;
  PTimeVal = ^TTimeVal;

function  PFC_IsConnected: BOOL; stdcall;
function  PFC_GetDateTime: TDateTime; stdcall;
procedure PFC_GetSystemTime(out st: TSystemTime); stdcall;
function  PFC_GetTimeOfDay(out tv: TTimeVal): Integer; stdcall;

implementation

var
  g_vtimer : TVirtualTimer = nil;
  g_failed : Boolean       = FALSE;   // TRUE = init failed, stop retrying

// ---------------------------------------------------------------------------
// Lazy connect: create TVirtualTimer on first call.
// TVirtualTimer.Create opens 'Global\VIRTUALTIMER'; if the service owns it
// already, OwnRights will be FALSE here (reader mode).
procedure EnsureConnected;
begin
  if g_failed or (g_vtimer <> nil) then Exit;
  try
    g_vtimer := TVirtualTimer.Create;
  except
    g_failed := TRUE;  // mapping unavailable; stop retrying
    g_vtimer := nil;
  end;
end;

// ---------------------------------------------------------------------------
function PFC_IsConnected: BOOL; stdcall;
begin
  EnsureConnected;
  Result := (g_vtimer <> nil) and g_vtimer.Ready and (not g_vtimer.OwnRights);
end;

// ---------------------------------------------------------------------------
// GetTime uses the VirtualTimer's calibrated PFC anchor (pt.AdjustedCoef,
// RefTime, RefTick) stored in the shared TVirtualTimerData block.
// Falls back to Now when not connected.
function PFC_GetDateTime: TDateTime; stdcall;
begin
  EnsureConnected;
  if PFC_IsConnected then
    Result := g_vtimer.GetTime
  else
    Result := Now;
end;

// ---------------------------------------------------------------------------
// WinAPI-compatible GetSystemTime clone.
// DateTimeToSystemTime fills wMilliseconds correctly.
procedure PFC_GetSystemTime(out st: TSystemTime); stdcall;
begin
  DateTimeToSystemTime(PFC_GetDateTime, st);
end;

// ---------------------------------------------------------------------------
// POSIX gettimeofday clone. Returns 0 (always succeeds).
function PFC_GetTimeOfDay(out tv: TTimeVal): Integer; stdcall;
var
  dt       : TDateTime;
  ms_total : Int64;
begin
  dt         := PFC_GetDateTime;
  ms_total   := Round((dt - UNIX_EPOCH_DELTA) * MS_PER_DAY);
  tv.tv_sec  := ms_total div 1000;
  tv.tv_usec := (ms_total mod 1000) * 1000;
  Result := 0;
end;

// ---------------------------------------------------------------------------
procedure DllMain(Reason: DWORD);
begin
  if Reason = DLL_PROCESS_DETACH then
    FreeAndNil(g_vtimer);
end;

initialization
  DllProc := @DllMain;

end.
