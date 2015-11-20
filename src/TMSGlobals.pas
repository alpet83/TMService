unit TMSGlobals;

interface
uses Windows, SysUtils, Classes, DateTimeTools, Misc;

function AdjustPrivileges ( var hTok: NativeUInt ): Boolean;


implementation

function AdjustPrivileges;
const
  SE_SYSTEMTIME_NAME = 'SeSystemtimePrivilege';

var
   priv, last_priv: _TOKEN_PRIVILEGES;
   rlen: DWORD;
begin
 result := FALSE;

 if not OpenProcessToken (GetCurrentProcess, TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY, hTok) then
   begin
    PrintError('OpenProcessToken returned ~C0F' + Err2Str (GetLastError));
    exit;
   end;



 if LookupPrivilegeValue (nil, SE_SYSTEMTIME_NAME, priv.Privileges[0].Luid) then
  begin
   ODS('[~d ~T].~C0F #DBG: AdjustTokenPrivileges for ~C0A' + SE_SYSTEMTIME_NAME + '~C07...');
   priv.PrivilegeCount := 1;
   priv.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED;
   result := AdjustTokenPrivileges (hTok, False, priv, sizeof (priv), last_priv, rlen);
   if not result then
      PrintError('AdjustTokenPrivileges returned ~C0F' + Err2Str (GetLastError));
  end
 else
  PrintError('LookupPrivilegeValue returned ~C0F' + Err2Str (GetLastError));
end;


end.
