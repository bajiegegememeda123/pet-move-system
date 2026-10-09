unit MessageHandler;

interface

uses
  uLkJSON, PSafeIniFile, IED_Comm, Vcl.Forms, CommonState, Winapi.Windows,
  Vcl.Controls, Winapi.Messages, uPawpalMessage, Math,
  System.StrUtils, System.SysUtils, CommonConst, MovementSystemHelper,
  CollisionSystemHelper, LandingSystemHelper, Ulog;


type
  TWindowsStateType = (
    // X 轴移动
    wsWalkSlow,   // 慢走
    wsWalk,       // 行走
    wsWalkFast,   // 快走
    wsRun,        // 跑步
    wsRunJump,    // 跑跳
    wsRunJumpWithDelay1,  // 跑跳1倍速 带延迟 Step=待定  前摇待定 运动待定
    wsRunJumpWithDelay2,  // 跑跳2倍速 带延迟 Step=70  前摇0.05 运动0.4034
    wsRunJumpWithLag1, // 跑跳1倍速 带前摇 Step=待定  前摇待定 运动待定
    wsRunJumpWithLag2, // 跑跳2倍速 带前摇 Step=待定  前摇待定 运动待定
    wsBackward,   // 后退
    //Y轴移动
    wsJumpSmall,  // 跳跃到窗口边缘（跳不上去）
    wsJumpClimb,  // 跳跃到窗口边缘-后滑落
    wsJumpBig,    // 跳跃到窗口 (跳上去), 带延迟 前摇0.1 运动0.8068
    wsJumpUp,     // 原地跳 Y轴-200  前摇1.97604790419
    wsJumpDown,   // 窗口往下跳 带延迟 x_Step=120 y_Step=屏幕底部 前摇0.1 运动0.8068
    // 程序控制
    wsPickUp,     // 拎起 (跟随鼠标移动)
    wsLanding,    // 下落
    // 静止
    wsNone        // 窗口停止移动
  );

  TWebAppState = (stNormal, stGuide, stBottomRight);

  TMainCloseState = (stClose, stHidden);

const
  // 窗口状态类型常量映射
  WindowsStateType: array[TWindowsStateType] of string = ('WalkSlow', 'Walk', 'WalkFast',
    'Run', 'RunJump', 'RunJumpWithDelay1', 'RunJumpWithDelay2','RunJumpWithLag1', 'RunJumpWithLag2',
    'Backward', 'JumpSmall', 'JumpClimb', 'JumpBig', 'JumpUp', 'JumpDown', 'PickUp', 'Landing', 'None');



function OnWindowState(const a_Param: TlkJSONobject): TlkJSONobject;

implementation

procedure CalcLoopValue(const a_LoopCount: Integer; var a_Step: Single; var a_MotionDuration: Single);
begin
  if a_LoopCount > 1 then
  begin
    a_Step := a_Step * a_LoopCount;
    a_MotionDuration := a_MotionDuration * a_LoopCount;
  end;
  if G_CollisionSystem.CollisionDirection = mdLeftToRight then
    a_Step := Application.MainForm.Left + a_Step
  else if G_CollisionSystem.CollisionDirection = mdRightToLeft then
    a_Step := Application.MainForm.Left - a_Step;
end;

function OnWindowState(const a_Param: TlkJSONobject): TlkJSONobject;
var
  l_Motion: string;
  l_MotionDuration: Single;
  l_LoopCount: Integer;
  l_PriorityNum: Integer;
  l_RandomDirection: integer;
  l_Step: Single;
begin
  Result := nil;

  if G_Trigger_Pause or (G_WebisQuietMode and (G_WebAppState <> stGuide)) then
    Exit;

  if Assigned(a_Param.Field['windowState']) then
    l_Motion := a_Param.Field['windowState'].Value;
  if Assigned(a_Param.Field['motionDuration']) then
    l_MotionDuration := a_Param.Field['motionDuration'].Value;
  if Assigned(a_Param.Field['loopCount']) then
    l_LoopCount := a_Param.Field['loopCount'].Value;
  if Assigned(a_Param.Field['priorityNum']) then
    l_PriorityNum := a_Param.Field['priorityNum'].Value;
  if Assigned(a_Param.Field['randomDirection']) then
  begin
    l_RandomDirection := a_Param.Field['randomDirection'].Value;
    if l_RandomDirection > 0 then
    begin
      // 几率转向
      if Random(100) < l_RandomDirection then
      begin
        if Assigned(g_PetMovementSystem) then
        begin
          g_PetMovementSystem.HandleTurnDirection;
          ulog.WriteLog('OnWindowState: ' +  l_Motion);
          ulog.WriteLog('randomDirection: ' +  inttostr(l_RandomDirection));
          ulog.WriteLog('HandleTurnDirection: ');
        end;
      end;

    end;
  end;

  if not Assigned(g_PetMovementSystem) then
    g_PetMovementSystem := TPetMovementSystem.Create(Application.MainForm, DEFAULT_MARGIN_TOP, DEFAULT_MARGIN_LEFT);


  // wsLanding wsJumpBig wsJumpClimb过程忽略其它Windows State
  if (G_WindowsStateTypeStr = WindowsStateType[TWindowsStateType.wsLanding]) or
  (G_WindowsStateTypeStr = WindowsStateType[TWindowsStateType.wsJumpBig]) or
  (G_WindowsStateTypeStr = WindowsStateType[TWindowsStateType.wsJumpClimb]) or
  (G_WindowsStateTypeStr = WindowsStateType[TWindowsStateType.wsJumpDown]) or
  (G_WindowsStateTypeStr = WindowsStateType[TWindowsStateType.wsJumpUp])then
    Exit;
  G_WindowsStateTypeStr := l_Motion;
  G_CollisionSystem.BackwardFlag := False;

  if l_Motion = WindowsStateType[TWindowsStateType.wsWalkSlow] then
  begin
    l_Step := 30;
    CalcLoopValue(l_LoopCount, l_Step, l_MotionDuration);
    g_PetMovementSystem.OnStartMove(TWindowsStateType.wsWalkSlow, l_Step, l_MotionDuration, l_PriorityNum);
  end
  else
  if l_Motion = WindowsStateType[TWindowsStateType.wsWalk] then
  begin
    l_Step := 35;
    CalcLoopValue(l_LoopCount, l_Step, l_MotionDuration);
    g_PetMovementSystem.OnStartMove(TWindowsStateType.wsWalk, l_Step, l_MotionDuration, l_PriorityNum);
  end
  else
  if l_Motion = WindowsStateType[TWindowsStateType.wsWalkFast] then
  begin
    l_Step := 40;
    CalcLoopValue(l_LoopCount, l_Step, l_MotionDuration);
    g_PetMovementSystem.OnStartMove(TWindowsStateType.wsWalkFast, l_Step, l_MotionDuration, l_PriorityNum);
  end
  else
  if l_Motion = WindowsStateType[TWindowsStateType.wsRun] then
  begin
    l_Step := 90;
    CalcLoopValue(l_LoopCount, l_Step, l_MotionDuration);
    g_PetMovementSystem.OnStartMove(TWindowsStateType.wsRun, l_Step, l_MotionDuration, l_PriorityNum);
  end
  else
  if l_Motion = WindowsStateType[TWindowsStateType.wsRunJump] then
  begin
    l_Step := 90;
    CalcLoopValue(l_LoopCount, l_Step, l_MotionDuration);
    g_PetMovementSystem.OnStartMove(TWindowsStateType.wsRunJump, l_Step, l_MotionDuration, l_PriorityNum);
  end
  else
  if l_Motion = WindowsStateType[TWindowsStateType.wsRunJumpWithDelay1] then
  begin
    l_Step := 120;
    CalcLoopValue(l_LoopCount, l_Step, l_MotionDuration);
    g_PetMovementSystem.OnStartMove(TWindowsStateType.wsRunJumpWithDelay1, l_Step, 0.6, l_PriorityNum,0.4);
  end
  else
  if l_Motion = WindowsStateType[TWindowsStateType.wsRunJumpWithDelay2] then
  begin
    l_Step := 100;
    CalcLoopValue(l_LoopCount, l_Step, l_MotionDuration);
    g_PetMovementSystem.OnStartMove(TWindowsStateType.wsRunJumpWithDelay2, l_Step, 0.3, l_PriorityNum,0.2);
  end
  else
  if l_Motion = WindowsStateType[TWindowsStateType.wsRunJumpWithLag1] then
  begin
    l_Step := 120;
    CalcLoopValue(l_LoopCount, l_Step, l_MotionDuration);                         // 22 / 32 * 1             // 5/ 31 * 1
    g_PetMovementSystem.OnStartMove(TWindowsStateType.wsRunJumpWithLag1, l_Step, 0.5, l_PriorityNum,0.25);
  end
  else
  if l_Motion = WindowsStateType[TWindowsStateType.wsRunJumpWithLag2] then
  begin
    l_Step := 70;
    CalcLoopValue(l_LoopCount, l_Step, l_MotionDuration);                         // 25 / 34 0.55             // 5 / 34  * 0.55
    g_PetMovementSystem.OnStartMove(TWindowsStateType.wsRunJumpWithLag2, l_Step, 0.25, l_PriorityNum, 0.125);
  end
  else
  if l_Motion = WindowsStateType[TWindowsStateType.wsBackward] then
  begin
    G_CollisionSystem.BackwardFlag := True;
    l_Step := -40;
    CalcLoopValue(l_LoopCount, l_Step, l_MotionDuration);
    g_PetMovementSystem.OnStartMove(TWindowsStateType.wsBackward, l_Step, l_MotionDuration, l_PriorityNum);
  end
  else
  if l_Motion = WindowsStateType[TWindowsStateType.wsJumpUp] then
  begin
    l_Step := 200;
    l_Step := Application.MainForm.Top - l_Step;
    g_PetMovementSystem.JumpUpIndex := 0;                                       //0.57634730539
    g_PetMovementSystem.OnStartMoveVertical(TWindowsStateType.wsJumpUp, l_Step, 0.48173652695, l_PriorityNum, 2.10604790419);
  end
  else
  if l_Motion = WindowsStateType[TWindowsStateType.wsJumpBig] then
  begin
    if G_CollisionSystem.CollisionDirection = mdLeftToRight then
      g_PetMovementSystem.OnStartMoveVertical(TWindowsStateType.wsJumpBig, g_PetMovementSystem.LastJumpRect.Top - Application.MainForm.Height +  DEFAULT_MARGIN_TOP, 0.8068, l_PriorityNum, 0.1, g_PetMovementSystem.LastJumpRect.Left - DEFAULT_MARGIN_LEFT)
    else
    if G_CollisionSystem.CollisionDirection = mdRightToLeft then
      g_PetMovementSystem.OnStartMoveVertical(TWindowsStateType.wsJumpBig, g_PetMovementSystem.LastJumpRect.Top - Application.MainForm.Height +  DEFAULT_MARGIN_TOP, 0.8068, l_PriorityNum, 0.1, g_PetMovementSystem.LastJumpRect.Right - Application.MainForm.Width + DEFAULT_MARGIN_LEFT);
  end
  else
  if l_Motion = WindowsStateType[TWindowsStateType.wsJumpSmall] then
  begin
    // 固定跳240px  +-27px 模型原因，手动控制贴近一点
    if G_CollisionSystem.CollisionDirection = mdLeftToRight then
      g_PetMovementSystem.OnStartMoveVertical(TWindowsStateType.wsJumpSmall, Application.MainForm.Top - 240 , l_MotionDuration, l_PriorityNum, 0, g_PetMovementSystem.LastJumpRect.Left - Application.MainForm.Width + DEFAULT_MARGIN_LEFT + 27)
    else
    if G_CollisionSystem.CollisionDirection = mdRightToLeft then
      g_PetMovementSystem.OnStartMoveVertical(TWindowsStateType.wsJumpSmall, Application.MainForm.Top - 240 , l_MotionDuration, l_PriorityNum, 0, g_PetMovementSystem.LastJumpRect.Right - DEFAULT_MARGIN_LEFT - 27)
    else
  end
  else
  if l_Motion = WindowsStateType[TWindowsStateType.wsJumpClimb] then
  begin
    if l_LoopCount > 1 then
      l_MotionDuration := l_LoopCount * l_MotionDuration;
    // 接的wsJumpSmall跳240px, 所以下落240px
    g_PetMovementSystem.OnStartMoveVertical(TWindowsStateType.wsJumpClimb, Application.MainForm.Top + 240 , l_MotionDuration, l_PriorityNum, 0)
  end
  else
  if l_Motion = WindowsStateType[TWindowsStateType.wsLanding] then
  begin
    if G_WindowLandingSystem.LastOverlapResult.IsOverlap then
    begin
      if G_WindowLandingSystem.CheckCatWindowOverlap then
        l_Step := G_WindowLandingSystem.LastOverlapResult.OverlapRect.Top - DEFAULT_MARGIN_TOP
      else
        G_WindowLandingSystem.CheckLanding;
    end;

    if not G_WindowLandingSystem.LastOverlapResult.IsOverlap then
    begin
      if G_WindowLandingSystem.LastLandingResult.HasLandingTarget then
        l_Step := G_WindowLandingSystem.LastLandingResult.LandingRect.Top  - Application.MainForm.Height +  DEFAULT_MARGIN_TOP + DEFAULT_MARGIN_Top_Correct
      else
        l_Step := G_WindowLandingSystem.LastLandingResult.LandingRect.Bottom  - Application.MainForm.Height +  DEFAULT_MARGIN_TOP + DEFAULT_MARGIN_Top_Correct;
    end;
    // 根据距离，预估一个时间   0.3 - 2.3
    l_MotionDuration := Max(0.3, (l_Step - Application.MainForm.Top) * 0.15 / 100);
    l_MotionDuration := Min(2.3, l_MotionDuration);

    g_PetMovementSystem.OnStartMoveVertical(TWindowsStateType.wsLanding, l_Step , l_MotionDuration , l_PriorityNum, 0)
  end
  else
  if l_Motion = WindowsStateType[TWindowsStateType.wsJumpDown] then
  begin
    l_Step := 120;
    CalcLoopValue(l_LoopCount, l_Step, l_MotionDuration);
    g_PetMovementSystem.OnStartMoveVertical(TWindowsStateType.wsJumpDown, G_WindowLandingSystem.LastLandingResult.LandingRect.Bottom  - Application.MainForm.Height + DEFAULT_MARGIN_TOP, 0.8068, l_PriorityNum, 0.1, l_Step);
  end
  else
    g_PetMovementSystem.PauseMovement;
end;

end.

