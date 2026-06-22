object svcTime: TsvcTime
  OnCreate = ServiceCreate
  DisplayName = 'LocalTimeSync service'
  Interactive = True
  OnContinue = ServiceContinue
  OnPause = ServicePause
  OnShutdown = ServiceShutdown
  OnStart = ServiceStart
  OnStop = ServiceStop
  Height = 617
  Width = 557
  PixelsPerInch = 144
  object tmrCheck: TTimer
    OnTimer = tmrCheckTimer
    Left = 24
    Top = 24
  end
  object tmrFast: TTimer
    Interval = 500
    OnTimer = tmrFastTimer
    Left = 168
    Top = 156
  end
end
