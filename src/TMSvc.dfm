object svcTime: TsvcTime
  OldCreateOrder = False
  OnCreate = ServiceCreate
  DisplayName = 'LocalTimeSync service'
  Interactive = True
  OnContinue = ServiceContinue
  OnPause = ServicePause
  OnShutdown = ServiceShutdown
  OnStart = ServiceStart
  OnStop = ServiceStop
  Height = 411
  Width = 371
  object tmrCheck: TTimer
    OnTimer = tmrCheckTimer
    Left = 16
    Top = 16
  end
  object tmrFast: TTimer
    Interval = 500
    OnTimer = tmrFastTimer
    Left = 112
    Top = 104
  end
end
