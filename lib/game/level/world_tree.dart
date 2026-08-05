import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../entities/iso_entity.dart';
import '../iso.dart';
import '../palette.dart';

/// 월드 정중앙, 안전지대 한복판에 선 나무.
///
/// 1 km² 짜리 데이터 공간은 어디를 봐도 비슷하게 생겨서, 눈으로 잡을 수 있는
/// 기준점이 없으면 방향 감각이 무너진다. 이 나무는 그 기준점이다 — 멀리서도
/// 보이도록 크게 세우고, 적의 마젠타와 정반대편인 안전지대의 민트-그린으로
/// 빛나게 해서 "저기가 안전지대"라는 신호를 겸한다.
///
/// 순수한 이정표라 판정이 없다. 통과해 지나갈 수 있고 피해도 입지 않는다.
class WorldTree extends IsoEntity {
  WorldTree({required super.grid}) : super(bodyRadius: 0.9, depthBias: 0);

  /// 줄기 높이(타일 z 단위). 화면에서는 이 값 × [kHeightUnit] 픽셀이 된다.
  static const double _trunkHeight = 5.0;

  /// 잎이 뭉친 수관(樹冠)의 반지름(픽셀).
  static const double _canopyRadius = 104.0;

  /// 줄기 밑동의 절반 폭(픽셀).
  static const double _rootHalfWidth = 26.0;

  /// 줄기 꼭대기의 절반 폭(픽셀). 위로 갈수록 가늘어진다.
  static const double _topHalfWidth = 9.0;

  /// 수관 중심의 화면 y(위쪽이 음수).
  static const double _canopyY = -_trunkHeight * kHeightUnit;

  /// 수관 아래쪽 끝의 화면 y. [_canopyBlobs] 중 가장 낮게 내려오는 덩어리의
  /// 바닥이며, 가지를 어디서 갈라야 잎에 묻히지 않는지를 정한다.
  static const double _canopyBottomY = _canopyY + _canopyRadius * 1.06;

  /// 수관 주위를 도는 데이터 입자의 수.
  static const int _moteCount = 14;

  /// 매 프레임 다시 그릴 필요가 없는 줄기·수관을 담아 두는 캐시.
  ui.Picture? _cached;
  double _time = 0;

  /// 입자마다 고정된 궤도 값(시작 위상, 각속도, 궤도 반지름, 높이).
  ///
  /// 실행할 때마다 배치가 달라지면 이정표로서의 인상이 흔들리므로 고정 씨앗을
  /// 쓴다. 여러 클라이언트에서도 같은 모습으로 보인다.
  static final List<_Mote> _motes = _buildMotes();

  static List<_Mote> _buildMotes() {
    final rng = math.Random(20260805);
    return List.generate(_moteCount, (i) {
      return _Mote(
        phase: rng.nextDouble() * math.pi * 2,
        speed: 0.35 + rng.nextDouble() * 0.5,
        orbit: _canopyRadius * (0.75 + rng.nextDouble() * 0.55),
        height: _canopyY + (rng.nextDouble() - 0.5) * _canopyRadius * 1.3,
        radius: 1.6 + rng.nextDouble() * 2.2,
      );
    });
  }

  @override
  Future<void> onLoad() async {
    _cached = _record();
  }

  @override
  void onRemove() {
    _cached?.dispose();
    _cached = null;
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  /// 밑동에서 꼭대기까지 이어지는 줄기의 윤곽.
  Path _trunkPath() {
    const top = _canopyY + kHeightUnit * 0.6;
    return Path()
      ..moveTo(-_rootHalfWidth, 0)
      ..quadraticBezierTo(-_topHalfWidth * 1.6, top * 0.45, -_topHalfWidth, top)
      ..lineTo(_topHalfWidth, top)
      ..quadraticBezierTo(_topHalfWidth * 1.6, top * 0.45, _rootHalfWidth, 0)
      ..close();
  }

  /// 수관을 이루는 잎 덩어리들. (중심 x, 중심 y, 반지름).
  static const List<(double, double, double)> _canopyBlobs = [
    (0, _canopyY - _canopyRadius * 0.34, _canopyRadius * 0.82),
    (-_canopyRadius * 0.62, _canopyY, _canopyRadius * 0.66),
    (_canopyRadius * 0.62, _canopyY + _canopyRadius * 0.06, _canopyRadius * 0.7),
    (-_canopyRadius * 0.24, _canopyY + _canopyRadius * 0.46, _canopyRadius * 0.6),
    (_canopyRadius * 0.3, _canopyY + _canopyRadius * 0.5, _canopyRadius * 0.54),
  ];

  ui.Picture _record() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    _renderRoots(canvas);
    _renderTrunk(canvas);
    _renderCanopy(canvas);

    return recorder.endRecording();
  }

  /// 밑동에서 바닥으로 퍼져 나가는 뿌리. 지면의 데이터 회로와 이어진 모습이다.
  void _renderRoots(Canvas canvas) {
    final root = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5
      ..color = GamePalette.safeZoneEdge.withValues(alpha: 0.55);

    // 아이소메트릭 지면이라 가로로 넓고 세로로 눌린 방향으로 뻗는다.
    const spread = [
      Offset(-kHalfTileWidth * 0.8, kHalfTileHeight * 0.42),
      Offset(kHalfTileWidth * 0.8, kHalfTileHeight * 0.42),
      Offset(-kHalfTileWidth * 0.55, -kHalfTileHeight * 0.34),
      Offset(kHalfTileWidth * 0.55, -kHalfTileHeight * 0.34),
    ];
    for (final end in spread) {
      canvas.drawPath(
        Path()
          ..moveTo(0, -4)
          ..quadraticBezierTo(end.dx * 0.5, end.dy * 0.2, end.dx, end.dy),
        root,
      );
    }
  }

  void _renderTrunk(Canvas canvas) {
    final trunk = _trunkPath();
    final bounds = trunk.getBounds();

    // 밝은 배경 위에서 실루엣이 죽지 않도록 줄기는 짙게 유지한다.
    canvas.drawPath(
      trunk,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(bounds.left, 0),
          Offset(bounds.right, 0),
          const [
            Color(0xFF12303F),
            Color(0xFF1E5468),
            Color(0xFF0E2733),
          ],
          const [0.0, 0.42, 1.0],
        ),
    );

    // 줄기를 타고 오르는 수액 — 이 세계에서는 흐르는 데이터다.
    final vein = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = GamePalette.safeZoneGlow.withValues(alpha: 0.75);
    canvas.drawPath(
      Path()
        ..moveTo(-6, -8)
        ..quadraticBezierTo(4, _canopyY * 0.45, -2, _canopyY * 0.9),
      vein,
    );
    canvas.drawPath(
      Path()
        ..moveTo(7, -6)
        ..quadraticBezierTo(-2, _canopyY * 0.5, 5, _canopyY * 0.85),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = GamePalette.safeZoneFill.withValues(alpha: 0.5),
    );

    // 수관으로 갈라져 들어가는 가지.
    //
    // 수관은 이 뒤에 그려서 가지 끝을 덮으므로, 갈라지는 지점은 수관 아래쪽
    // 끝보다 더 낮아야 한다. 그렇지 않으면 가지가 통째로 잎에 묻힌다.
    final branch = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6
      ..color = const Color(0xFF16404F);
    const baseY = _canopyBottomY + 66;
    const tipY = _canopyBottomY - 16;
    for (final dx in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(0, baseY)
          ..quadraticBezierTo(
            dx * _canopyRadius * 0.28,
            baseY - 30,
            dx * _canopyRadius * 0.6,
            tipY,
          ),
        branch,
      );
    }
  }

  void _renderCanopy(Canvas canvas) {
    // 잎 덩어리를 겹쳐 쌓아 부피를 만든다. 아래는 그늘, 위는 빛을 받는다.
    for (final (cx, cy, r) in _canopyBlobs) {
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(cx - r * 0.3, cy - r * 0.45),
            r * 1.25,
            [
              GamePalette.safeZoneFill.withValues(alpha: 0.95),
              GamePalette.safeZoneGlow.withValues(alpha: 0.9),
              GamePalette.safeZoneEdge.withValues(alpha: 0.85),
            ],
            const [0.0, 0.55, 1.0],
          ),
      );
    }

    // 잎 사이로 비치는 밝은 결.
    final sparkle = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final rng = math.Random(7);
    for (var i = 0; i < 18; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final d = rng.nextDouble() * _canopyRadius * 0.95;
      canvas.drawCircle(
        Offset(math.cos(a) * d, _canopyY + math.sin(a) * d * 0.8),
        1 + rng.nextDouble() * 1.8,
        sparkle,
      );
    }
  }

  @override
  void render(Canvas canvas) {
    renderShadow(canvas, _rootHalfWidth * 1.9, radiusY: _rootHalfWidth * 0.95);

    final picture = _cached;
    if (picture != null) canvas.drawPicture(picture);

    // 수관을 감싼 후광의 맥동. 안전지대 경계의 맥동과 같은 호흡으로 뛴다.
    final pulse = 0.5 + 0.3 * math.sin(_time * 1.8);
    canvas.drawCircle(
      const Offset(0, _canopyY),
      _canopyRadius * 1.12,
      Paint()
        ..color = GamePalette.safeZoneGlow.withValues(alpha: pulse * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );

    // 나무 주위를 도는 데이터 입자.
    for (final mote in _motes) {
      final angle = mote.phase + _time * mote.speed;
      final bob = math.sin(_time * mote.speed * 1.7 + mote.phase) * 10;
      // 앞으로 돌아올 때는 커지고, 뒤로 돌아갈 때는 옅어진다.
      final depth = (math.sin(angle) + 1) / 2;
      canvas.drawCircle(
        Offset(
          math.cos(angle) * mote.orbit,
          mote.height + math.sin(angle) * mote.orbit * 0.28 + bob,
        ),
        mote.radius * (0.6 + depth * 0.7),
        Paint()
          ..color = GamePalette.dataMote
              .withValues(alpha: 0.25 + depth * 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }
}

/// 나무 주위를 도는 데이터 입자 하나의 고정된 궤도.
class _Mote {
  const _Mote({
    required this.phase,
    required this.speed,
    required this.orbit,
    required this.height,
    required this.radius,
  });

  /// 궤도의 시작 위상(라디안).
  final double phase;

  /// 각속도(라디안/초).
  final double speed;

  /// 궤도 반지름(픽셀).
  final double orbit;

  /// 궤도가 놓인 화면 y.
  final double height;

  /// 입자의 크기(픽셀).
  final double radius;
}
