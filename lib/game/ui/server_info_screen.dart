import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../spacetime/cyborg_connection.dart';
import '../action_rpg_game.dart';
import '../palette.dart';

/// 지금 붙어 있는 서버가 어디인지 보여주는 화면.
///
/// **이 화면이 필요한 이유는 서버가 하나가 아니기 때문이다.** 개발 중에는 로컬,
/// 자체 호스팅 VPS, 클라우드를 오가고, 그때마다 "지금 내가 보고 있는 월드가
/// 어느 서버인가" 를 헷갈리기 쉽다. 두 사람이 서로를 못 볼 때 가장 먼저
/// 확인해야 하는 것도 이것이다 — 같은 서버에 있는지.
///
/// 값은 [kCyborgHost] 등 접속 상수에서 그대로 읽는다. 화면에 적힌 것과 실제
/// 접속처가 어긋나면 이 화면이 있으나 마나이므로, 따로 적어 두지 않고 **연결에
/// 쓰는 값 자체**를 보여 준다.
class ServerInfoScreen extends PositionComponent
    with TapCallbacks, HasGameReference<ActionRpgGame> {
  ServerInfoScreen() : super(priority: 141);

  static const double panelWidth = 440;
  static const double panelHeight = 340;

  static const Rect _closeRect = Rect.fromLTWH(panelWidth - 46, 14, 32, 32);

  /// 항목 한 줄의 높이.
  static const double _rowHeight = 40;

  /// 첫 줄이 시작되는 높이.
  static const double _listTop = 92;

  bool _open = false;
  double _anim = 0;

  bool get isOpen => _open;

  void open() => _open = true;
  void close() => _open = false;
  void toggle() => _open = !_open;

  // ── 좌표 변환 ───────────────────────────────────────────────────────

  @override
  void onGameResize(Vector2 newSize) {
    super.onGameResize(newSize);
    size = newSize;
  }

  double get _scale => math.min(
        1.0,
        math.min((size.x - 32) / panelWidth, (size.y - 32) / panelHeight),
      );

  Offset get _origin => Offset(
        (size.x - panelWidth * _scale) / 2,
        (size.y - panelHeight * _scale) / 2,
      );

  Offset _toPanel(Vector2 point) {
    final scale = _scale;
    final origin = _origin;
    return Offset(
      (point.x - origin.dx) / scale,
      (point.y - origin.dy) / scale,
    );
  }

  // ── 입력 ────────────────────────────────────────────────────────────

  @override
  bool containsLocalPoint(Vector2 point) => _open;

  @override
  void onTapDown(TapDownEvent event) {
    if (!_open) return;
    // 화면 전체를 덮으므로 탭이 조이스틱이나 액션 버튼까지 새지 않게 한다.
    event.handled = true;

    final local = _toPanel(event.localPosition);
    const panel = Rect.fromLTWH(0, 0, panelWidth, panelHeight);
    if (_closeRect.contains(local) || !panel.contains(local)) close();
  }

  // ── 갱신 ────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    final target = _open ? 1.0 : 0.0;
    _anim += (target - _anim) * math.min(1, dt * 14);
    if ((_anim - target).abs() < 0.005) _anim = target;
  }

  // ── 렌더링 ──────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    if (_anim <= 0.004) return;
    final t = _anim.clamp(0.0, 1.0);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = const Color(0xFF06202F).withValues(alpha: 0.5 * t),
    );

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(_scale * (0.94 + t * 0.06));
    canvas.translate(-panelWidth / 2, -panelHeight / 2);
    canvas.saveLayer(
      const Rect.fromLTWH(-30, -30, panelWidth + 60, panelHeight + 60),
      Paint()..color = Colors.white.withValues(alpha: t),
    );

    _renderPanel(canvas);

    canvas.restore();
    canvas.restore();
  }

  void _renderPanel(Canvas canvas) {
    const rect = Rect.fromLTWH(0, 0, panelWidth, panelHeight);
    final shape = RRect.fromRectAndRadius(rect, const Radius.circular(16));

    canvas.drawRRect(
      shape,
      Paint()
        ..color = GamePalette.shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawRRect(shape, Paint()..color = GamePalette.hudBackground);
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = GamePalette.hudBorder.withValues(alpha: 0.5),
    );

    _renderHeader(canvas);
    _renderRows(canvas);
  }

  void _renderHeader(Canvas canvas) {
    _text(
      canvas,
      '서버 정보',
      const Offset(20, 26),
      size: 19,
      weight: FontWeight.w900,
      color: GamePalette.textPrimary,
      letterSpacing: 1.2,
    );
    _text(
      canvas,
      'SpacetimeDB',
      const Offset(20, 52),
      size: 11,
      weight: FontWeight.w700,
      color: GamePalette.textDim,
      letterSpacing: 1.6,
    );

    // 닫기
    canvas.drawRRect(
      RRect.fromRectAndRadius(_closeRect, const Radius.circular(8)),
      Paint()..color = GamePalette.hudBorder.withValues(alpha: 0.25),
    );
    _text(
      canvas,
      '✕',
      Offset(_closeRect.center.dx - 6, _closeRect.center.dy - 8),
      size: 15,
      weight: FontWeight.w800,
      color: GamePalette.textPrimary,
    );

    canvas.drawLine(
      const Offset(20, 78),
      const Offset(panelWidth - 20, 78),
      Paint()
        ..strokeWidth = 1
        ..color = GamePalette.hudBorder.withValues(alpha: 0.3),
    );
  }

  void _renderRows(Canvas canvas) {
    final connected = game.presence.isAvailable;

    // **접속 주소가 이 화면의 본론이다.** 나머지는 그 주소를 읽을 때 함께
    // 알아야 하는 것들이다 — 어느 DB 인지, 암호화됐는지, 지금 붙어 있는지.
    final rows = <(String, String, Color)>[
      (
        '접속 주소',
        '${kCyborgSsl ? 'wss' : 'ws'}://$kCyborgHost',
        GamePalette.bladeGlow,
      ),
      ('데이터베이스', kCyborgDatabase, GamePalette.textPrimary),
      (
        '보안 연결',
        kCyborgSsl ? 'TLS 사용' : '평문 (TLS 없음)',
        kCyborgSsl ? GamePalette.textPrimary : GamePalette.hpFillLow,
      ),
      (
        '연결 상태',
        connected ? '월드에 접속됨' : '오프라인',
        connected ? GamePalette.safeZoneGlow : GamePalette.textDim,
      ),
      (
        '함께 있는 요원',
        connected ? '${game.remotePlayerCount} 명' : '—',
        GamePalette.textPrimary,
      ),
    ];

    for (var i = 0; i < rows.length; i++) {
      final (label, value, color) = rows[i];
      final y = _listTop + i * _rowHeight;

      // 줄마다 옅은 바탕을 번갈아 깔아 눈이 가로로 따라가기 쉽게 한다.
      if (i.isEven) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(16, y - 6, panelWidth - 32, _rowHeight - 6),
            const Radius.circular(8),
          ),
          Paint()..color = GamePalette.hudBorder.withValues(alpha: 0.12),
        );
      }

      _text(
        canvas,
        label,
        Offset(28, y),
        size: 12,
        weight: FontWeight.w700,
        color: GamePalette.textDim,
      );
      _text(
        canvas,
        value,
        Offset(148, y - 1),
        size: 13,
        weight: FontWeight.w800,
        color: color,
      );
    }

    // 주소가 코드 상수에서 온다는 것을 알려 둔다. 화면에 적힌 것과 실제 접속처가
    // 어긋날 수 없다는 뜻이고, 바꾸려면 어디를 봐야 하는지이기도 하다.
    _text(
      canvas,
      'lib/spacetime/cyborg_connection.dart 의 값을 그대로 읽는다',
      const Offset(20, panelHeight - 34),
      size: 10,
      weight: FontWeight.w600,
      color: GamePalette.textDim.withValues(alpha: 0.7),
    );
  }

  void _text(
    Canvas canvas,
    String value,
    Offset at, {
    required double size,
    required FontWeight weight,
    required Color color,
    double letterSpacing = 0,
  }) {
    TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: letterSpacing,
        ),
      ),
      textDirection: TextDirection.ltr,
    )
      ..layout()
      ..paint(canvas, at);
  }
}
