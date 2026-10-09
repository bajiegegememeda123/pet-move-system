unit MovementSystemHelper;

interface

uses
  System.Classes, Vcl.Forms, Vcl.Controls, Winapi.Windows, System.SysUtils, DateUtils,
  System.Types, System.Math, CommonConst, uPawpalMessage, uLkJSON, CommonState,
  RdAni, CollisionSystemHelper, CommonFunc, IED_Comm, LandingSystemHelper,
  WindowMonitorSystem, uProductStat3, ulog;

type

  TPetMovementSystem = class(TComponent)
  private
    FMainForm: TForm;
    FMarginTop: Integer;           // 猫咪窗口顶部边距
    FMarginLeft: Integer;          // 猫咪窗口左侧边距
    FWindowState: TWindowsStateType;
    FPriority: Integer; // 1~6优先级, 1最高6最低
    FLastJumpTime: Double;
    FLastJumpRect: TRect;
    FJumpUpIndex: Integer;

    // 获取猫咪子窗口的矩形区域
    function GetCatWindowRect: TRect;

    procedure SetCurX(const Value: Integer);
    procedure SetCurY(const Value: Integer);
    function GetCurX: Integer;
    function GetCurY: Integer;

    procedure MoveUpdate(AAnimateData: TRdAnimationFloat);
    procedure MoveFinished;

    function IsWalkingState: Boolean;
    procedure HandleCollision(AAnimateData: TRdAnimationFloat; IsBoundary: Boolean);
    procedure HandleJumpBehavior;
    procedure HandleTouchBehavior;

    function CalculateNewPosition(CurrentPos: Integer; RemainingValue: Single; CollisionDir: TMoveDirection; State: TWindowsStateType): Integer;
  public
    constructor Create(AForm: TForm; AMarginTop: Integer = 100; AMarginLeft: Integer = 190);
    procedure OnStartMove(AWindowState: TWindowsStateType; ANewValue: Single; ADuration: Single; APriority: Integer; ADelay: Single = 0);
    procedure OnStartMoveVertical(AWindowState: TWindowsStateType; ANewValue: Single; ADuration: Single; APriority: Integer; ADelay: Single = 0; ANewValueX: Single = 0);
    procedure PauseMovement;

    procedure HandleTurnDirection;
    property MainForm: TForm read FMainForm write FMainForm;
    property LastJumpRect:TRect read FLastJumpRect write FLastJumpRect;
  published
    property CurX: Integer read GetCurX write SetCurX;
    property CurY: Integer read GetCurY write SetCurY;
    property JumpUpIndex: Integer read FJumpUpIndex write FJumpUpIndex;
  end;

var
  g_PetMovementSystem: TPetMovementSystem = nil;

implementation

{ TPetMovementSystem }

function TPetMovementSystem.CalculateNewPosition(CurrentPos: Integer;
  RemainingValue: Single; CollisionDir: TMoveDirection;
  State: TWindowsStateType): Integer;
var
  DirectionMultiplier: integer;
begin
  DirectionMultiplier := 1;
  if (CollisionDir = mdLeftToRight) = (State <> wsBackward) then
    DirectionMultiplier := -1;
  Result := CurrentPos + Trunc(RemainingValue * DirectionMultiplier);
end;

constructor TPetMovementSystem.Create(AForm: TForm; AMarginTop: Integer = 100; AMarginLeft: Integer = 190);
begin
  inherited Create(nil);
  FMainForm := AForm;
  FMarginTop := AMarginTop;     // 设置顶部边距
  FMarginLeft := AMarginLeft;   // 设置左侧边距
  FWindowState := wsNone;
  FPriority := 6;
  FJumpUpIndex := 0;
  FLastJumpTime := StrToFloatDef(Common_ReadIniString(IED_GetLocalDataPath + 'Pawpal\PetCatData.ini', 'data', 'catjump', '0'), 0);
end;

function TPetMovementSystem.GetCatWindowRect: TRect;
var
  CatLeft, CatTop, CatWidth, CatHeight: Integer;
begin
  CatLeft := FMainForm.Left + FMarginLeft;
  CatTop := FMainForm.Top + FMarginTop;
  CatWidth := FMainForm.Width - (FMarginLeft * 2);
  CatHeight := FMainForm.Height - (FMarginTop * 2);

  Result := Rect(CatLeft, CatTop, CatLeft + CatWidth, CatTop + CatHeight);
end;

function TPetMovementSystem.GetCurX: Integer;
begin
  Result := FMainForm.Left;
end;

function TPetMovementSystem.GetCurY: Integer;
begin
  Result := FMainForm.Top;
end;

procedure TPetMovementSystem.HandleCollision(AAnimateData: TRdAnimationFloat;
  IsBoundary: Boolean);
var
  l_NewValue: Single;
  l_CollisionResult: TCollisionResult;
begin
  // 剩余距离
  l_NewValue := CalculateNewPosition(FMainForm.Left, AAnimateData.RemainingValue, G_CollisionSystem.CollisionDirection, FWindowState);

  // 切换方向
  HandleTurnDirection;

  l_CollisionResult.IsCollided := False;
  l_CollisionResult.Behavior := G_CollisionSystem.LastCollisionResult.Behavior;
  l_CollisionResult.CollisionRect := G_CollisionSystem.LastCollisionResult.CollisionRect;
  l_CollisionResult.CollisionHand := G_CollisionSystem.LastCollisionResult.CollisionHand;
  l_CollisionResult.CollisionType := G_CollisionSystem.LastCollisionResult.CollisionType;
  G_CollisionSystem.LastCollisionResult := l_CollisionResult;

  // 开始新动画
  TAnimator.AnimateFloat(self, 'CurX', l_NewValue, AAnimateData.RemainingTime, MoveUpdate, MoveFinished);
end;

procedure TPetMovementSystem.HandleJumpBehavior;
var
  l_CatRect: TRect;
  l_JumpJson: TlkJSONobject;
  l_JumpOver: Boolean;
  ClassName: array[0..255] of Char;
begin
  // 检查跳跃冷却时间
  if MinutesBetween(Now, FLastJumpTime) < 30 then
    Exit;

  // 记录跳跃时间
  FLastJumpTime := Now;
  Common_WriteIniString(IED_GetLocalDataPath + 'Pawpal\PetCatData.ini', 'data', 'catjump', FloatToStr(Now));

  l_CatRect := GetCatWindowRect;
  TAnimator.AbortAnimate(self, 'CurX');
  FLastJumpRect := G_CollisionSystem.LastCollisionResult.CollisionRect;
  G_CollisionSystem.MoveOnWinHand := G_CollisionSystem.LastCollisionResult.CollisionHand;

  // 通知web播放跳跃动作池
  l_JumpOver := (l_CatRect.Top - G_CollisionSystem.LastCollisionResult.CollisionRect.Top) < 300;
  l_JumpJson := TlkJSONobject.Create();
  if l_JumpOver then // 窗口高度小于300px，跳上去
    l_JumpJson.Add('isJumpOver', True)
  else
    l_JumpJson.Add('isJumpOver', False);

  PostWebMessage('update_jump_state', l_JumpJson);

  // 日志记录
  GetClassName(G_CollisionSystem.LastCollisionResult.CollisionHand, ClassName, SizeOf(ClassName));
  ulog.WriteLog('HandleJumpBehavior isJumpOver: '+ booltoStr(l_JumpOver));
  ulog.WriteLog('HandleJumpBehavior ClassName: '+ ClassName);
  ulog.WriteLog(Format('HandleJumpBehavior Rect: %d %d %d %d', [FLastJumpRect.Left, FLastJumpRect.Top, FLastJumpRect.Right, FLastJumpRect.Bottom]));
end;

procedure TPetMovementSystem.HandleTouchBehavior;
var
  l_JumpJson: TlkJSONobject;
begin
  PostWebMessage('update_touch_state', nil);
end;

procedure TPetMovementSystem.HandleTurnDirection;
var
  l_Direction: TlkJSONobject;
begin
  // 反转移动方向
  if G_CollisionSystem.CollisionDirection = mdLeftToRight then
  begin
    G_CollisionSystem.CollisionDirection := mdRightToLeft;
    l_Direction := TlkJSONobject.Create();
    l_Direction.Add('direction', 'right');
  end
  else
  begin
    G_CollisionSystem.CollisionDirection := mdLeftToRight;
    l_Direction := TlkJSONobject.Create();
    l_Direction.Add('direction', 'left');
  end;

  PostWebMessage('update_window_direction', l_Direction);
end;

function TPetMovementSystem.IsWalkingState: Boolean;
begin
  Result := (FWindowState = wsWalk) or (FWindowState = wsWalkSlow) or (FWindowState = wsWalkFast) or
  (FWindowState = wsRun) or (FWindowState = wsRunJump);
end;

procedure TPetMovementSystem.MoveFinished;
var
  l_WinState, l_Falling: TlkJSONobject;
begin
  // 通知web 窗口聚焦
  if FWindowState = wsJumpBig then
  begin
    l_WinState := TlkJSONobject.Create();
    l_WinState.Add('isWindowMode', True);
    PostWebMessage('update_window_state', l_WinState);
    G_CollisionSystem.MoveState := msOnWindows;

    G_WindowsStateTypeStr := WindowsStateType[TWindowsStateType.wsNone];

    G_WindowMonitorSystem.StopMonitoring;
    G_WindowMonitorSystem.StartMonitoring(G_CollisionSystem.MoveOnWinHand);

    DoStatCommon(1058,False)   //猫咪在窗口上次数
  end
  else
  if FWindowState = wsJumpClimb then
  begin
    l_WinState := TlkJSONobject.Create();
    l_WinState.Add('isWindowMode', StrToBool(IntToStr(Integer(G_CollisionSystem.MoveState))));
    PostWebMessage('update_window_state', l_WinState);

    G_WindowsStateTypeStr := WindowsStateType[TWindowsStateType.wsNone];
  end
  else
  if FWindowState = wsLanding then
  begin
    if G_WindowLandingSystem.LastOverlapResult.IsOverlap then
    begin
      PostWebMessage('update_hanging_window_state', nil);
      G_WindowMonitorSystem.StopMonitoring;
      G_WindowMonitorSystem.StartMonitoring(G_WindowLandingSystem.LastOverlapResult.OverlapHand, True);
    end
    else
    begin
      l_WinState := TlkJSONobject.Create();
      l_WinState.Add('isWindowMode', G_WindowLandingSystem.LastLandingResult.HasLandingTarget);
      PostWebMessage('update_window_state', l_WinState);

      l_Falling := TlkJSONobject.Create();
      l_Falling.Add('isFalling', False);
      PostWebMessage('updata_falling_state', l_Falling);

      if G_WindowLandingSystem.LastLandingResult.HasLandingTarget then
      begin
        G_CollisionSystem.MoveState := msOnWindows;
        G_CollisionSystem.MoveOnWinHand := G_WindowLandingSystem.LastLandingResult.LandingWinHand;

        G_WindowMonitorSystem.StopMonitoring;
        G_WindowMonitorSystem.StartMonitoring(G_CollisionSystem.MoveOnWinHand);

        DoStatCommon(1058,False)   //猫咪在窗口上次数
      end
      else
      begin
        G_CollisionSystem.MoveState := msOnTaskBar;
        G_CollisionSystem.MoveOnWinHand := G_WindowLandingSystem.LastLandingResult.LandingWinHand;

        G_WindowMonitorSystem.StopMonitoring;
      end;
      OutputDebugString(PChar('LandingWinHand: ' + IntToStr(G_WindowLandingSystem.LastLandingResult.LandingWinHand)));
    end;
    G_WindowsStateTypeStr := WindowsStateType[TWindowsStateType.wsNone];
    //记录所在屏幕，下次从这个屏幕右下角启动
    SaveCatScreenIndex(GetCatWindowRect);
  end
  else
  if FWindowState = wsJumpDown then
  begin
    G_WindowsStateTypeStr := WindowsStateType[TWindowsStateType.wsNone];
    l_WinState := TlkJSONobject.Create();
    l_WinState.Add('isWindowMode', False);
    PostWebMessage('update_window_state', l_WinState);

    G_CollisionSystem.MoveState := msOnTaskBar;
    G_CollisionSystem.MoveOnWinHand := 0;
    G_WindowMonitorSystem.StopMonitoring;
  end
  else
  if FWindowState = wsJumpUp then
  begin
    if FJumpUpIndex = 0 then
    begin
      TAnimator.AnimateFloat(self, 'CurY', FMainForm.Top + 200, 0.22173652695, nil, Self.MoveFinished, False, 0, TAnimateType.easeQuintIn);
      FJumpUpIndex := 1;
    end
    else
    begin
      G_WindowsStateTypeStr := WindowsStateType[TWindowsStateType.wsNone];
    end;
  end;

end;

procedure TPetMovementSystem.MoveUpdate(AAnimateData: TRdAnimationFloat);
var
  l_NewValue: Single;
  l_CatRect: TRect;
begin
  if G_Trigger_Pause or (G_WebisQuietMode and (G_WebAppState <> stGuide))  then
  begin
    PauseMovement;
  end;

  // 处理边界碰撞
  if G_CollisionSystem.LastCollisionResult.IsCollided and (G_CollisionSystem.LastCollisionResult.CollisionType = ctBoundary) then
  begin
    HandleCollision(AAnimateData, True); // True 表示边界碰撞
    Exit;
  end;

  // 只在行走状态且优先级为6时处理窗口碰撞
  if IsWalkingState and G_CollisionSystem.LastCollisionResult.IsCollided and
     (G_CollisionSystem.LastCollisionResult.CollisionType = ctWindow) and (FPriority = 6) then
  begin
    case G_CollisionSystem.LastCollisionResult.Behavior of
      cbJump: HandleJumpBehavior;
      cbTurn: HandleCollision(AAnimateData, False); // False 表示窗口碰撞
      cbTouch: HandleTouchBehavior;
    end;
    // outputdebugString(Pchar('CollisionSystem.Behavior: ' + inttostr(Integer(G_CollisionSystem.LastCollisionResult.Behavior))))
  end;
end;

procedure TPetMovementSystem.OnStartMove(AWindowState: TWindowsStateType;
  ANewValue, ADuration: Single; APriority: Integer; ADelay: Single);
begin
  FWindowState := AWindowState;
  FPriority := APriority;
  TAnimator.AnimateFloat(self, 'CurX', ANewValue, ADuration, Self.MoveUpdate, Self.MoveFinished, False, ADelay);
end;

procedure TPetMovementSystem.OnStartMoveVertical(
  AWindowState: TWindowsStateType; ANewValue, ADuration: Single;
  APriority: Integer; ADelay: Single; ANewValueX: Single);
begin
  FWindowState := AWindowState;
  FPriority := APriority;
  if FWindowState = wsJumpUp then
    TAnimator.AnimateFloat(self, 'CurY', ANewValue, ADuration, nil, Self.MoveFinished, False, ADelay, TAnimateType.easeQuintOut)
  else
  if (FWindowState = wsJumpBig) or  (FWindowState = wsJumpSmall) then
  begin
    TAnimator.AnimateFloat(self, 'CurY', ANewValue, ADuration, nil, Self.MoveFinished, False, ADelay, TAnimateType.easeBackOut);
    TAnimator.AnimateFloat(self, 'CurX', ANewValueX, ADuration, nil, nil, False, ADelay, TAnimateType.easeSineInOut)  //easeSineInOut
  end
  else
  if FWindowState = wsJumpClimb then
    TAnimator.AnimateFloat(self, 'CurY', ANewValue, ADuration, nil, Self.MoveFinished, False, ADelay, TAnimateType.easeCubicIn)
  else
  if FWindowState = wsLanding then
    TAnimator.AnimateFloat(self, 'CurY', ANewValue, ADuration, nil, Self.MoveFinished, False, ADelay, TAnimateType.easeCubicIn)
  else
  if FWindowState = wsJumpDown then
  begin
    TAnimator.AnimateFloat(self, 'CurY', ANewValue, ADuration, nil, Self.MoveFinished, False, ADelay, TAnimateType.easeBackIn);
    TAnimator.AnimateFloat(self, 'CurX', ANewValueX, ADuration, nil, nil, False, ADelay, TAnimateType.easeSineIn);
  end;

end;

procedure TPetMovementSystem.PauseMovement;
begin
  FWindowState := wsNone;
  TAnimator.AbortAnimate(self, 'CurX');
  TAnimator.AbortAnimate(self, 'CurY');
end;

procedure TPetMovementSystem.SetCurX(const Value: Integer);
begin
  FMainForm.Left := Value;
end;

procedure TPetMovementSystem.SetCurY(const Value: Integer);
begin
  FMainForm.Top := Value;
end;

end.

