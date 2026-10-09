{ 25.12 lck 控件属性动画
  修复vcl的onProcess事件中执行stop会导致DoFinish来两次bug，直接导致free两次异常
  增加RemainingValue、RemainingTime用于OnProcessProc事件

  @TAnimateType待定使用rdBezier,
  @TAnimator匿名动画
}
unit RdAni;

interface

uses Windows, MMSystem, Types, SysUtils, TypInfo, Classes, Math, Controls, Forms,
     {$if CompilerVersion >= 23.0}Generics.Collections,{$ifend}
     SyncObjs, RdBezierCurves, RdTimer;

type
  TTrigger = type string;

  TAnimateType = (Linear, customCubicBezier,
    easeQuadIn, easeQuadOut, easeQuadInOut,
    easeCubicIn, easeCubicOut, easeCubicInOut,
    easeQuartIn, easeQuartOut, easeQuartInOut,
    easeQuintIn, easeQuintOut, easeQuintInOut,
    easeSineIn, easeSineOut, easeSineInOut,
    easeExpoIn, easeExpoOut, easeExpoInOut,
    easeCircIn, easeCircOut, easeCircInOut,
    easeBackIn, easeBackOut, easeBackInOut
//    ElasticIn, ElasticOut, ElasticInOut,
    );

  TRdAnimationFloat = class;

  TAnimator = class
  private type
    TAnimationDestroyer = class
    private
      procedure DoAniFinished(Sender: TObject);
    end;
  private class var
    FDestroyer: TAnimationDestroyer;
  private
    class procedure CreateDestroyer;
    class procedure Uninitialize;
  public
 (*   { animations }
    class procedure StartAnimation(const Target: TComponent; const AName: string);
    class procedure StopAnimation(const Target: TComponent; const AName: string);
    class procedure StartTriggerAnimation(const Target: TComponent; const AInstance: TComponent; const ATrigger: string);
    class procedure StartTriggerAnimationWait(const Target: TComponent; const AInstance: TComponent; const ATrigger: string);
    class procedure StopTriggerAnimation(const Target: TComponent; const AInstance: TComponent; const ATrigger: string);
    { default }
    class procedure DefaultStartTriggerAnimation(const Target, AInstance: TComponent; const ATrigger: string); static;
    class procedure DefaultStartTriggerAnimationWait(const Target: TComponent; const AInstance: TComponent; const ATrigger: string);
    { animation property }
*)
    class procedure AnimateFloat(const Target: TComponent; const APropertyName: string;
      const NewValue: Single; Duration: Single; OnProcessProc: TProc<TRdAnimationFloat>; OnFinishProc: TProc = nil;
      //自动反转(反转一次, 反转结束执行FinishProc)
      AutoReverse: Boolean = False;
      //延迟秒 (Duration不包含Delay)
      Delay: Single = 0.0;
      AnimateType: TAnimateType = TAnimateType.Linear); overload;
(*    class procedure AnimateFloat(const Target: TComponent; const APropertyName: string;
      const NewValue: Single; Duration: Single; OnFinishProc: TProc = nil;
      //自动反转(反转一次, 反转结束执行FinishProc)
      AutoReverse: Boolean = False;
      //延迟秒 (Duration不包含Delay)
      Delay: Single = 0.0;
      AnimateType: TAnimateType = TAnimateType.Linear); overload;

    class procedure AnimateFloatWait(const Target: TComponent; const APropertyName: string; const NewValue: Single; Duration: Single = 0.2;
      AType: TAnimationType = TAnimationType.In; AInterpolation: TInterpolationType = TInterpolationType.Linear);
    class procedure AnimateColor(const Target: TComponent; const APropertyName: string; NewValue: TAlphaColor; Duration: Single = 0.2;
      AType: TAnimationType = TAnimationType.In; AInterpolation: TInterpolationType = TInterpolationType.Linear);
*)
    //打断当前动画(停止在当前位置)
    class procedure AbortAnimate(const Target: TComponent; const APropertyName: string);
//    class procedure StopAnimate(const Target: TComponent; const APropertyName: string);
  end;

  TAnimation = class(TComponent)
  public class var
    AniFrameRate: Integer;
  private type
    TTriggerRec = record
      Name: string;
      Prop: PPropInfo;
      Value: Boolean;
    end;
  private class var
    FAniThread: TObject;
  private
    FTickCount : Integer;
    FDuration: Single;
    FDelay, FDelayTime: Single;
    FCurrentTime: Single;
    FInverse: Boolean;
    FSavedInverse: Boolean;
    FTrigger, FTriggerInverse: TTrigger;
    FLoop: Boolean;
    FPause: Boolean;
    FRunning: Boolean;
    FOnFinish: TNotifyEvent;
    FOnProcess: TNotifyEvent;
    FAnimateType: TAnimateType;
//    FAnimationType: TAnimationType;
    FEnabled: Boolean;
    FAutoReverse: Boolean;
    FFinishCounter: Integer;
    procedure SetEnabled(const Value: Boolean);
    procedure SetTrigger(const Value: TTrigger);
    procedure SetTriggerInverse(const Value: TTrigger);
    class procedure Uninitialize;
    class procedure Initialize;
    procedure SetTarget(const Value: TComponent);
    function GetRemainingTime: Single;
//    procedure SetTargetObj(const Value: TObject);
  protected
//    FTargetObj: TObject;
    FTarget: TComponent;
    ///<summary>Return normalized CurrentTime value between 0..1 </summary>
    function GetNormalizedTime: Single;
    procedure FirstFrame; virtual;
    procedure ProcessAnimation; virtual; abstract;
    procedure DoProcess; virtual;
    procedure DoFinish; virtual;
    procedure Loaded; override;
    procedure ParentChanged; virtual;
    procedure AssignTo(Dest: TPersistent); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    OnFinishProc: TProc;
    OnProcessProc: TProc;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Start; virtual;
    procedure Stop; virtual;
    procedure StopAtCurrent; virtual;
//    procedure StartTrigger(const AInstance: TFmxObject; const ATrigger: string);
//    procedure StopTrigger(const AInstance: TFmxObject; const ATrigger: string);
    procedure ProcessTick(time, deltaTime: Single);
    property Running: Boolean read FRunning;
    property Pause: Boolean read FPause write FPause;
    property AutoReverse: Boolean read FAutoReverse write FAutoReverse default False;
    property Enabled: Boolean read FEnabled write SetEnabled default False;
    property Delay: Single read FDelay write FDelay;
    property Duration: Single read FDuration write FDuration nodefault;
    property AnimateType: TAnimateType read FAnimateType write FAnimateType default TAnimateType.Linear;
    property Inverse: Boolean read FInverse write FInverse default False;
    ///<summary>Normalized CurrentTime value between 0..1 </summary>
    property NormalizedTime: Single read GetNormalizedTime;
    property Loop: Boolean read FLoop write FLoop default False;
    property Trigger: TTrigger read FTrigger write SetTrigger;
    property TriggerInverse: TTrigger read FTriggerInverse write SetTriggerInverse;
    property CurrentTime: Single read FCurrentTime;
    property OnProcess: TNotifyEvent read FOnProcess write FOnProcess;
    property OnFinish: TNotifyEvent read FOnFinish write FOnFinish;

    property Target: TComponent read FTarget write SetTarget;
//    property TargetObj: TObject read FTargetObj write SetTargetObj;

    //剩余时间(无论是否反转，都是正数, 不同于CurrentTime反转过程为递减至0)
    property RemainingTime: Single read GetRemainingTime;

    class property AniThread: TObject read FAniThread;
  end;


{ TCustomPropertyAnimation }

  TCustomPropertyAnimation = class(TAnimation)
  private
  protected
    //判断过滤
    FPropKinds: TTypeKinds;

    //prop缓存, FInstance注意释放同步
    FInstance: TObject;
    FPropInfo: PPropInfo;
    //相对路径
    FPropPath: string;
    //全路径
    FPropertyName: string;
    procedure SetPropertyName(const AValue: string);
    function FindProperty: Boolean;
    procedure ParentChanged; override;
    procedure AssignTo(Dest: TPersistent); override;
  public
    constructor Create(AOwner: TComponent); override;
    property PropertyName: string read FPropertyName write SetPropertyName;
    procedure Start; override;
    procedure Stop; override;
//    property Parent: TComponent read FTarget;
  end;

  TCustomPropertyAnimationClass = class of TCustomPropertyAnimation;

{ TRdAnimationFloat }

  {$INCLUDE RdXE3Control64.inc}
  TRdAnimationFloat = class(TCustomPropertyAnimation)
  private
    FStartValue: Single;
    FStopValue: Single;
    FCurrentValue: Single;
    FStartFromCurrent: Boolean;
    function GetRemainingValue: Single;
  protected
    procedure ProcessAnimation; override;
    procedure FirstFrame; override;
    procedure AssignTo(Dest: TPersistent); override;
  public
    constructor Create(AOwner: TComponent); override;
    property PropInstance: TObject read FInstance;
    //当前值(只能在onProcess事件中读取，由当前时间(t/D)计算出
    property CurrentValue: Single read FCurrentValue;
    //相对stop的剩余值(始终为正数, 只能在onProcess事件中读取)
    property RemainingValue: Single read GetRemainingValue;
  published
//    property AnimationType default TAnimationType.In;
    property AutoReverse default False;
    property Enabled default False;
    property Delay;
    property Duration nodefault;
    property AnimateType default TAnimateType.Linear;
    property Inverse default False;
    property Loop default False;
    property OnProcess;
    property OnFinish;
    property PropertyName;
    property StartValue: Single read FStartValue write FStartValue stored True nodefault;
    property StartFromCurrent: Boolean read FStartFromCurrent write FStartFromCurrent default False;
    property StopValue: Single read FStopValue write FStopValue stored True nodefault;
    property Target;
//    property Trigger;
//    property TriggerInverse;
  end;

procedure Register;

implementation

uses RdSkinStyle;

procedure Register;
begin
  RegisterComponents('RdControl', [TRdAnimationFloat]);
end;

type
  TAnimationType = (&In, Out, InOut);

function InterpolateSingle(const Start, Stop, T: Single): Single;
begin
  Result := Start + (Stop - Start) * T;
end;

{function InterpolateColor(const Start, Stop: TColor; T: Single): TColor;
begin
  TAlphaColorRec(Result).A := TAlphaColorRec(Start).A + Trunc((TAlphaColorRec(Stop).A - TAlphaColorRec(Start).A) * T);
  TAlphaColorRec(Result).R := TAlphaColorRec(Start).R + Trunc((TAlphaColorRec(Stop).R - TAlphaColorRec(Start).R) * T);
  TAlphaColorRec(Result).G := TAlphaColorRec(Start).G + Trunc((TAlphaColorRec(Stop).G - TAlphaColorRec(Start).G) * T);
  TAlphaColorRec(Result).B := TAlphaColorRec(Start).B + Trunc((TAlphaColorRec(Stop).B - TAlphaColorRec(Start).B) * T);
end;   }

type
  TVclComponentList = TList{$if CompilerVersion >= 24.0}<TComponent>{$ifend};

function InterpolateBack(t, B, C, D, S: Single; AType: TAnimationType): Single;
begin
  case AType of
    TAnimationType.In:
      begin
        if S = 0 then
          S := 1.70158;
        t := t / D;
        Result := C * t * t * ((S + 1) * t - S) + B;
      end;
    TAnimationType.Out:
      begin
        if S = 0 then
          S := 1.70158;
        t := t / D - 1;
        Result := C * (t * t * ((S + 1) * t + S) + 1) + B;
      end;
    TAnimationType.InOut:
      begin
        if S = 0 then
          S := 1.70158;
        t := t / (D / 2);
        if t < 1 then
        begin
          S := S * 1.525;
          Result := C / 2 * (t * t * ((S + 1) * t - S)) + B;
        end
        else
        begin
          t := t - 2;
          S := S * 1.525;
          Result := C / 2 * (t * t * ((S + 1) * t + S) + 2) + B;
        end;
      end;
  else
    Result := 0;
  end;
end;

function InterpolateBounce(t, B, C, D: Single; AType: TAnimationType): Single;
  function _EaseOut(t, B, C, D: Single): Single;
  begin
    t := t / D;
    if t < 1 / 2.75 then
    begin
      Result := C * (7.5625 * t * t) + B;
    end
    else if t < 2 / 2.72 then
    begin
      t := t - (1.5 / 2.75);
      Result := C * (7.5625 * t * t + 0.75) + B;
    end
    else if t < 2.5 / 2.75 then
    begin
      t := t - (2.25 / 2.75);
      Result := C * (7.5625 * t * t + 0.9375) + B;
    end
    else
    begin
      t := t - (2.625 / 2.75);
      Result := C * (7.5625 * t * t + 0.984375) + B;
    end;
  end;
  function _EaseIn(t, B, C, D: Single): Single;
  begin
    Result := C - _EaseOut(D - t, 0, C, D) + B;
  end;

begin
  case AType of
    TAnimationType.In:
      begin
        Result := _EaseIn(t, B, C, D);
      end;
    TAnimationType.Out:
      begin
        Result := _EaseOut(t, B, C, D);
      end;
    TAnimationType.InOut:
      begin
        if t < D / 2 then
          Result := _EaseIn(t * 2, 0, C, D) * 0.5 + B
        else
          Result := _EaseOut(t * 2 - D, 0, C, D) * 0.5 + C * 0.5 + B;
      end;
  else
    Result := 0;
  end;
end;

function InterpolateCirc(t, B, C, D: Single; AType: TAnimationType): Single;
begin
  case AType of
    TAnimationType.In:
      begin
        t := t / D;
        Result := -C * (Sqrt(1 - t * t) - 1) + B;
      end;
    TAnimationType.Out:
      begin
        t := t / D - 1;
        Result := C * Sqrt(1 - t * t) + B;
      end;
    TAnimationType.InOut:
      begin
        t := t / (D / 2);
        if t < 1 then
          Result := -C / 2 * (Sqrt(1 - t * t) - 1) + B
        else
        begin
          t := t - 2;
          Result := C / 2 * (Sqrt(1 - t * t) + 1) + B;
        end;
      end;
  else
    Result := 0;
  end;
end;

function InterpolateCubic(t, B, C, D: Single; AType: TAnimationType): Single;
begin
  case AType of
    TAnimationType.In:
      begin
        t := t / D;
        Result := C * t * t * t + B;
      end;
    TAnimationType.Out:
      begin
        t := t / D - 1;
        Result := C * (t * t * t + 1) + B;
      end;
    TAnimationType.InOut:
      begin
        t := t / (D / 2);
        if t < 1 then
          Result := C / 2 * t * t * t + B
        else
        begin
          t := t - 2;
          Result := C / 2 * (t * t * t + 2) + B;
        end;
      end;
  else
    Result := 0;
  end;
end;

function InterpolateElastic(t, B, C, D, A, P: Single; AType: TAnimationType): Single;
var
  S: Single;
begin
  case AType of
    TAnimationType.In:
      begin
        if t = 0 then
        begin
          Result := B;
          Exit;
        end;
        t := t / D;
        if t = 1 then
        begin
          Result := B + C;
          Exit;
        end;
        if P = 0 then
          P := D * 0.3;
        if (A = 0) or (A < Abs(C)) then
        begin
          A := C;
          S := P / 4;
        end
        else
        begin
          S := P / (2 * Pi) * ArcSin((C / A));
        end;
        t := t - 1;
        Result := -(A * Power(2, (10 * t)) * Sin((t * D - S) * (2 * Pi) / P)) + B;
      end;
    TAnimationType.Out:
      begin
        if t = 0 then
        begin
          Result := B;
          Exit;
        end;
        t := t / D;
        if t = 1 then
        begin
          Result := B + C;
          Exit;
        end;
        if P = 0 then
          P := D * 0.3;
        if (A = 0) or (A < Abs(C)) then
        begin
          A := C;
          S := P / 4;
        end
        else
        begin
          S := P / (2 * Pi) * ArcSin((C / A));
        end;
        Result := A * Power(2, (-10 * t)) * Sin((t * D - S) * (2 * Pi) / P) + C + B;
      end;
    TAnimationType.InOut:
      begin
        if t = 0 then
        begin
          Result := B;
          Exit;
        end;
        t := t / (D / 2);
        if t = 2 then
        begin
          Result := B + C;
          Exit;
        end;
        if P = 0 then
          P := D * (0.3 * 1.5);
        if (A = 0) or (A < Abs(C)) then
        begin
          A := C;
          S := P / 4;
        end
        else
        begin
          S := P / (2 * Pi) * ArcSin((C / A));
        end;

        if t < 1 then
        begin
          t := t - 1;
          Result := -0.5 * (A * Power(2, (10 * t)) * Sin((t * D - S) * (2 * Pi) / P)) + B;
        end
        else
        begin
          t := t - 1;
          Result := A * Power(2, (-10 * t)) * Sin((t * D - S) * (2 * Pi) / P) * 0.5 + C + B;
        end;
      end;
  else
    Result := 0;
  end;
end;

function InterpolateExpo(t, B, C, D: Single; AType: TAnimationType): Single;
begin
  case AType of
    TAnimationType.In:
      begin
        If t = 0 Then
          Result := B
        else
          Result := C * Power(2, (10 * (t / D - 1))) + B;
      end;
    TAnimationType.Out:
      begin
        If t = D then
          Result := B + C
        else
          Result := C * (-Power(2, (-10 * t / D)) + 1) + B;
      end;
    TAnimationType.InOut:
      begin
        if t = 0 then
        begin
          Result := B;
          Exit;
        end;
        if t = D then
        begin
          Result := B + C;
          Exit;
        end;
        t := t / (D / 2);
        if t < 1 then
          Result := C / 2 * Power(2, (10 * (t - 1))) + B
        else
        begin
          t := t - 1;
          Result := C / 2 * (-Power(2, (-10 * t)) + 2) + B;
        end;
      end;
  else
    Result := 0;
  end;
end;

function InterpolateLinear(t, B, C, D: Single): Single;
begin
  Result := C * t / D + B;
end;

function InterpolateQuad(t, B, C, D: Single; AType: TAnimationType): Single;
begin
  case AType of
    TAnimationType.In:
      begin
        t := t / D;
        Result := C * t * t + B;
      end;
    TAnimationType.Out:
      begin
        t := t / D;
        Result := -C * t * (t - 2) + B;
      end;
    TAnimationType.InOut:
      begin
        t := t / (D / 2);

        if t < 1 then
          Result := C / 2 * t * t + B
        else
        begin
          t := t - 1;
          Result := -C / 2 * (t * (t - 2) - 1) + B;
        end;
      end;
  else
    Result := 0;
  end;
end;

function InterpolateQuart(t, B, C, D: Single; AType: TAnimationType): Single;
begin
  case AType of
    TAnimationType.In:
      begin
        t := t / D;
        Result := C * t * t * t * t + B;
      end;
    TAnimationType.Out:
      begin
        t := t / D - 1;
        Result := -C * (t * t * t * t - 1) + B;
      end;
    TAnimationType.InOut:
      begin
        t := t / (D / 2);
        if t < 1 then
          Result := C / 2 * t * t * t * t + B
        else
        begin
          t := t - 2;
          Result := -C / 2 * (t * t * t * t - 2) + B;
        end;
      end;
  else
    Result := 0;
  end;
end;

function InterpolateQuint(t, B, C, D: Single; AType: TAnimationType): Single;
begin
  case AType of
    TAnimationType.In:
      begin
        t := t / D;
        Result := C * t * t * t * t * t + B;
      end;
    TAnimationType.Out:
      begin
        t := t / D - 1;
        Result := C * (t * t * t * t * t + 1) + B;
      end;
    TAnimationType.InOut:
      begin
        t := t / (D / 2);
        if t < 1 then
          Result := C / 2 * t * t * t * t * t + B
        else
        begin
          t := t - 2;
          Result := C / 2 * (t * t * t * t * t + 2) + B;
        end;
      end;
  else
    Result := 0;
  end;
end;

function InterpolateSine(t, B, C, D: Single; AType: TAnimationType): Single;
begin
  case AType of
    TAnimationType.In:
      begin
        Result := -C * Cos(t / D * (Pi / 2)) + C + B;
      end;
    TAnimationType.Out:
      begin
        Result := C * Sin(t / D * (Pi / 2)) + B;
      end;
    TAnimationType.InOut:
      begin
        Result := -C / 2 * (Cos(Pi * t / D) - 1) + B;
      end;
  else
    Result := 0;
  end;
end;

{ TAnimator.TAnimationDestroyer }

procedure TAnimator.TAnimationDestroyer.DoAniFinished(Sender: TObject);
begin
  TThread.ForceQueue(nil, procedure begin
    TAnimation(Sender).Free;
  end);
end;

{ TAnimator }
(*
class procedure TAnimator.StartAnimation(const Target: TFmxObject; const AName: string);
var
  I: Integer;
  E: TAnimation;
begin
  I := 0;
  while (Target.Children <> nil) and (I < Target.Children.Count) do
  begin
    if Target.Children[I] is TAnimation then
      if CompareText(TAnimation(Target.Children[I]).Name, AName) = 0 then
      begin
        E := TAnimation(Target.Children[I]);
        E.Start;
      end;
    Inc(I);
  end;
end;

class procedure TAnimator.StopAnimation(const Target: TFmxObject; const AName: string);
var
  I: Integer;
  E: TAnimation;
begin
  if Target.Children <> nil then
    for I := Target.Children.Count - 1 downto 0 do
      if TFmxObject(Target.Children[I]) is TAnimation then
        if CompareText(TAnimation(Target.Children[I]).Name, AName) = 0 then
        begin
          E := TAnimation(Target.Children[I]);
          E.Stop;
        end;
end;

class procedure TAnimator.StartTriggerAnimation(const Target: TFmxObject; const AInstance: TFmxObject; const ATrigger: string);
var
  Animatable: ITriggerAnimation;
begin
  StopTriggerAnimation(Target, AInstance, ATrigger);
  if Supports(Target, ITriggerAnimation, Animatable) then
    Animatable.StartTriggerAnimation(AInstance, ATrigger)
  else
    DefaultStartTriggerAnimation(Target, AInstance, ATrigger);
end;

class procedure TAnimator.DefaultStartTriggerAnimation(const Target: TFmxObject; const AInstance: TFmxObject; const ATrigger: string);
var
  I: Integer;
  Control: IControl;
begin
  if (Target <> nil) and (Target.Children <> nil) then
    for I := 0 to Target.Children.Count - 1 do
    begin
      if Target.Children[I] is TAnimation then
        TAnimation(Target.Children[I]).StartTrigger(AInstance, ATrigger);
      if Supports(Target.Children[I], IControl, Control) and Control.Locked and not Control.HitTest then
        StartTriggerAnimation(Target.Children[I], AInstance, ATrigger);
    end;
end;

class procedure TAnimator.StartTriggerAnimationWait(const Target: TFmxObject; const AInstance: TFmxObject; const ATrigger: string);
var
  Animatable: ITriggerAnimation;
begin
  StopTriggerAnimation(Target, AInstance, ATrigger);
  if Supports(Target, ITriggerAnimation, Animatable) then
    Animatable.StartTriggerAnimationWait(AInstance, ATrigger)
  else
    DefaultStartTriggerAnimationWait(Target, AInstance, ATrigger);
end;

class procedure TAnimator.DefaultStartTriggerAnimationWait(const Target, AInstance: TFmxObject; const ATrigger: string);
var
  I: Integer;
  Control: IControl;
begin
  if Target.Children <> nil then
    for I := 0 to Target.Children.Count - 1 do
    begin
      if Target.Children[I] is TAnimation then
      begin
        TAnimation(Target.Children[I]).StartTrigger(AInstance, ATrigger);
        while TAnimation(Target.Children[I]).Running do
        begin
          Application.ProcessMessages;
          Sleep(0);
        end;
      end;
      if Supports(Target.Children[I], IControl, Control) and Control.Locked and not Control.HitTest then
        StartTriggerAnimationWait(Target.Children[I], AInstance, ATrigger);
    end;
end;

class procedure TAnimator.StopTriggerAnimation(const Target: TFmxObject; const AInstance: TFmxObject; const ATrigger: string);
var
  Item: TFmxObject;
  Control: IControl;
begin
  if Target.Children <> nil then
    for Item in Target.Children do
    begin
      if TFmxObject(Item) is TAnimation then
        TAnimation(Item).StopTrigger(AInstance, ATrigger);
      if Supports(Item, IControl, Control) and Control.Locked and not Control.HitTest then
        StopTriggerAnimation(Item, AInstance, ATrigger);
    end;
end;

{ Property animation }

class procedure TAnimator.AnimateColor(const Target: TFmxObject; const APropertyName: string; NewValue: TAlphaColor;
  Duration: Single = 0.2; AType: TAnimationType = TAnimationType.In;
  AInterpolation: TInterpolationType = TInterpolationType.Linear);
var
  Animation: TColorAnimation;
begin
  StopPropertyAnimation(Target, APropertyName);

  CreateDestroyer;

  Animation := TColorAnimation.Create(Target);
  Animation.Parent := Target;
  Animation.AnimationType := AType;
  Animation.Interpolation := AInterpolation;
  Animation.OnFinish := FDestroyer.DoAniFinished;
  Animation.Duration := Duration;
  Animation.PropertyName := APropertyName;
  Animation.StartFromCurrent := True;
  Animation.StopValue := NewValue;
  Animation.Start;
end;
*)

class procedure TAnimator.AnimateFloat(const Target: TComponent; const APropertyName: string; const NewValue: Single;
  Duration: Single; OnProcessProc: TProc<TRdAnimationFloat>; OnFinishProc: TProc; AutoReverse: Boolean;
  Delay: Single; AnimateType: TAnimateType);
var
  Animation: TRdAnimationFloat;
begin
  CreateDestroyer;
  AbortAnimate(Target, APropertyName);

  Animation := TRdAnimationFloat.Create(nil);
  Animation.Target := Target;
  Animation.AnimateType := AnimateType;
  if Assigned(OnProcessProc) then
  begin
    Animation.OnProcessProc :=
      procedure
      begin
        OnProcessProc(Animation);
      end;
  end;
  Animation.OnFinishProc := OnFinishProc;
  Animation.OnFinish := FDestroyer.DoAniFinished;
  Animation.Duration := Duration;
  Animation.AutoReverse := AutoReverse;
  Animation.Delay := Delay;
  Animation.PropertyName := APropertyName;
  Animation.StartFromCurrent := True;
  Animation.StopValue := NewValue;
  Animation.Start;

  {#
  if Animation.FindProperty then
  begin
    Animation.FirstFrame; //todo @获取初始值
    Animation.Duration := Abs((Animation.StopValue - Animation.StartValue) / ValuePerSecond);
    Animation.Start;
  end;}
end;

(*
class procedure TAnimator.AnimateFloat(const Target: TComponent; const APropertyName: string; const NewValue: Single;
  Duration: Single; OnFinishProc: TProc; AutoReverse: Boolean;
  Delay: Single; AnimateType: TAnimateType);
begin
  AnimateFloat(Target, APropertyName, NewValue, Duration, nil, OnFinishProc, AutoReverse, Delay, AnimateType);
end;

class procedure TAnimator.AnimateFloatWait(const Target: TFmxObject; const APropertyName: string; const NewValue: Single;
  Duration: Single = 0.2; AType: TAnimationType = TAnimationType.In;
  AInterpolation: TInterpolationType = TInterpolationType.Linear);
var
  Animation: TFloatAnimation;
begin
  StopPropertyAnimation(Target, APropertyName);

  Animation := TFloatAnimation.Create(nil);
  try
    Animation.Parent := Target;
    Animation.AnimationType := AType;
    Animation.Interpolation := AInterpolation;
    Animation.Duration := Duration;
    Animation.PropertyName := APropertyName;
    Animation.StartFromCurrent := True;
    Animation.StopValue := NewValue;
    Animation.Start;
    while Animation.FRunning do
    begin
      Application.ProcessMessages;
      Sleep(0);
    end;
  finally
    Animation.DisposeOf;
  end;
end;

*)

class procedure TAnimator.AbortAnimate(const Target: TComponent; const APropertyName: string);
var
  FFreeLst: TVclComponentList;
  I: Integer;
begin
  FFreeLst := PPointer(PByte(@Target.DesignInfo) - SizeOf(Pointer))^;

  if FFreeLst = nil then exit;

  I := FFreeLst.Count - 1;
  while I >= 0 do
  begin
    if (TObject(FFreeLst[I]) is TCustomPropertyAnimation) and
       (CompareText(TCustomPropertyAnimation(FFreeLst[I]).PropertyName, APropertyName) = 0) then
      TCustomPropertyAnimation(FFreeLst[I]).StopAtCurrent;
    if I > FFreeLst.Count then
      I := FFreeLst.Count;
    Dec(I);
  end;
end;

class procedure TAnimator.CreateDestroyer;
begin
  if FDestroyer = nil then
    FDestroyer := TAnimationDestroyer.Create;
end;

class procedure TAnimator.Uninitialize;
begin
  FreeAndNil(FDestroyer);
end;


{ TAniThread }

type

  TTimerThread = class(TThread)
  private
    FTimerEvent: TNotifyEvent;
    FInterval: Cardinal;
    FEnabled: Boolean;
    FEnabledEvent: TEvent;
    procedure SetEnabled(const Value: Boolean);
    procedure SetInterval(const Value: Cardinal);
  protected
    procedure Execute; override;
    procedure DoInterval;
  public
    constructor Create; virtual;
    destructor Destroy; override;

    property Interval: Cardinal read FInterval write SetInterval;
    property Enabled: Boolean read FEnabled write SetEnabled;
    property OnTimer: TNotifyEvent read FTimerEvent write FTimerEvent;
  end;

  TThreadTimer = class(TRdTimer)
  private
    FThread: TTimerThread;
//    procedure Timer;
  protected
    procedure SetOnTimer(Value: TNotifyEvent); override;
    procedure SetEnabled(Value: Boolean); override;
    procedure SetInterval(Value: Cardinal); override;
    procedure UpdateTimer; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

  TAniThread = class(TThreadTimer)
  private
    FAniFrameRate: Integer;
    FAniList: TList;//<TAnimation>;
    FTime, FDeltaTime: Double;
    procedure OneStep;
    procedure DoSyncTimer(Sender: TObject);
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    procedure AddAnimation(const Ani: TAnimation);
    function RemoveAnimation(const Ani: TAnimation): Integer;
  end;

var
  FPerformanceFrequency: Int64 = 0;
function GetTickSecond: Double;
var
  PerformanceCounter: Int64;
begin
  if FPerformanceFrequency <> 0 then
  begin
    QueryPerformanceCounter(PerformanceCounter);
    Result := PerformanceCounter / FPerformanceFrequency;
  end
  else
    Result := timeGetTime / 1000;
end;

function GetTimeValue: Double;
var
  PerformanceCounter: Int64;
begin
  if FPerformanceFrequency <> 0 then
  begin
    QueryPerformanceCounter(PerformanceCounter);
    Result := (PerformanceCounter * 1000.0) / FPerformanceFrequency;
  end
  else
    Result := timeGetTime;
end;

constructor TAniThread.Create;
begin
  TAnimation.AniFrameRate := EnsureRange(TAnimation.AniFrameRate, 5, 200);
  FAniFrameRate := TAnimation.AniFrameRate;
  inherited Create(nil);
  Interval := Trunc(1000 / FAniFrameRate / 10) * 10;

  OnTimer := DoSyncTimer;
  FAniList := TList.Create;
  FTime := GetTickSecond;

  Enabled := False;
end;

destructor TAniThread.Destroy;
var
  i: Integer;
begin
  for i := FAniList.Count - 1 downto 0 do
  begin
    TAnimation(FAniList[i]).Free;
  end;

  inherited;
  FreeAndNil(FAniList);
end;

procedure TAniThread.AddAnimation(const Ani: TAnimation);
begin
  if FAniList.IndexOf(Ani) < 0 then
    FAniList.Add(Ani);
  if not Enabled and (FAniList.Count > 0) then
    FTime := GetTickSecond;
  Enabled := FAniList.Count > 0;
end;

function TAniThread.RemoveAnimation(const Ani: TAnimation): Integer;
begin
  result := FAniList.Remove(Ani);
  Enabled := FAniList.Count > 0;
end;

procedure TAniThread.DoSyncTimer(Sender: TObject);
begin
  OneStep;
  if FAniFrameRate <> TAnimation.AniFrameRate then
  begin
    if TAnimation.AniFrameRate < 5 then
      TAnimation.AniFrameRate := 5;
    FAniFrameRate := TAnimation.AniFrameRate;
    Interval := Trunc(1000 / FAniFrameRate / 10) * 10;
  end;
end;

procedure TAniThread.OneStep;
var
  I: Integer;
  NewTime: Double;
  Ani: TAnimation;
begin
  NewTime := GetTickSecond;
  FDeltaTime := NewTime - FTime;
  FTime := NewTime;
  if FDeltaTime <= 0 then
    Exit;
  if FAniList.Count > 0 then
  begin
    I := FAniList.Count - 1;
    while I >= 0 do
    begin
      Ani := TAnimation(FAniList[I]);
      if Ani.FRunning then
      begin
        {if (FAniList[I].StyleName <> '') and
          (CompareText(FAniList[I].StyleName, 'caret') = 0) then
        begin
          FAniList[I].Tag := FAniList[I].Tag + 1;
          if FAniList[I].Tag mod 12 = 0 then
          begin
            FAniList[I].ProcessTick(FTime, FDeltaTime);
          end;
        end
        else          }
          Ani.ProcessTick(FTime, FDeltaTime);
      end;
      dec(I);
      if I >= FAniList.Count then
        I := FAniList.Count - 1;
    end;
  end;
end;

{ TAnimation }

procedure TAnimation.ParentChanged;
begin
//  inherited;
//  ParseTriggers(nil, False, False);
end;

procedure TAnimation.AssignTo(Dest: TPersistent);
var
  DestAnimation: TAnimation;
begin
  if Dest is TAnimation then
  begin
    DestAnimation := TAnimation(Dest);
//    DestAnimation.AnimationType := AnimationType;
    DestAnimation.AutoReverse := AutoReverse;
    DestAnimation.Duration := Duration;
    DestAnimation.Delay := Delay;
    DestAnimation.AnimateType := AnimateType;
    DestAnimation.Inverse := Inverse;
    DestAnimation.Loop := Loop;
//    DestAnimation.Trigger := Trigger;
//    DestAnimation.TriggerInverse := TriggerInverse;
    DestAnimation.Enabled := Enabled;
  end
  else
    inherited;
end;

constructor TAnimation.Create(AOwner: TComponent);
begin
  inherited;
  FTarget := nil;
  FEnabled := False;
  Duration := 0.2;
  FFinishCounter := 0;
end;

destructor TAnimation.Destroy;
begin
  if AniThread <> nil then
    TAniThread(AniThread).FAniList.Remove(Self);
//  FreeAndNil(FTriggerList);
//  FreeAndNil(FInverseTriggerList);
  inherited;
end;

procedure TAnimation.FirstFrame;
begin

end;

procedure TAnimation.Loaded;
begin
  inherited;
  if not (csDesigning in ComponentState) and Enabled then
  begin
    //异步执行，解决TargetForm启动过程中visible=false
    TThread.ForceQueue(nil, Start);
  end;
end;

procedure TAnimation.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove)and (AComponent <> nil) then
  begin
    if FTarget = AComponent then
      SetTarget(nil);
  end;
end;

procedure TAnimation.SetEnabled(const Value: Boolean);
begin
  if FEnabled <> Value then
  begin
    FEnabled := Value;
    if not(csDesigning in ComponentState) and not(csLoading in ComponentState) and
      not(csReading in ComponentState) then
    begin
      if FEnabled then
        Start
      else
        Stop;
    end;
  end;
end;

procedure TAnimation.SetTarget(const Value: TComponent);
var
  bak: TComponent;
begin
  if (FTarget = Value) or (Value = Self) then exit;

  if FTarget <> nil then
  begin
    FTarget.RemoveFreeNotification(Self);
  end;
  FTarget := Value;
//  FTargetObj := Value;
  if FTarget <> nil then
  begin
    bak := Self.Owner;
    PPointer(@Self.Owner)^ := nil;
    try
      Value.FreeNotification(Self);
    finally
      PPointer(@Self.Owner)^ := bak;
    end;
  end;

  ParentChanged;
end;
{
procedure TAnimation.SetTargetObj(const Value: TObject);
begin
  if (FTargetObj = Value) or (FTargetObj = self) then exit;

  FTargetObj := Value;
  if Value is TComponent then
    SetTarget(TComponent(Value))
  else
    ParentChanged;
end;    }

procedure TAnimation.SetTrigger(const Value: TTrigger);
begin
  FTrigger := Value;
//  ParseTriggers(nil, False, False);
end;

procedure TAnimation.SetTriggerInverse(const Value: TTrigger);
begin
  FTriggerInverse := Value;
//  ParseTriggers(nil, False, False);
end;

function TAnimation.GetNormalizedTime: Single;
begin
  Result := 0;
  if (FDuration > 0) and (FDelayTime <= 0) then
  begin
    case FAnimateType of
//      TAnimateType.customCubicBezier: CubicBezierCurves(FCurrentTime / FDuration, easeOutQuart);
      TAnimateType.Linear:
        Result := InterpolateLinear(FCurrentTime, 0, 1, FDuration);
      TAnimateType.easeQuadIn:
        Result := InterpolateQuad(FCurrentTime, 0, 1, FDuration, TAnimationType.In);
      TAnimateType.easeQuadOut:
        Result := InterpolateQuad(FCurrentTime, 0, 1, FDuration, TAnimationType.Out);
      TAnimateType.easeQuadInOut:
        Result := InterpolateQuad(FCurrentTime, 0, 1, FDuration, TAnimationType.InOut);

      TAnimateType.easeCubicIn:
        Result := InterpolateCubic(FCurrentTime, 0, 1, FDuration, TAnimationType.In);
      TAnimateType.easeCubicOut:
        Result := InterpolateCubic(FCurrentTime, 0, 1, FDuration, TAnimationType.Out);
      TAnimateType.easeCubicInOut:
        Result := InterpolateCubic(FCurrentTime, 0, 1, FDuration, TAnimationType.InOut);

      TAnimateType.easeExpoIn:
        Result := InterpolateExpo(FCurrentTime, 0, 1, FDuration, TAnimationType.In);
      TAnimateType.easeExpoOut:
        Result := InterpolateExpo(FCurrentTime, 0, 1, FDuration, TAnimationType.Out);
      TAnimateType.easeExpoInOut:
        Result := InterpolateExpo(FCurrentTime, 0, 1, FDuration, TAnimationType.InOut);

      TAnimateType.easeBackIn:
        Result := InterpolateBack(FCurrentTime, 0, 1, FDuration, 0, TAnimationType.In);
      TAnimateType.easeBackOut:
        Result := InterpolateBack(FCurrentTime, 0, 1, FDuration, 0, TAnimationType.Out);
      TAnimateType.easeBackInOut:
        Result := InterpolateBack(FCurrentTime, 0, 1, FDuration, 0, TAnimationType.InOut);

      TAnimateType.easeQuartIn:
        Result := InterpolateQuart(FCurrentTime, 0, 1, FDuration, TAnimationType.In);
      TAnimateType.easeQuartOut:
        Result := InterpolateQuart(FCurrentTime, 0, 1, FDuration, TAnimationType.Out);
      TAnimateType.easeQuartInOut:
        Result := InterpolateQuart(FCurrentTime, 0, 1, FDuration, TAnimationType.InOut);

      TAnimateType.easeQuintIn:
        Result := InterpolateQuint(FCurrentTime, 0, 1, FDuration, TAnimationType.In);
      TAnimateType.easeQuintOut:
        Result := InterpolateQuint(FCurrentTime, 0, 1, FDuration, TAnimationType.Out);
      TAnimateType.easeQuintInOut:
        Result := InterpolateQuint(FCurrentTime, 0, 1, FDuration, TAnimationType.InOut);

      TAnimateType.easeSineIn:
        Result := InterpolateSine(FCurrentTime, 0, 1, FDuration, TAnimationType.In);
      TAnimateType.easeSineOut:
        Result := InterpolateSine(FCurrentTime, 0, 1, FDuration, TAnimationType.Out);
      TAnimateType.easeSineInOut:
        Result := InterpolateSine(FCurrentTime, 0, 1, FDuration, TAnimationType.InOut);

      TAnimateType.easeCircIn:
        Result := InterpolateCirc(FCurrentTime, 0, 1, FDuration, TAnimationType.In);
      TAnimateType.easeCircOut:
        Result := InterpolateCirc(FCurrentTime, 0, 1, FDuration, TAnimationType.Out);
      TAnimateType.easeCircInOut:
        Result := InterpolateCirc(FCurrentTime, 0, 1, FDuration, TAnimationType.InOut);

   {
      TInterpolationType.Elastic:
        Result := InterpolateElastic(FCurrentTime, 0, 1, FDuration, 0, 0, FAnimationType);
      TInterpolationType.Bounce:
        Result := InterpolateBounce(FCurrentTime, 0, 1, FDuration, FAnimationType);}
    end;
  end;
end;

function TAnimation.GetRemainingTime: Single;
begin
  if not FInverse then //5s: 0-4s
    result := FDuration - FCurrentTime
  else
    result := FCurrentTime;
end;

class procedure TAnimation.Initialize;
begin
  if not QueryPerformanceFrequency(FPerformanceFrequency) then
    FPerformanceFrequency := 0;

  TAnimator.FDestroyer := nil;
  TAnimation.FAniThread := nil;
  TAnimation.AniFrameRate := 100;
end;

procedure TAnimation.DoProcess;
begin
  if Assigned(OnProcessProc) then
    OnProcessProc;
  if Assigned(FOnProcess) then
    FOnProcess(Self);
end;

procedure TAnimation.DoFinish;
begin
  inc(FFinishCounter);
  if Assigned(OnFinishProc) then
    OnFinishProc;
  if Assigned(FOnFinish) then
    FOnFinish(Self);
end;

procedure TAnimation.ProcessTick(time, deltaTime: Single);
var
  bkCounter: Integer;
begin
  inherited;
  if [csDesigning, csDestroying] * ComponentState <> [] then
    Exit;

  if (FTarget is TControl) and (not TControl(FTarget).Visible) then
    Stop;

  if (not FRunning) then
    Exit;

 // {@test事件内恢复
  if FPause then
  begin
    DoProcess;
    Exit;
  end;


  if (FDelay > 0) and (FDelayTime <> 0) then
  begin
    if FDelayTime > 0 then
    begin
      FDelayTime := FDelayTime - deltaTime;
      if FDelayTime <= 0 then
      begin
        FDelayTime := 0;
        if FInverse then
          FCurrentTime := FDuration
        else
          FCurrentTime := 0;
        FirstFrame;
        ProcessAnimation;
        DoProcess;
      end;
    end;
    Exit;
  end;

  if FInverse then
    FCurrentTime := FCurrentTime - deltaTime
  else
    FCurrentTime := FCurrentTime + deltaTime;
  if FCurrentTime >= FDuration then
  begin
    FCurrentTime := FDuration;
    if FLoop then
    begin
      if FAutoReverse then
      begin
        FInverse := True;
        FCurrentTime := FDuration;
      end
      else
        FCurrentTime := 0;
    end
    else
      if FAutoReverse and (FTickCount = 0) then
      begin
        Inc(FTickCount);
        FInverse := True;
        FCurrentTime := FDuration;
      end
      else
        FRunning := False;
  end
  else if FCurrentTime <= 0 then
  begin
    FCurrentTime := 0;
    if FLoop then
    begin
      if FAutoReverse then
      begin
        FInverse := False;
        FCurrentTime := 0;
      end
      else
        FCurrentTime := FDuration;
    end
    else
      if FAutoReverse and (FTickCount = 0) then
      begin
        Inc(FTickCount);
        FInverse := False;
        FCurrentTime := 0;
      end
      else
        FRunning := False;
  end;

  bkCounter := FFinishCounter;
  ProcessAnimation;
  DoProcess;

  if not FRunning then
  begin
    if AutoReverse then
      FInverse := FSavedInverse;

    //保证一次动画只finish一次，防止重复释放
    if bkCounter = FFinishCounter then
    begin
      if AniThread <> nil then
        TAniThread(AniThread).RemoveAnimation(Self);
      DoFinish;
    end;
  end;
end;

procedure TAnimation.Start;
var
  SaveDuration: Single;
begin
  if not FLoop then
    FTickCount := 0;
  if (FTarget is TControl) and (not TControl(FTarget).Visible) then
    Exit;
  if AutoReverse then
  begin
    if Running then
      FInverse := FSavedInverse
    else
      FSavedInverse := FInverse;
  end;
  if (Abs(FDuration) < 0.001) or (Target = nil) or (csDesigning in ComponentState) then
  begin
    { immediate animation }
    SaveDuration := FDuration;
    try
      FDelayTime := 0;
      FDuration := 1;
      if FInverse then
        FCurrentTime := 0
      else
        FCurrentTime := FDuration;
      FRunning := True;
      FirstFrame; //vcl bug?
      ProcessAnimation;
      DoProcess;
      FCurrentTime := 0;
      if FRunning then //fix 保证只执行一次DoFinish, 防止process中执行stop
      begin
        FRunning := False;
        DoFinish;
      end;
    finally
      FDuration := SaveDuration;
    end;
  end
  else
  begin
    FDelayTime := FDelay;
    FRunning := True;
    if FInverse then
      FCurrentTime := FDuration
    else
      FCurrentTime := 0;
    if FDelay = 0 then
    begin
      FirstFrame;
      ProcessAnimation;
      DoProcess;
    end;

    if FRunning then //fix 防止外部process事件再执行stop
    begin
      if AniThread = nil then
        FAniThread := TAniThread.Create;

      TAniThread(AniThread).AddAnimation(Self);
      if not TAniThread(AniThread).Enabled then
        Stop
      else
        FEnabled := True;
    end;
  end;
end;

procedure TAnimation.Stop;
begin
  if not FRunning then
    Exit;

  if AniThread <> nil then
    TAniThread(AniThread).RemoveAnimation(Self);

  if AutoReverse then
    FInverse := FSavedInverse;

  if FInverse then
    FCurrentTime := 0
  else
    FCurrentTime := FDuration;
  ProcessAnimation;
  DoProcess;
  if FRunning then //fix 保证只执行一次DoFinish, 防止process中执行stop
  begin
    FRunning := False;
    DoFinish;
  end;
end;

procedure TAnimation.StopAtCurrent;
begin
  if not FRunning then
    Exit;

  if AniThread <> nil then
    TAniThread(AniThread).RemoveAnimation(Self);

  if AutoReverse then
    FInverse := FSavedInverse;

  if FInverse then
    FCurrentTime := 0
  else
    FCurrentTime := FDuration;
  FEnabled := False;
  if FRunning then //fix 保证只执行一次DoFinish
  begin
    FRunning := False;
    DoFinish;
  end;
end;
(*
procedure TAnimation.ParseTriggers(const AInstance: TFmxObject; Normal, Inverse: Boolean);
var
  T: TRttiType;
  P: TRttiProperty;
  Line, Setter, Prop, Value: string;
  Trigger: TTriggerRec;
begin
  if AInstance = nil then
  begin
    if FTriggerList <> nil then
      FreeAndNil(FTriggerList);
    if FInverseTriggerList <> nil then
      FreeAndNil(FInverseTriggerList);
    FTargetClass := nil;
    Exit;
  end;

  if ((Inverse and (FInverseTriggerList <> nil)) or not Inverse)
    and ((Normal and (FTriggerList <> nil)) or not Normal) then Exit;

  T := SharedContext.GetType(AInstance.ClassInfo);
  if T = nil then Exit;

  while Inverse do
  begin
    if FInverseTriggerList <> nil then
      Break
    else
      FInverseTriggerList := TList<TTriggerRec>.Create;

    Line := FTriggerInverse;
    Setter := GetToken(Line, ';');
    while Setter <> '' do
    begin
      Prop := GetToken(Setter, '=');
      Value := Setter;
      P := T.GetProperty(Prop);
      if (P <> nil) and (P.PropertyType.TypeKind = tkEnumeration) then
      begin
        Trigger.Name := Prop;
        Trigger.Prop := P;
        Trigger.Value := StrToBoolDef(Value, True);
        FInverseTriggerList.Add(Trigger);
      end
      else
      begin
        FreeAndNil(FInverseTriggerList);
        Break;
      end;
      Setter := GetToken(Line, ';');
    end;
    Break;
  end;

  while Normal do
  begin
    if FTriggerList <> nil then
      Break
    else
      FTriggerList := TList<TTriggerRec>.Create;

    Line := FTrigger;
    Setter := GetToken(Line, ';');
    while Setter <> '' do
    begin
      Prop := GetToken(Setter, '=');
      Value := Setter;
      P := T.GetProperty(Prop);
      if (P <> nil) and (P.PropertyType.TypeKind = tkEnumeration) then
      begin
        Trigger.Name := Prop;
        Trigger.Prop := P;
        Trigger.Value := StrToBoolDef(Value, True);
        FTriggerList.Add(Trigger);
      end
      else
      begin
        FreeAndNil(FTriggerList);
        Break;
      end;
      Setter := GetToken(Line, ';');
    end;
    Break;
  end;

  if (FInverseTriggerList <> nil) or (FTriggerList <> nil) then
    FTargetClass := AInstance.ClassType;
end;

procedure TAnimation.StartTrigger(const AInstance: TFmxObject; const ATrigger: string);
var
  V: TValue;
  StartValue: Boolean;
  ContainsInTrigger, ContainsInTriggerInverse: Boolean;
  I: Integer;
  Trigger: TTriggerRec;
begin
  if AInstance = nil then
    Exit;

  ContainsInTrigger := ContainsText(FTrigger, ATrigger);
  ContainsInTriggerInverse := ContainsText(FTriggerInverse, ATrigger);

  ParseTriggers(AInstance, ContainsInTrigger, ContainsInTriggerInverse);

  if not AInstance.InheritsFrom(FTargetClass) then
    Exit;

  if ContainsInTrigger or ContainsInTriggerInverse then
  begin
    if (FInverseTriggerList <> nil) and (FInverseTriggerList.Count > 0) and ContainsInTriggerInverse then
    begin
      StartValue := False;
      for I := 0 to FInverseTriggerList.Count - 1 do
      begin
        Trigger := FInverseTriggerList[I];
        V := Trigger.Prop.GetValue(AInstance);
        StartValue := V.AsBoolean = Trigger.Value;
        if not StartValue then
          Break;
      end;
      if StartValue then
      begin
        Inverse := True;
        Start;
        Exit;
      end;
    end;
    if (FTriggerList <> nil) and (FTriggerList.Count > 0) and ContainsInTrigger then
    begin
      StartValue := False;
      for I := 0 to FTriggerList.Count - 1 do
      begin
        Trigger := FTriggerList[I];
        V := Trigger.Prop.GetValue(AInstance);
        StartValue := V.AsBoolean = Trigger.Value;
        if not StartValue then
          Break;
      end;
      if StartValue then
      begin
        if FTriggerInverse <> '' then
          Inverse := False;
        Start;
      end;
    end;
  end;
end;

procedure TAnimation.StopTrigger(const AInstance: TFmxObject; const ATrigger: string);
begin
  if AInstance = nil then
    Exit;
  if (FTriggerInverse <> '') and string(FTriggerInverse).ToLower.Contains(ATrigger.ToLower) then
    Stop;
  if (FTrigger <> '') and string(FTrigger).ToLower.Contains(ATrigger.ToLower) then
    Stop;
end;
*)
class procedure TAnimation.Uninitialize;
begin
  FreeAndNil(FAniThread);
end;

{ TCustomPropertyAnimation }

procedure TCustomPropertyAnimation.AssignTo(Dest: TPersistent);
var
  DestAnimation: TCustomPropertyAnimation;
begin
  if Dest Is TCustomPropertyAnimation then
  begin
    DestAnimation := TCustomPropertyAnimation(Dest);
    DestAnimation.Target := Target;
    DestAnimation.PropertyName := PropertyName;
  end;
  inherited;
end;

constructor TCustomPropertyAnimation.Create(AOwner: TComponent);
begin
  FPropKinds := [];
  inherited;
  FPropInfo := nil;
end;

function TCustomPropertyAnimation.FindProperty: Boolean;
var
  i,j,l, p, itemIndex: Integer;
  PropInfo: PPropInfo;
  Instance, PropValue: TObject;
  lastFullPath, PropName: string;
begin
  Result := False;

  if (Target = nil) or (FPropertyName = '') then exit;

  if (FInstance = nil) then
  begin
    FPropInfo := nil;
    FPropPath := '';
    Instance := Target;

    I := 1;
    L := Length(FPropertyName);

    while True do
    begin
      J := I;
      while (I <= L) and (FPropertyName[I] <> '.') do Inc(I);
      PropName := Copy(FPropertyName, J, I - J);
      {#if I < J then
        lastFullPath := Copy(FPropPath, 1, I - 1)
      else
        lastFullPath := '';}
      if I > L then Break;
      p := Length(PropName);
      itemIndex := -1;             //[0]
      if (p > 1)and(PropName[p] = ']') then
      begin
        while (p >= 1)and(PropName[p] <> '[') do Dec(p);
        if p >= 1 then
        if TryStrToInt(Copy(PropName, p + 1, Length(PropName)-p-1), itemIndex) then
        begin
          delete(PropName, p, Length(PropName)-p+1);
        end;

      end;

      lastFullPath := Copy(FPropertyName, 1, I - 1);
      //#if nowFSkin.FIgnoreValues.IndexOf(PropName) >= 0 then exit;


      PropInfo := GetPropInfo(FInstance.ClassInfo, PropName);
      if PropInfo = nil then
      begin
        PropName := FPropPath;
  //        if FPropName <> '' then
  //          PropertyError(FPropName);
        Exit;
      end;
      PropValue := nil;
      if PropInfo^.PropType^.Kind = tkClass then
        PropValue := TObject(GetOrdProp(Instance, PropInfo));
      if not (PropValue is TPersistent) then
        exit;//PropPathError;
      if (PropValue is TCollection)and (itemIndex >= 0) then
      if (itemIndex < TCollection(PropValue).Count) then
      begin
        PropValue := TCollection(PropValue).Items[itemIndex];
      end
      else
        exit;//PropPathError;

      Instance := TPersistent(PropValue);
      Inc(I);
    end;

    PropInfo := GetPropInfo(Instance.ClassInfo, PropName);
    if PropInfo <> nil then
    begin
      if PropInfo.PropType^.Kind in FPropKinds then
      begin
        FInstance := Instance;
        FPropInfo := PropInfo;
        FPropPath := PropName;
        result := True;
      end;
    end;
  end
  else
    Result := True;
end;

procedure TCustomPropertyAnimation.ParentChanged;
begin
  inherited;
  FInstance := nil;
end;

procedure TCustomPropertyAnimation.SetPropertyName(const AValue: string);
begin
  if not SameText(AValue, PropertyName) then
    FInstance := nil;
  FPropertyName := AValue;
end;

procedure TCustomPropertyAnimation.Start;
begin
  if FindProperty then
    inherited Start;
end;

procedure TCustomPropertyAnimation.Stop;
begin
  inherited Stop;
  FInstance := nil;
end;

{ TIntAnimation }

procedure TRdAnimationFloat.AssignTo(Dest: TPersistent);
var
  DestAnimation: TRdAnimationFloat;
begin
  if Dest is TRdAnimationFloat then
  begin
    DestAnimation := TRdAnimationFloat(Dest);
    DestAnimation.StartValue := StartValue;
    DestAnimation.StopValue := StopValue;
    DestAnimation.StartFromCurrent := StartFromCurrent;
  end;
  inherited;
end;

constructor TRdAnimationFloat.Create(AOwner: TComponent);
begin
  inherited;
  FPropKinds := [tkInteger, tkFloat];
  Duration := 0.2;
  FCurrentValue := 0;
  FStartValue := 0;
  FStopValue := 0;
end;

procedure TRdAnimationFloat.FirstFrame;
begin
  if StartFromCurrent and (FInstance <> nil) then
  begin
    case FPropInfo.PropType^.Kind of
      tkInteger: StartValue := GetOrdProp(FInstance, FPropInfo);
      tkFloat: StartValue := GetFloatProp(FInstance, FPropInfo);
//      tkInt64:
    end;
  end;
end;

function TRdAnimationFloat.GetRemainingValue: Single;
begin
  if not FInverse then
    result := Abs(FStopValue - FCurrentValue)
  else
    result := Abs(FCurrentValue - FStartValue);
end;

procedure TRdAnimationFloat.ProcessAnimation;
begin
  FCurrentValue := InterpolateSingle(FStartValue, FStopValue, NormalizedTime);
  if (FInstance <> nil) and (FPropInfo <> nil) then
  begin
    case FPropInfo.PropType^.Kind of
      tkInteger: SetOrdProp(FInstance, FPropInfo, Round(FCurrentValue));
      tkFloat: SetFloatProp(FInstance, FPropInfo, FCurrentValue);
    end;
  end;
end;

{ TTimerThread }

constructor TTimerThread.Create;
begin
  FEnabledEvent := TEvent.Create;
  Interval := 1;
  FEnabled := False;
  inherited Create(False);
end;

destructor TTimerThread.Destroy;
begin
  //先置空事件，防止thd.waitfor执行queue回调
  FTimerEvent := nil;
  Terminate;
  FEnabledEvent.SetEvent;
  inherited;
  FreeAndNil(FEnabledEvent);
end;

procedure TTimerThread.DoInterval;
begin
  if Assigned(FTimerEvent) then
    FTimerEvent(Self);
end;

procedure TTimerThread.Execute;
begin
  Priority := tpHigher;
  while not Terminated do
  begin
    Sleep(Interval);
    TThread.Synchronize(nil,
      procedure
      begin
        DoInterval;
      end);
    FEnabledEvent.WaitFor(windows.INFINITE);
  end;
end;

procedure TTimerThread.SetEnabled(const Value: Boolean);
begin
  if FEnabled <> Value then
  begin
    FEnabled := Value;
    if FEnabled then
      FEnabledEvent.SetEvent
    else
      FEnabledEvent.ResetEvent;
  end;
end;

procedure TTimerThread.SetInterval(const Value: Cardinal);
begin
  if Value > 0 then
    FInterval := Value
  else
    FInterval := 1;
end;

{ TThreadTimer }

constructor TThreadTimer.Create(AOwner: TComponent);
begin
  inherited;
  FThread := TTimerThread.Create;
end;

destructor TThreadTimer.Destroy;
begin
  FreeAndNil(FThread);
  inherited;
end;

procedure TThreadTimer.SetEnabled(Value: Boolean);
begin
  inherited;
  FThread.Enabled := Value;
end;

procedure TThreadTimer.SetInterval(Value: Cardinal);
begin
  inherited;
  FThread.Interval := Value;
end;

procedure TThreadTimer.SetOnTimer(Value: TNotifyEvent);
begin
  inherited;
  FThread.OnTimer := Value;
end;

procedure TThreadTimer.UpdateTimer;
begin
  // Don't invoke inherited method, because we take care under alternative timer implementation with Thread.
end;

initialization
  TAnimation.Initialize;
finalization
  TAnimation.Uninitialize;
  TAnimator.Uninitialize;

end.
