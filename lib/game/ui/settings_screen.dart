import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../action_rpg_game.dart';
import '../audio/audio_settings.dart';
import '../audio/game_audio.dart';
import '../palette.dart';

/// 따로 조절하는 두 갈래 소리.
///
/// 선언 순서가 곧 화면에 그려지는 줄 순서다([SettingsScreen._rowRect] 가
/// `index` 로 자리를 잡는다).
enum _Channel {
  music('배경음', '월드에 흐르는 음악'),
  sfx('효과음', '전투·조작·획득음');

  const _Channel(this.label, this.description);

  final String label;
  final String description;
}

/// 소리 크기를 조절하는 설정 화면.
///
/// 캐릭터 화면·리더보드와 같은 방식으로 항상 붙어 있고 [isOpen] 으로만 열고
/// 닫는다. 월드는 모두가 공유하는 실시간 공간이라 이 패널이 떠 있어도 게임은
/// 멈추지 않는다 — 볼륨을 만지는 동안에도 로봇은 다가온다.
///
/// 값은 [GameAudio] 에 곧바로 걸리고, 손을 뗄 때 [AudioSettings] 가 기기에
/// 남긴다. 그래서 배경음은 끄는 즉시 귀로 확인되고, 효과음은 손을 뗄 때 나는
/// 클릭음으로 크기를 가늠할 수 있다.
class SettingsScreen extends PositionComponent
    with TapCallbacks, DragCallbacks, HasGameReference<ActionRpgGame> {
  SettingsScreen() : super(priority: 143);

  /// 기준 해상도에서의 패널 크기. 화면이 좁으면 통째로 축소한다.
  static const double panelWidth = 400;
  static const double panelHeight = 264;

  /// 볼륨 한 줄이 차지하는 높이.
  static const double rowHeight = 64;

  /// 첫 줄이 시작되는 높이(머리 부분 아래).
  static const double rowsTop = 70;

  static const Rect _closeRect = Rect.fromLTWH(panelWidth - 46, 14, 32, 32);

  /// 음소거 줄. 볼륨 두 줄 아래에 붙는다.
  static const Rect _muteRect = Rect.fromLTWH(
    20,
    rowsTop + rowHeight * 2,
    panelWidth - 40,
    46,
  );

  bool _open = false;
  double _anim = 0;

  /// 손가락이 잡고 있는 슬라이더. 없으면 null.
  _Channel? _dragging;

  /// 눌렸다가 아직 손을 떼지 않은 슬라이더.
  _Channel? _pressed;

  /// 음소거 줄을 누르고 있는 중인지.
  bool _pressedMute = false;

  bool get isOpen => _open;

  void open() {
    _open = true;
    _clearPresses();
  }

  void close() {
    _open = false;
    _clearPresses();
  }

  void toggle() => _open ? close() : open();

  void _clearPresses() {
    _dragging = null;
    _pressed = null;
    _pressedMute = false;
  }

  final TextPaint _title = TextPaint(
    style: const TextStyle(
      color: GamePalette.hudBorder,
      fontSize: 15,
      fontWeight: FontWeight.w900,
      letterSpacing: 2,
    ),
  );
  final TextPaint _hint = TextPaint(
    style: const TextStyle(
      color: GamePalette.textDim,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
    ),
  );
  final TextPaint _label = TextPaint(
    style: const TextStyle(
      color: GamePalette.textPrimary,
      fontSize: 15,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.4,
    ),
  );
  final TextPaint _desc = TextPaint(
    style: const TextStyle(
      color: GamePalette.textDim,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    ),
  );
  final TextPaint _value = TextPaint(
    style: const TextStyle(
      color: GamePalette.hudBorder,
      fontSize: 15,
      fontWeight: FontWeight.w900,
    ),
  );

  // ── 좌표 ────────────────────────────────────────────────────────────

  @override
  void onGameResize(Vector2 newSize) {
    super.onGameResize(newSize);
    size = newSize;
  }

  /// 화면에 맞춘 패널 축소 비율. 작은 화면에서는 통째로 줄여 넣는다.
  double get _scale => math.min(
    1.0,
    math.min((size.x - 32) / panelWidth, (size.y - 32) / panelHeight),
  );

  Offset get _origin => Offset(
    (size.x - panelWidth * _scale) / 2,
    (size.y - panelHeight * _scale) / 2,
  );

  /// 화면 좌표를 패널 내부 좌표로 옮긴다.
  Offset _toPanel(Vector2 point) {
    final scale = _scale;
    final origin = _origin;
    return Offset(
      (point.x - origin.dx) / scale,
      (point.y - origin.dy) / scale,
    );
  }

  /// 슬라이더 한 줄이 차지하는 영역. 손가락이 굵어도 잡히도록 줄 전체가
  /// 판정 영역이다.
  static Rect _rowRect(int index) => Rect.fromLTWH(
    20,
    rowsTop + rowHeight * index,
    panelWidth - 40,
    rowHeight - 8,
  );

  /// 실제로 그려지는 홈. 값과 x 좌표의 환산 기준이기도 하다.
  static Rect _trackRect(int index) {
    final row = _rowRect(index);
    return Rect.fromLTWH(row.left + 10, row.bottom - 16, row.width - 20, 6);
  }

  /// 음소거 줄 오른쪽에 놓이는 토글 스위치.
  static Rect get _switchRect => Rect.fromLTWH(
    _muteRect.right - 66,
    _muteRect.center.dy - 12,
    46,
    24,
  );

  /// [point] 가 가리키는 슬라이더. 슬라이더 밖이면 null.
  _Channel? _channelAt(Offset point) {
    for (final channel in _Channel.values) {
      if (_rowRect(channel.index).contains(point)) return channel;
    }
    return null;
  }

  /// 홈 위의 x 좌표를 0~1 의 볼륨으로 환산한다.
  double _ratioAt(double x, int index) {
    final track = _trackRect(index);
    return ((x - track.left) / track.width).clamp(0.0, 1.0);
  }

  // ── 값 ──────────────────────────────────────────────────────────────

  double _volumeOf(_Channel channel) => switch (channel) {
    _Channel.music => GameAudio.musicVolume,
    _Channel.sfx => GameAudio.sfxVolume,
  };

  void _setVolume(_Channel channel, double value) {
    // 퍼센트로 적어 두고 실제로는 그보다 미세한 값을 들고 있으면, 같은 표기에서
    // 서로 다른 크기가 난다. 표기 단위인 1% 로 끊는다.
    final quantized = (value.clamp(0.0, 1.0) * 100).round() / 100;
    switch (channel) {
      case _Channel.music:
        // 흐르는 중인 트랙에 바로 반영되므로 결과가 귀에 들린다.
        unawaited(GameAudio.setMusicVolume(quantized));
      case _Channel.sfx:
        GameAudio.setSfxVolume(quantized);
    }
  }

  /// 손을 뗀 값을 확정한다.
  void _commit(_Channel channel) {
    // 효과음은 이 순간까지 아무 소리도 나지 않았다. 방금 고른 크기를 한 번
    // 들려줘야 무엇을 고른 것인지 알 수 있다.
    if (channel == _Channel.sfx) GameAudio.play(Sfx.uiClick);
    unawaited(AudioSettings.save());
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
    if (_closeRect.contains(local) || !panel.contains(local)) {
      game.closeSettingsScreen();
      return;
    }

    if (_muteRect.contains(local)) {
      _pressedMute = true;
      return;
    }

    final channel = _channelAt(local);
    if (channel == null) return;
    // 누른 자리로 손잡이가 곧장 옮겨 간다. 이어지는 드래그는 그 자리에서
    // 손가락을 따라간다.
    _pressed = channel;
    _setVolume(channel, _ratioAt(local.dx, channel.index));
  }

  @override
  void onTapUp(TapUpEvent event) {
    final channel = _pressed;
    final mute = _pressedMute;
    _pressed = null;
    _pressedMute = false;
    if (!_open) return;

    if (mute) {
      // 누른 자리에서 손을 뗐을 때만 켜고 끈다.
      if (_muteRect.contains(_toPanel(event.localPosition))) game.toggleMute();
      return;
    }
    if (channel != null) _commit(channel);
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    _pressed = null;
    _pressedMute = false;
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (!_open) return;
    event.handled = true;
    _dragging = _channelAt(_toPanel(event.localPosition));
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    final channel = _dragging;
    if (!_open || channel == null) return;
    // 손잡이는 이미 손가락 아래에 있다(누른 순간 옮겨 갔다). 그 자리에서 움직인
    // 만큼만 더한다. 패널이 축소돼 있으면 손가락이 움직인 화면 거리보다 홈
    // 위에서 더 많이 움직여야 하므로 배율로 나눈다.
    final track = _trackRect(channel.index);
    _setVolume(
      channel,
      _volumeOf(channel) + event.localDelta.x / _scale / track.width,
    );
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    final channel = _dragging;
    _dragging = null;
    if (channel != null) _commit(channel);
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _dragging = null;
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
      Paint()..color = GamePalette.shadow.withValues(alpha: 0.5 * t),
    );

    // 히트 테스트(`_toPanel`)와 같은 배율·중심을 쓴다. 열리는 동안의 미세한
    // 확대는 연출일 뿐이라 판정에는 반영하지 않는다.
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
    for (final channel in _Channel.values) {
      _renderSlider(canvas, channel);
    }
    _renderMuteRow(canvas);
  }

  void _renderHeader(Canvas canvas) {
    _title.render(canvas, 'SOUND', Vector2(24, 30), anchor: Anchor.centerLeft);
    _hint.render(canvas, '소리 크기', Vector2(96, 31), anchor: Anchor.centerLeft);
    canvas.drawLine(
      const Offset(24, 54),
      const Offset(panelWidth - 24, 54),
      Paint()
        ..strokeWidth = 1
        ..color = GamePalette.hudBorder.withValues(alpha: 0.25),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(_closeRect, const Radius.circular(8)),
      Paint()..color = GamePalette.hudInset,
    );
    final center = _closeRect.center;
    final cross = Paint()
      ..color = GamePalette.textDim
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center + const Offset(-6, -6),
      center + const Offset(6, 6),
      cross,
    );
    canvas.drawLine(
      center + const Offset(6, -6),
      center + const Offset(-6, 6),
      cross,
    );
  }

  void _renderSlider(Canvas canvas, _Channel channel) {
    final index = channel.index;
    final row = _rowRect(index);
    final track = _trackRect(index);
    final volume = _volumeOf(channel);
    // 음소거 중에는 어차피 아무 소리도 나지 않는다. 그 사실이 보이도록 흐린다.
    final alpha = GameAudio.muted ? 0.35 : 1.0;
    final accent = GamePalette.hudBorder.withValues(alpha: alpha);

    _label.render(
      canvas,
      channel.label,
      Vector2(row.left + 10, row.top + 12),
      anchor: Anchor.centerLeft,
    );
    _desc.render(
      canvas,
      channel.description,
      Vector2(row.left + 74, row.top + 13),
      anchor: Anchor.centerLeft,
    );
    _value.render(
      canvas,
      '${(volume * 100).round()}%',
      Vector2(row.right - 10, row.top + 12),
      anchor: Anchor.centerRight,
    );

    // 홈.
    canvas.drawRRect(
      RRect.fromRectAndRadius(track, const Radius.circular(3)),
      Paint()..color = GamePalette.hudInset,
    );
    // 채워진 만큼.
    if (volume > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(track.left, track.top, track.width * volume, track.height),
          const Radius.circular(3),
        ),
        Paint()..color = accent,
      );
    }

    // 손잡이. 잡고 있는 동안에는 조금 커지고 테두리에 빛이 돈다.
    final held = _dragging == channel || _pressed == channel;
    final knob = Offset(track.left + track.width * volume, track.center.dy);
    if (held) {
      canvas.drawCircle(
        knob,
        16,
        Paint()..color = accent.withValues(alpha: 0.18 * alpha),
      );
    }
    canvas.drawCircle(knob, held ? 11 : 9, Paint()..color = GamePalette.hudBackground);
    canvas.drawCircle(
      knob,
      held ? 11 : 9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = accent,
    );
  }

  void _renderMuteRow(Canvas canvas) {
    final muted = GameAudio.muted;
    final accent = muted ? GamePalette.hpFillLow : GamePalette.hudBorder;

    if (_pressedMute) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(_muteRect, const Radius.circular(10)),
        Paint()..color = accent.withValues(alpha: 0.16),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(_muteRect, const Radius.circular(10)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = accent.withValues(alpha: 0.3),
    );

    _drawSpeaker(
      canvas,
      Offset(_muteRect.left + 26, _muteRect.center.dy),
      accent,
      silent: muted,
    );
    _label.render(
      canvas,
      '음소거',
      Vector2(_muteRect.left + 50, _muteRect.center.dy - 7),
      anchor: Anchor.centerLeft,
    );
    _desc.render(
      canvas,
      muted ? '모든 소리를 끈 상태' : 'V 키로도 켜고 끈다',
      Vector2(_muteRect.left + 50, _muteRect.center.dy + 10),
      anchor: Anchor.centerLeft,
    );

    // 토글 스위치.
    final track = _switchRect;
    canvas.drawRRect(
      RRect.fromRectAndRadius(track, const Radius.circular(12)),
      Paint()
        ..color = muted
            ? accent.withValues(alpha: 0.85)
            : GamePalette.hudInset,
    );
    canvas.drawCircle(
      Offset(muted ? track.right - 12 : track.left + 12, track.center.dy),
      9,
      Paint()..color = GamePalette.hudBackground,
    );
  }

  /// 스피커. [silent] 면 소리 대신 X 를 붙인다.
  void _drawSpeaker(
    Canvas canvas,
    Offset center,
    Color color, {
    required bool silent,
  }) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(
      Path()
        ..moveTo(center.dx - 8, center.dy - 3)
        ..lineTo(center.dx - 4, center.dy - 3)
        ..lineTo(center.dx, center.dy - 8)
        ..lineTo(center.dx, center.dy + 8)
        ..lineTo(center.dx - 4, center.dy + 3)
        ..lineTo(center.dx - 8, center.dy + 3)
        ..close(),
      stroke,
    );

    if (silent) {
      canvas.drawLine(
        center + const Offset(3, -4),
        center + const Offset(9, 4),
        stroke,
      );
      canvas.drawLine(
        center + const Offset(9, -4),
        center + const Offset(3, 4),
        stroke,
      );
      return;
    }

    for (final radius in const [4.0, 7.5]) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 3,
        math.pi * 2 / 3,
        false,
        stroke,
      );
    }
  }
}
