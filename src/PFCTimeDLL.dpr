library PFCTimeDLL;

{
  PFCTimeDLL.dpr -- High-precision time DLL backed by TMService PFC virtual timer.

  The DLL opens a read-only view of the named shared memory block that TMService
  (TMSvc.pas) maintains, and exposes:

    PFC_IsConnected  -- check whether TMService is running and block is valid
    PFC_GetDateTime  -- Delphi/COM TDateTime (Double, days since 30-Dec-1899)
    PFC_GetSystemTime(out TSystemTime) -- drop-in for WinAPI GetSystemTime
    PFC_GetTimeOfDay(out TTimeVal): Integer -- POSIX gettimeofday equivalent

  When the service is not running the functions fall back to the system clock,
  so callers do not need to handle the disconnected case specially.

  Target: Delphi 12 / Studio 23.0, Win32 (x86).
  Requires: TMService to be installed and running (for shared memory provider).
}

uses
  SysUtils,
  Windows,
  DateTimeTools in '..\lib\DateTimeTools.pas',
  PFCTime in 'PFCTime.pas';

exports
  PFC_IsConnected,
  PFC_GetDateTime,
  PFC_GetSystemTime,
  PFC_GetTimeOfDay;

{$R *.res}

begin
end.
