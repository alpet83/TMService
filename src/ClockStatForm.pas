unit ClockStatForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics, StrUtils, TMSGlobals,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Misc, DateTimeTools, VCLTee.TeEngine, Vcl.ExtCtrls, VCLTee.TeeProcs, VCLTee.Chart, VCLTee.Series, Vcl.StdCtrls, StrClasses, VCLTee.TeeFunci;

type
  TMainForm = class(TForm)
    Chart: TChart;
    updTimer: TTimer;
    Series1: TFastLineSeries;
    edtAproxPFC: TEdit;
    btnUpdAproxPFC: TButton;
    edtVisibleSet: TEdit;
    btnExit: TButton;
    edtHWCAdjust: TEdit;
    btnUpdHWCadjust: TButton;
    lbInfo: TLabel;
    procedure updTimerTimer(Sender: TObject);
    procedure btnUpdAproxPFCClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure edtVisibleSetChange(Sender: TObject);
    procedure btnExitClick(Sender: TObject);
    procedure btnUpdHWCadjustClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
              hTok: NativeUInt;
   have_privileges: Boolean;
           n_ticks: Integer;
    { Private declarations }
  public
    { Public declarations }
    vtdRef: TVirtualTimerRecord;
  end;


var
  MainForm: TMainForm;

implementation

{$R *.dfm}

procedure TMainForm.btnExitClick(Sender: TObject);
begin
 Close;
end;

procedure TMainForm.btnUpdAproxPFCClick(Sender: TObject);
var
   v: Single;
begin
 v := atof ( edtAproxPFC.Text );
 if v <= 0.01 then exit;
 g_timer.ActiveSlot.aprox_pfc := v;
end;

procedure TMainForm.btnUpdHWCadjustClick(Sender: TObject);
var
   t_adj: Cardinal;
   t_inc: Cardinal;
  ta_dis: LongBool;
    slot: TVirtualTimerRecord;
       v: Integer;


begin
 v := atoi ( edtAproxPFC.Text );
 if not have_privileges then exit;
 slot := g_timer.ActiveSlot^;
 slot.clock_adj := v;
 g_timer.Update (slot);
 GetSystemTimeAdjustment ( t_adj, t_inc, ta_dis );
 SetSystemTimeAdjustment ( t_adj, TRUE );
 SetSystemTimeAdjustment ( DWORD(v), FALSE );
end;

procedure TMainForm.edtVisibleSetChange(Sender: TObject);
var
   sl: TStrMap;
   sr: TChartSeries;
    s: String;
    n: Integer;
begin
 s := AnsiReplaceStr ( edtVisibleSet.Text, ' ', '' );


 sl := TStrMap.Create;
 sl.Split (',', s);
 for n := 0 to Chart.SeriesCount - 1 do
  begin
   sr := Chart.SeriesList [n];
   sr.Visible := ( sl.IndexOf (sr.Name) >= 0 );
  end;

 sl.Free;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
 edtAproxPFC.Text := ftow ( g_timer.ActiveSlot.aprox_pfc, '%.3f' );

 if ( not have_privileges ) then
      have_privileges := AdjustPrivileges (hTok);

end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
 CloseHandle (hTok);
end;

procedure TMainForm.updTimerTimer(Sender: TObject);

var
   sr: TChartSeries;
   dt: TDateTime;
   dv: Double;
  vtd: TVirtualTimerRecord;
    n: Integer;
    t: String;
    s: String;

begin

 while Chart.SeriesCount < 5 do
       Chart.AddSeries ( TFastLineSeries.Create (Chart) );


 n := n_ticks and $3F;

 lbInfo.Caption := 'tick $' + IntToHex(n, 2);

 if n = 0 then
    edtHWCadjust.Text := IntToStr ( g_timer.ActiveSlot.clock_adj );
 Inc (n_ticks);


 sr := Chart.SeriesList [0];

 dt := Now;



 vtd := g_timer.ActiveSlot^;

 dv := vtd.pfc_dvg;

 sr.Title := ftow ( dv, 'pfc_dvg ms/h = %.1f ' );
 sr.Name := 'pfc_dvg';
 sr.AddXY ( dt, dv );


 sr := Chart.SeriesList [1];
 sr.Name := 'clk_dvg';

 dv := vtd.clock_dvg;
 if Abs (vtd.clock_dvg) > 200 then
   begin
    dv := dv * 0.001;
    sr.Title := ftow ( dv, 'clk_dvg s/h = %.3f ' );
    sr.AddXY ( dt, dv );
   end
 else
   begin
    sr.Title := ftow ( dv, 'clk_dvg ms/h = %.1f ' );
    sr.AddXY ( dt, vtd.clock_dvg );
   end;

 sr := Chart.SeriesList [2];
 sr.Title := 'pfc_adj ms/h';
 sr.Name := 'pfc_adj';

 dv := 3600000 * ( vtd.pfc_corr - 1 );

 sr.AddXY ( dt, dv );

 vtdRef := vtd;

 s := '';
 for n := 0 to Chart.SeriesCount - 1 do
  begin
   sr := Chart.SeriesList [n];
   if not sr.Visible then continue;
   t := sr.Name;
   if Pos ('_', t) <= 0 then continue;
   if s = '' then
      s := t else s := s + ', ' + t;
  end;

 if not edtVisibleSet.Focused then
    edtVisibleSet.Text := s;
end;

initialization
 if g_timer = nil then
    g_timer := TVirtualTimer.Create;
end.
