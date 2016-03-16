object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'MainForm'
  ClientHeight = 546
  ClientWidth = 860
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  DesignSize = (
    860
    546)
  PixelsPerInch = 96
  TextHeight = 13
  object lbInfo: TLabel
    Left = 248
    Top = 496
    Width = 6
    Height = 13
    Anchors = [akLeft, akBottom]
    Caption = '0'
  end
  object Chart: TChart
    Left = 8
    Top = 8
    Width = 844
    Height = 474
    Title.Text.Strings = (
      'TChart')
    LeftAxis.StartPosition = 3.000000000000000000
    LeftAxis.EndPosition = 97.000000000000000000
    View3D = False
    TabOrder = 0
    Anchors = [akLeft, akTop, akRight, akBottom]
    DefaultCanvas = 'TGDIPlusCanvas'
    ColorPaletteIndex = 13
    object Series1: TFastLineSeries
      LinePen.Color = 10708548
      XValues.DateTime = True
      XValues.Name = 'X'
      XValues.Order = loAscending
      YValues.Name = 'Y'
      YValues.Order = loNone
    end
  end
  object edtAproxPFC: TEdit
    Left = 8
    Top = 515
    Width = 97
    Height = 21
    Anchors = [akLeft, akBottom]
    TabOrder = 1
    Text = '0.9'
  end
  object btnUpdAproxPFC: TButton
    Left = 111
    Top = 512
    Width = 114
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'Update aprox. fact.'
    TabOrder = 2
    OnClick = btnUpdAproxPFCClick
  end
  object edtVisibleSet: TEdit
    Left = 240
    Top = 517
    Width = 337
    Height = 21
    Anchors = [akLeft, akBottom]
    TabOrder = 3
    OnChange = edtVisibleSetChange
  end
  object btnExit: TButton
    Left = 777
    Top = 512
    Width = 75
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'Exit'
    TabOrder = 4
    OnClick = btnExitClick
    ExplicitTop = 439
  end
  object edtHWCAdjust: TEdit
    Left = 8
    Top = 488
    Width = 97
    Height = 21
    Anchors = [akLeft, akBottom]
    TabOrder = 5
    Text = '50'
  end
  object btnUpdHWCadjust: TButton
    Left = 111
    Top = 484
    Width = 114
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'Update HWC adjust'
    TabOrder = 6
    OnClick = btnUpdHWCadjustClick
  end
  object updTimer: TTimer
    Interval = 937
    OnTimer = updTimerTimer
    Left = 8
    Top = 440
  end
end
