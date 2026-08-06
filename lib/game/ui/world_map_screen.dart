import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../action_rpg_game.dart';
import '../level/level_map.dart';
import '../level/teleport_destinations.dart';
import '../palette.dart';
import '../systems/monster_codex.dart';

/// 월드 좌표와 지도 위의 자리를 오가는 환산기.
///
/// 지도에서 조용히 틀리기 쉬운 것은 색이 아니라 **자리**다 — 축이 뒤집히거나
/// 반 칸씩 밀리면 내 표식이 엉뚱한 곳에 찍히는데, 지형 축소판 위에서는 그것이
/// 그럴듯해 보인다. 그래서 환산만 Flame 없이 시험할 수 있도록 떼어 둔다.
class WorldMapProjection {
  const WorldMapProjection({
    required this.mapRect,
    required this.worldWidth,
    required this.worldHeight,
  });

  /// [area] 안에 월드를 **비율을 지켜** 앉힌 환산기.
  ///
  /// 가로세로를 따로 늘이면 월드가 눌려 들어간다. 그러면 위험 등급 고리는
  /// 원인데 지형은 타원이 되어, 고리와 실제 거리가 축마다 다르게 어긋난다.
  /// 남는 여백은 위아래(또는 좌우)로 균등하게 나눈다.
  factory WorldMapProjection.fit({
    required Rect area,
    required double worldWidth,
    required double worldHeight,
  }) {
    final scale = math.min(area.width / worldWidth, area.height / worldHeight);
    final width = worldWidth * scale;
    final height = worldHeight * scale;
    return WorldMapProjection(
      mapRect: Rect.fromLTWH(
        area.left + (area.width - width) / 2,
        area.top + (area.height - height) / 2,
        width,
        height,
      ),
      worldWidth: worldWidth,
      worldHeight: worldHeight,
    );
  }

  /// 지도가 그려지는 영역(패널 내부 좌표).
  final Rect mapRect;

  /// 월드 한 변의 칸 수.
  final double worldWidth;
  final double worldHeight;

  /// 월드 한 칸이 지도에서 차지하는 길이.
  double get tileScale => mapRect.width / worldWidth;

  /// 월드 그리드 좌표를 지도 위의 자리로 옮긴다.
  Offset toMap(Vector2 grid) => Offset(
    mapRect.left + grid.x / worldWidth * mapRect.width,
    mapRect.top + grid.y / worldHeight * mapRect.height,
  );

  /// 지도 위의 자리를 월드 그리드 좌표로 되돌린다.
  Vector2 toGrid(Offset point) => Vector2(
    (point.dx - mapRect.left) / mapRect.width * worldWidth,
    (point.dy - mapRect.top) / mapRect.height * worldHeight,
  );
}

/// 월드 전체를 한 장에 담은 지도.
///
/// 이 월드는 걸어서 1 km 짜리 단일 맵이고, 주둔 로봇의 위험 등급은 시작 지점에서
/// 멀어질수록 1에서 200까지 오른다([MonsterCodex.regionLevel]). 그런데 화면에는
/// 반경 30 m 남짓의 근접 레이더밖에 없어서, **어느 쪽이 얼마나 위험한지 알 길이
/// 없었다.** 레벨 12 요원이 무심코 서쪽으로 3분을 걸으면 레벨 80 구역에 들어가
/// 영문도 모른 채 쓰러진다.
///
/// 이 지도는 그 판단 근거를 준다 — 위험 등급 고리, 안전지대, 텔레포트 목적지,
/// 같은 월드에 있는 다른 요원, 그리고 지금 내가 선 자리다. 지도를 눌러 그 지점의
/// 위험도와 거리도 재 볼 수 있다.
///
/// 다른 패널과 마찬가지로 항상 붙어 있고 [isOpen] 으로만 열고 닫는다. 월드는
/// 공유된 실시간 공간이라 지도를 보는 동안에도 로봇은 다가온다.
class WorldMapScreen extends PositionComponent
    with TapCallbacks, HasGameReference<ActionRpgGame> {
  WorldMapScreen() : super(priority: 144);

  /// 기준 해상도에서의 패널 크기. 화면이 좁으면 통째로 축소한다.
  static const double panelWidth = 470;
  static const double panelHeight = 578;

  /// 지도가 놓이는 영역. 월드는 이 안에 비율을 지켜 들어간다.
  static const Rect mapArea =
      Rect.fromLTWH(20, 70, panelWidth - 40, panelWidth - 40);

  static const Rect _closeRect = Rect.fromLTWH(panelWidth - 46, 14, 32, 32);

  /// 지형 축소판 한 변의 픽셀 수.
  ///
  /// 1006 × 1006 칸을 매 프레임 훑을 수는 없다. 열 때 한 번만 이 크기로 구워
  /// 두고 그 다음부터는 이미지 한 장을 그린다.
  static const int _terrainSize = 256;

  /// 지도에 고리로 표시할 위험 등급과 그 색.
  ///
  /// 등급마다 고리를 그리면 시작 근처가 촘촘해 읽히지 않는다. 성장 단계가
  /// 뚜렷하게 갈리는 다섯 지점만 남긴다.
  static const List<({int level, Color color})> dangerBands = [
    (level: 200, color: Color(0xFFFF1F6B)),
    (level: 100, color: Color(0xFFD8203F)),
    (level: 50, color: Color(0xFFE86A1C)),
    (level: 25, color: Color(0xFFE0A400)),
    (level: 10, color: Color(0xFF16C98D)),
  ];

  bool _open = false;
  double _anim = 0;
  double _time = 0;

  /// 지형 축소판. 만들어지기 전에는 null 이다.
  ui.Image? _terrain;

  /// [_terrain] 을 어느 지형에서 구웠는지.
  ///
  /// 재시작하면 월드가 통째로 새로 생성되므로, 그때 구워 둔 그림을 계속 쓰면
  /// 지도만 옛 월드를 가리킨다.
  LevelMap? _terrainMap;

  /// 지도를 눌러 재 본 지점(그리드 좌표). 누르기 전에는 null.
  Vector2? _probe;

  bool get isOpen => _open;

  void open() {
    _open = true;
    _ensureTerrain();
  }

  void close() {
    _open = false;
    _probe = null;
  }

  void toggle() => _open ? close() : open();

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
      letterSpacing: 0.4,
    ),
  );
  final TextPaint _value = TextPaint(
    style: const TextStyle(
      color: GamePalette.textPrimary,
      fontSize: 13,
      fontWeight: FontWeight.w800,
    ),
  );
  final TextPaint _ringLabel = TextPaint(
    style: const TextStyle(
      color: GamePalette.textPrimary,
      fontSize: 9,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.3,
    ),
  );
  final TextPaint _legend = TextPaint(
    style: const TextStyle(
      color: GamePalette.textDim,
      fontSize: 10,
      fontWeight: FontWeight.w700,
    ),
  );

  // ── 지형 축소판 ─────────────────────────────────────────────────────

  /// 지금 월드의 지형 축소판을 준비한다. 이미 있으면 아무것도 하지 않는다.
  void _ensureTerrain() {
    final map = game.map;
    if (_terrain != null && identical(_terrainMap, map)) return;

    // 새 월드다. 옛 그림은 버린다.
    _terrain?.dispose();
    _terrain = null;
    _terrainMap = map;

    final pixels = Uint8List(_terrainSize * _terrainSize * 4);
    final stepX = map.width / _terrainSize;
    final stepY = map.height / _terrainSize;

    for (var py = 0; py < _terrainSize; py++) {
      final gy = (py * stepY).floor();
      for (var px = 0; px < _terrainSize; px++) {
        final gx = (px * stepX).floor();
        final color = _terrainColor(map, gx, gy);
        final i = (py * _terrainSize + px) * 4;
        pixels[i] = (color >> 16) & 0xFF;
        pixels[i + 1] = (color >> 8) & 0xFF;
        pixels[i + 2] = color & 0xFF;
        pixels[i + 3] = (color >> 24) & 0xFF;
      }
    }

    ui.decodeImageFromPixels(
      pixels,
      _terrainSize,
      _terrainSize,
      ui.PixelFormat.rgba8888,
      (image) {
        // 굽는 사이에 월드가 바뀌었으면(재시작) 이 그림은 이미 옛것이다.
        if (!identical(_terrainMap, game.map)) {
          image.dispose();
          return;
        }
        _terrain = image;
      },
    );
  }

  /// 축소판 한 점의 색(ARGB). 근접 레이더와 같은 색 규칙을 쓴다.
  static int _terrainColor(LevelMap map, int x, int y) {
    final tile = map.tileAt(x, y);
    if (tile == TileType.none) return 0x00000000;
    if (map.isBlocked(x, y)) return 0xFF6E9DB8;
    return switch (tile) {
      TileType.circuit || TileType.stream => 0xFF9DE8F5,
      TileType.hazard => 0xFFFFAFC8,
      _ => 0xFFDCEFF8,
    };
  }

  @override
  void onRemove() {
    _terrain?.dispose();
    _terrain = null;
    super.onRemove();
  }

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

  /// 지금 월드에 맞춘 환산기.
  WorldMapProjection get projection => WorldMapProjection.fit(
    area: mapArea,
    worldWidth: game.map.width.toDouble(),
    worldHeight: game.map.height.toDouble(),
  );

  /// 위험 등급 곡선의 기준이 되는 반경(타일).
  ///
  /// [MonsterPopulation.generate] 가 개체를 배치할 때 쓰는 값과 같아야 지도와
  /// 실제 주둔 병력이 맞는다.
  double get _halfSpan =>
      math.max(game.map.width, game.map.height) / 2;

  /// [grid] 지점의 구역 위험 등급.
  int _levelAt(Vector2 grid) => MonsterCodex.regionLevel(
    (grid - game.map.spawn).length,
    _halfSpan,
  );

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
      game.closeWorldMap();
      return;
    }

    // 지도를 누르면 그 지점의 위험도와 거리를 재 준다. 어디서 사냥할지 고르는
    // 것이 이 화면의 쓸모라, 눌러 보는 것이 가장 빠른 답이다.
    final view = projection;
    if (view.mapRect.contains(local)) _probe = view.toGrid(local);
  }

  // ── 갱신 ────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    _time += dt;
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

    // 한 프레임 안에서는 모두 같은 환산을 써야 표식들이 서로 어긋나지 않는다.
    final view = projection;

    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(view.mapRect, const Radius.circular(10)),
    );
    _renderTerrain(canvas, view);
    _renderDangerBands(canvas, view);
    _renderSafeZone(canvas, view);
    _renderTeleportMarks(canvas, view);
    _renderRemoteAgents(canvas, view);
    _renderProbe(canvas, view);
    _renderPlayerMark(canvas, view);
    canvas.restore();

    canvas.drawRRect(
      RRect.fromRectAndRadius(view.mapRect, const Radius.circular(10)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = GamePalette.hudBorder.withValues(alpha: 0.4),
    );

    _renderFooter(canvas);
  }

  void _renderHeader(Canvas canvas) {
    final player = game.player;
    final level = _levelAt(player.grid);

    _title.render(
      canvas,
      'WORLD MAP',
      Vector2(24, 30),
      anchor: Anchor.centerLeft,
    );
    _hint.render(
      canvas,
      '${game.map.playableWidthInMeters.round()} m 단일 월드',
      Vector2(126, 31),
      anchor: Anchor.centerLeft,
    );

    // 지금 선 자리의 좌표와 그 구역의 위험 등급. 지도를 열지 않고도 알아야 할
    // 값이지만, 적어도 여기서는 언제나 볼 수 있어야 한다.
    _value.render(
      canvas,
      '${player.grid.x.round()}, ${player.grid.y.round()}',
      Vector2(panelWidth - 56, 24),
      anchor: Anchor.centerRight,
    );
    _renderLevelChip(
      canvas,
      Offset(panelWidth - 56, 42),
      level,
      align: Anchor.centerRight,
    );

    canvas.drawLine(
      const Offset(24, 58),
      const Offset(panelWidth - 24, 58),
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

  void _renderTerrain(Canvas canvas, WorldMapProjection view) {
    final terrain = _terrain;
    canvas.drawRect(view.mapRect, Paint()..color = GamePalette.voidColor);
    if (terrain == null) {
      // 굽는 데는 한 프레임이면 된다. 그 한 프레임을 빈 칸으로 두지 않는다.
      _hint.render(
        canvas,
        '지형을 그리는 중',
        Vector2(view.mapRect.center.dx, view.mapRect.center.dy),
        anchor: Anchor.center,
      );
      return;
    }
    canvas.drawImageRect(
      terrain,
      Rect.fromLTWH(
        0,
        0,
        terrain.width.toDouble(),
        terrain.height.toDouble(),
      ),
      view.mapRect,
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  /// 시작 지점을 중심으로 퍼지는 위험 등급 고리.
  ///
  /// 바깥 고리부터 그려 안쪽이 위에 덮이므로, 눈에 보이는 색은 언제나 그 자리의
  /// 등급이다.
  void _renderDangerBands(Canvas canvas, WorldMapProjection view) {
    final center = view.toMap(game.map.spawn);
    final scale = view.tileScale;

    for (final band in dangerBands) {
      final radius =
          MonsterCodex.regionDistanceFor(band.level, _halfSpan) * scale;
      // 가장 바깥 등급은 지도 모서리까지 덮는다 — 고리 밖도 그 등급이다.
      if (band.level >= MonsterCodex.maxLevel) {
        canvas.drawRect(
          view.mapRect,
          Paint()..color = band.color.withValues(alpha: 0.13),
        );
        continue;
      }
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = band.color.withValues(alpha: 0.13),
      );
    }

    // 경계선과 등급 표기는 채움을 모두 얹은 뒤에 그린다.
    for (var i = 0; i < dangerBands.length; i++) {
      final band = dangerBands[i];
      if (band.level >= MonsterCodex.maxLevel) continue;
      final radius =
          MonsterCodex.regionDistanceFor(band.level, _halfSpan) * scale;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = band.color.withValues(alpha: 0.55),
      );

      // 표기를 모두 12시에 세우면 안쪽 고리들이 좁은 구간에 겹쳐 쌓인다.
      // 고리마다 다른 각도에 붙여 서로 비켜 가게 한다.
      final angle = -math.pi / 2 + i * 0.9;
      _ringLabel.render(
        canvas,
        'Lv.${band.level}',
        Vector2(
          center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius,
        ),
        anchor: Anchor.center,
      );
    }
  }

  void _renderSafeZone(Canvas canvas, WorldMapProjection view) {
    final zone = game.map.safeZone;
    final rect = Rect.fromPoints(
      view.toMap(Vector2(zone.minX, zone.minY)),
      view.toMap(Vector2(zone.maxX, zone.maxY)),
    );
    canvas.drawRect(
      rect,
      Paint()..color = GamePalette.safeZoneFill.withValues(alpha: 0.5),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = GamePalette.safeZoneEdge,
    );
  }

  /// 텔레포트로 갈 수 있는 곳. 어디로 뛸 수 있는지 지도에서 바로 보인다.
  void _renderTeleportMarks(Canvas canvas, WorldMapProjection view) {
    for (final destination in TeleportDestination.values) {
      if (destination.isSafe) continue; // 안전지대는 이미 초록 사각형이다.
      final point = view.toMap(destination.anchorOn(game.map));
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = GamePalette.hudBorder.withValues(alpha: 0.9);
      canvas.drawPath(
        Path()
          ..moveTo(point.dx, point.dy - 4)
          ..lineTo(point.dx + 4, point.dy)
          ..lineTo(point.dx, point.dy + 4)
          ..lineTo(point.dx - 4, point.dy)
          ..close(),
        paint,
      );
    }
  }

  /// 같은 월드에 접속해 있는 다른 요원들.
  void _renderRemoteAgents(Canvas canvas, WorldMapProjection view) {
    final paint = Paint()..color = GamePalette.playerAccent;
    final halo = Paint()
      ..color = GamePalette.playerAccent.withValues(alpha: 0.35);
    for (final agent in game.remotePlayers) {
      final point = view.toMap(agent.grid);
      canvas.drawCircle(point, 4, halo);
      canvas.drawCircle(point, 2, paint);
    }
  }

  void _renderProbe(Canvas canvas, WorldMapProjection view) {
    final probe = _probe;
    if (probe == null) return;
    final point = view.toMap(probe);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = GamePalette.textPrimary.withValues(alpha: 0.8);
    canvas.drawCircle(point, 7, paint);
    canvas.drawLine(
      Offset(point.dx - 11, point.dy),
      Offset(point.dx - 4, point.dy),
      paint,
    );
    canvas.drawLine(
      Offset(point.dx + 4, point.dy),
      Offset(point.dx + 11, point.dy),
      paint,
    );
  }

  /// 내가 선 자리. 지도에서 가장 먼저 눈에 들어와야 한다.
  void _renderPlayerMark(Canvas canvas, WorldMapProjection view) {
    final point = view.toMap(game.player.grid);
    final pulse = 0.5 + 0.5 * math.sin(_time * 3.4);

    canvas.drawCircle(
      point,
      7 + pulse * 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = GamePalette.hudBorder.withValues(alpha: 0.7 - pulse * 0.45),
    );
    canvas.drawCircle(
      point,
      4.5,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      point,
      3,
      Paint()..color = GamePalette.hudBorder,
    );
  }

  void _renderFooter(Canvas canvas) {
    // 지도가 좌우로 남는 여백을 만들 수 있으므로, 아래쪽 글은 지도가 아니라
    // 지도가 놓인 영역을 기준으로 줄을 맞춘다.
    final top = mapArea.bottom + 12.0;

    // 눌러 본 지점이 있으면 그 값을 먼저 알린다 — 방금 물어본 질문의 답이다.
    final probe = _probe;
    if (probe != null) {
      final distance = (probe - game.player.grid).length;
      _hint.render(
        canvas,
        '표시 지점',
        Vector2(24, top + 8),
        anchor: Anchor.centerLeft,
      );
      _renderLevelChip(canvas, Offset(84, top + 8), _levelAt(probe));
      _value.render(
        canvas,
        '여기서 ${distance.round()} m',
        Vector2(panelWidth - 24, top + 8),
        anchor: Anchor.centerRight,
      );
    } else {
      _hint.render(
        canvas,
        '지도를 누르면 그 지점의 위험도를 잰다',
        Vector2(24, top + 8),
        anchor: Anchor.centerLeft,
      );
    }

    // 위험 등급 색 범례. 고리 색이 무엇을 뜻하는지 여기서 읽는다.
    var x = 24.0;
    for (final band in dangerBands.reversed) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top + 26, 10, 10),
          const Radius.circular(2),
        ),
        Paint()..color = band.color.withValues(alpha: 0.75),
      );
      _legend.render(
        canvas,
        'Lv.${band.level}',
        Vector2(x + 14, top + 31),
        anchor: Anchor.centerLeft,
      );
      x += 62;
    }

    _legend.render(
      canvas,
      '◇ 텔레포트 목적지    ● 다른 요원 ${game.remotePlayers.length}명',
      Vector2(24, top + 50),
      anchor: Anchor.centerLeft,
    );
  }

  /// `Lv.42` 배지. 위험 등급 색으로 칠해 숫자와 색이 같은 뜻을 갖게 한다.
  void _renderLevelChip(
    Canvas canvas,
    Offset at,
    int level, {
    Anchor align = Anchor.centerLeft,
  }) {
    final color = bandColorFor(level);
    final text = 'Lv.$level';
    const width = 46.0;
    final left = align == Anchor.centerRight ? at.dx - width : at.dx;
    final rect = Rect.fromLTWH(left, at.dy - 8, width, 16);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = color.withValues(alpha: 0.18),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.7),
    );
    _ringLabel.render(
      canvas,
      text,
      Vector2(rect.center.dx, rect.center.dy),
      anchor: Anchor.center,
    );
  }

  /// [level] 이 속한 위험 등급 띠의 색.
  ///
  /// 지도의 고리와 HUD 의 위험도 표시가 같은 색을 써야, 걸어 다니며 본 색과
  /// 지도에서 고른 색이 같은 뜻을 갖는다.
  static Color bandColorFor(int level) {
    // 낮은 등급부터 훑어 처음으로 level 을 담는 띠가 그 자리의 색이다.
    for (final band in dangerBands.reversed) {
      if (level <= band.level) return band.color;
    }
    return dangerBands.first.color;
  }
}
