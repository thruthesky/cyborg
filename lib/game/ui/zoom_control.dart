import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../action_rpg_game.dart';
import '../palette.dart';

/// 화면 왼쪽에 세로로 선 확대·축소 버튼 한 쌍과 현재 배율 표시.
///
/// 조이스틱 바로 위, 액션 버튼과 반대쪽에 둔다. 오른쪽 열은 공격·대시·자동
/// 사냥이 이미 채우고 있어 전투 중 엄지가 오가는 자리이고, 시야 조절은 전투
/// 도중 급히 누를 것이 아니기 때문이다.
class ZoomControl extends PositionComponent
    with HasGameReference<ActionRpgGame> {
  ZoomControl() : super(priority: 90);

  /// 버튼 반지름.
  static const double buttonRadius = 18;

  /// 두 버튼 중심 사이의 거리. 사이에 배율 표시가 들어간다.
  static const double buttonGap = 54;

  /// 화면 왼쪽 가장자리에서 버튼 중심까지.
  static const double leftMargin = 44;

  /// 조이스틱(반지름 62 + 아래 여백 40) 위로 띄우는 거리.
  ///
  /// 이 값이 아래쪽 버튼의 중심 높이가 된다. 조이스틱 윗변보다 위에 있어야
  /// 조이스틱을 잡으려다 배율을 건드리는 일이 없다.
  static const double bottomOffset = 200;

  final TextPaint _label = TextPaint(
    style: const TextStyle(
      color: GamePalette.textDim,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.5,
    ),
  );

  @override
  Future<void> onLoad() async {
    addAll([
      ZoomButton(zoomIn: true, position: Vector2(0, -buttonGap)),
      ZoomButton(zoomIn: false, position: Vector2.zero()),
    ]);
    _applyLayout(game.size);
  }

  @override
  void onGameResize(Vector2 newSize) {
    super.onGameResize(newSize);
    if (isLoaded) _applyLayout(newSize);
  }

  void _applyLayout(Vector2 screenSize) {
    // 세로가 짧은 창에서 좌상단 생존 정보 패널(높이 132)을 덮지 않도록
    // 위쪽에 하한을 둔다. 자동 사냥 버튼 열이 쓰는 것과 같은 방식이다.
    position = Vector2(
      leftMargin,
      math.max(buttonGap + 150, screenSize.y - bottomOffset),
    );
  }

  @override
  void render(Canvas canvas) {
    // 지금 배율을 두 버튼 사이에 적는다. 눌러도 화면이 더 안 변하는 순간이
    // 오는데, 숫자가 없으면 버튼이 고장 난 것인지 끝에 닿은 것인지 알 수 없다.
    _label.render(
      canvas,
      game.cameraZoom.label,
      Vector2(0, -buttonGap / 2),
      anchor: Anchor.center,
    );
  }
}

/// 확대 또는 축소 버튼 한 개.
///
/// [AutoHuntRadiusButton] 과 생김새를 맞췄다 — 같은 "한 단계씩 조절" 이라는
/// 동작이므로 다르게 보일 이유가 없다.
class ZoomButton extends PositionComponent
    with TapCallbacks, HasGameReference<ActionRpgGame> {
  ZoomButton({
    required this.zoomIn,
    this.radius = ZoomControl.buttonRadius,
    super.position,
  }) : super(size: Vector2.all(radius * 2), anchor: Anchor.center);

  /// true 면 당기는 버튼, false 면 물러나는 버튼이다.
  final bool zoomIn;

  final double radius;

  double _pressAnim = 0;

  /// 이 방향으로 더 갈 수 없는 상태인지.
  bool get _exhausted =>
      zoomIn ? !game.cameraZoom.canZoomIn : !game.cameraZoom.canZoomOut;

  @override
  bool containsLocalPoint(Vector2 point) {
    final dx = point.x - radius;
    final dy = point.y - radius;
    return dx * dx + dy * dy <= radius * radius;
  }

  @override
  void onTapDown(TapDownEvent event) {
    // 여기서 멈추지 않으면 바닥의 클릭 이동 레이어까지 내려가, 배율을 바꿀
    // 때마다 캐릭터가 화면 왼쪽으로 걸어간다.
    event.handled = true;
    _pressAnim = 1;
    if (zoomIn) {
      game.zoomIn();
    } else {
      game.zoomOut();
    }
  }

  @override
  void update(double dt) {
    if (_pressAnim > 0) _pressAnim = math.max(0, _pressAnim - dt * 5);
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(radius, radius);
    final dim = _exhausted;
    final press = 1 - _pressAnim * 0.12;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(press);
    canvas.translate(-center.dx, -center.dy);

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = GamePalette.hudBackground.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = GamePalette.hudBorder.withValues(alpha: dim ? 0.25 : 0.7),
    );

    final ink = GamePalette.textPrimary.withValues(alpha: dim ? 0.25 : 0.95);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = ink;

    // 돋보기. 알 안에 + 또는 − 를 넣어 어느 쪽인지 한눈에 읽히게 한다.
    final lens = center + const Offset(-1.5, -1.5);
    const lensRadius = 7.0;
    canvas.drawCircle(lens, lensRadius, stroke);
    canvas.drawLine(
      lens + const Offset(5, 5),
      lens + const Offset(9.5, 9.5),
      Paint()
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = ink,
    );

    final mark = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = ink;
    const arm = 3.4;
    canvas.drawLine(lens + const Offset(-arm, 0), lens + const Offset(arm, 0), mark);
    if (zoomIn) {
      canvas.drawLine(lens + const Offset(0, -arm), lens + const Offset(0, arm), mark);
    }

    canvas.restore();
  }
}
