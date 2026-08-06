import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:provis/provis.dart'
    show GroundPatch, PathPatch, PebbleField, Prop, Rng, WaterProp;

import '../action_rpg_game.dart';
import '../iso.dart';
import '../palette.dart';
import '../visual/provis_bridge.dart';
import 'level_map.dart';

/// 청크 하나의 래스터화 결과.
class _GroundChunk {
  _GroundChunk(this.picture, this.hazardPath, this.bounds);

  final ui.Picture picture;

  /// 청크 안 방화벽 구역 전체를 합친 경로. 없으면 null.
  final Path? hazardPath;

  /// 청크가 화면에서 차지하는 영역(월드 좌표).
  final Rect bounds;

  /// 마지막으로 화면에 쓰인 시각. 캐시 방출 판단에 쓴다.
  double lastUsed = 0;

  void dispose() => picture.dispose();
}

/// 1 km × 1 km 데이터 공간의 바닥을 그리는 레이어.
///
/// 100만 칸을 한 장으로 래스터화할 수 없으므로 월드를 [kChunkTiles] 격자로
/// 나누고, 카메라에 들어온 청크만 [ui.Picture]로 구워 캐시한다.
/// 맥동하는 방화벽 발광만 매 프레임 덧그린다.
class GroundLayer extends PositionComponent
    with HasGameReference<ActionRpgGame> {
  GroundLayer(this.map) : super(priority: -100000);

  final LevelMap map;

  final Map<int, _GroundChunk> _cache = {};
  final List<int> _visibleKeys = [];

  double _time = 0;

  /// 캐시에 유지할 최대 청크 수. 화면에 필요한 양의 몇 배로 넉넉히 잡는다.
  static const int _maxCachedChunks = 96;

  /// 프레임당 새로 구울 수 있는 청크 수. 이동 중 프레임 스파이크를 막는다.
  static const int _chunkBudgetPerFrame = 3;

  /// 지면 얼룩을 생성하는 격자 한 변의 타일 수.
  ///
  /// 얼룩이 타일 경계와 무관하게 번져야 지면이 장판을 벗어난다. 그렇다고
  /// 청크마다 독립적으로 뿌리면 32타일 주기가 눈에 보이므로, 청크보다 작은
  /// **월드 고정 격자**를 따로 두고 칸마다 하나씩 심는다. [kChunkTiles] 의
  /// 약수라서 얼룩 칸이 청크 경계를 가로지르지 않는다 — 한 얼룩을 두 청크가
  /// 나눠 그려 겹친 부분만 진해지는 일이 생기지 않는다.
  static const int _stainCellTiles = 8;

  /// 얼룩 하나가 칸 밖으로 번질 수 있는 최대 거리(px).
  ///
  /// 구운 [ui.Picture] 의 cullRect 를 이만큼 넓혀 두어야 청크 가장자리의
  /// 얼룩이 잘리지 않는다.
  static const double _stainBleed = 560;

  @override
  void onRemove() {
    for (final chunk in _cache.values) {
      chunk.dispose();
    }
    _cache.clear();
    super.onRemove();
  }

  @override
  void update(double dt) {
    _time += dt;
    _refreshVisibleChunks();
  }

  /// 카메라가 보는 영역을 청크 목록으로 바꾸고 필요한 만큼 새로 굽는다.
  void _refreshVisibleChunks() {
    _visibleKeys.clear();

    final view = game.visibleGridBounds(margin: 2);
    final minCx = (view.left / kChunkTiles).floor().clamp(0, map.chunksX - 1);
    final maxCx = (view.right / kChunkTiles).ceil().clamp(0, map.chunksX - 1);
    final minCy = (view.top / kChunkTiles).floor().clamp(0, map.chunksY - 1);
    final maxCy = (view.bottom / kChunkTiles).ceil().clamp(0, map.chunksY - 1);

    var budget = _chunkBudgetPerFrame;
    for (var cy = minCy; cy <= maxCy; cy++) {
      for (var cx = minCx; cx <= maxCx; cx++) {
        final key = cy * map.chunksX + cx;
        var chunk = _cache[key];
        if (chunk == null) {
          if (budget <= 0) continue;
          budget--;
          chunk = _bakeChunk(cx, cy);
          _cache[key] = chunk;
        }
        chunk.lastUsed = _time;
        _visibleKeys.add(key);
      }
    }

    _evictStaleChunks();
  }

  /// 오래 쓰이지 않은 청크부터 캐시에서 버린다.
  void _evictStaleChunks() {
    if (_cache.length <= _maxCachedChunks) return;
    final entries = _cache.entries.toList()
      ..sort((a, b) => a.value.lastUsed.compareTo(b.value.lastUsed));
    final excess = _cache.length - _maxCachedChunks;
    for (var i = 0; i < excess; i++) {
      final entry = entries[i];
      if (entry.value.lastUsed == _time) break; // 이번 프레임에 쓰이는 건 남긴다.
      entry.value.dispose();
      _cache.remove(entry.key);
    }
  }

  // ── 청크 래스터화 ────────────────────────────────────────────────────

  /// 타일 하나의 다이아몬드 외곽 경로 좌표.
  static List<Offset> _diamond(int gx, int gy, [double inset = 0]) {
    final x = gx.toDouble();
    final y = gy.toDouble();
    final top = gridToScreen(x + inset, y + inset);
    final right = gridToScreen(x + 1 - inset, y + inset);
    final bottom = gridToScreen(x + 1 - inset, y + 1 - inset);
    final left = gridToScreen(x + inset, y + 1 - inset);
    return [
      top.toOffset(),
      right.toOffset(),
      bottom.toOffset(),
      left.toOffset(),
    ];
  }

  /// 청크가 화면에서 차지하는 사각 영역을 구한다.
  Rect _chunkBounds(int cx, int cy) {
    final x0 = cx * kChunkTiles;
    final y0 = cy * kChunkTiles;
    final x1 = x0 + kChunkTiles;
    final y1 = y0 + kChunkTiles;
    final corners = [
      gridToScreen(x0.toDouble(), y0.toDouble()),
      gridToScreen(x1.toDouble(), y0.toDouble()),
      gridToScreen(x1.toDouble(), y1.toDouble()),
      gridToScreen(x0.toDouble(), y1.toDouble()),
    ];
    var left = corners.first.x;
    var right = corners.first.x;
    var top = corners.first.y;
    var bottom = corners.first.y;
    for (final c in corners) {
      left = math.min(left, c.x);
      right = math.max(right, c.x);
      top = math.min(top, c.y);
      bottom = math.max(bottom, c.y);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  _GroundChunk _bakeChunk(int cx, int cy) {
    final bounds = _chunkBounds(cx, cy);
    final recorder = ui.PictureRecorder();
    // 얼룩이 칸 밖으로 번지므로 cullRect 를 그만큼 넓힌다. cullRect 는 힌트일
    // 뿐 메모리를 미리 잡지 않으므로 넉넉히 주어도 비용이 없다.
    final canvas = Canvas(recorder, bounds.inflate(_stainBleed));

    final startX = cx * kChunkTiles;
    final startY = cy * kChunkTiles;
    final endX = math.min(startX + kChunkTiles, map.width);
    final endY = math.min(startY + kChunkTiles, map.height);

    // 같은 색끼리 경로를 합쳐 그리기 호출 수를 타입 수준으로 줄인다.
    final plateEven = Path();
    final plateOdd = Path();
    final conduit = Path();
    final stream = Path();
    final hazard = Path();
    var hasHazard = false;

    for (var y = startY; y < endY; y++) {
      for (var x = startX; x < endX; x++) {
        final type = map.tileAt(x, y);
        if (type == TileType.none) continue;
        final poly = _diamond(x, y);
        switch (type) {
          case TileType.floor:
            ((x + y).isEven ? plateEven : plateOdd).addPolygon(poly, true);
          case TileType.circuit:
            conduit.addPolygon(poly, true);
          case TileType.stream:
            stream.addPolygon(poly, true);
          case TileType.hazard:
            hazard.addPolygon(poly, true);
            hasHazard = true;
          case TileType.none:
            break;
        }
      }
    }

    final fill = Paint()..style = PaintingStyle.fill;
    canvas.drawPath(plateEven, fill..color = GamePalette.floorBase);
    canvas.drawPath(plateOdd, fill..color = GamePalette.floorAlt);
    canvas.drawPath(conduit, fill..color = GamePalette.floorCircuit);
    canvas.drawPath(stream, fill..color = GamePalette.floorStream);
    canvas.drawPath(hazard, fill..color = GamePalette.floorHazard);

    // 단면은 공백과 맞닿은 변에서 **아래로** 떨어지므로 플레이트와 겹치지
    // 않는다. 얼룩은 그 위에 얹혀 플레이트 안쪽만 물들인다.
    _drawPlatformSkirt(canvas, startX, startY, endX, endY);
    _drawPlateStains(canvas, startX, startY, endX, endY);
    _drawGroundProps(canvas, startX, startY, endX, endY);
    _drawTileGrid(canvas, startX, startY, endX, endY);
    _drawConduitTraces(canvas, startX, startY, endX, endY);
    _drawPlatformRim(canvas, startX, startY, endX, endY);

    return _GroundChunk(
      recorder.endRecording(),
      hasHazard ? hazard : null,
      bounds,
    );
  }

  /// 플레이트 표면의 명도 얼룩.
  ///
  /// 타일마다 색을 번갈아 칠하면 지면은 **장판**이 된다 — 무늬가 타일 격자에
  /// 묶여 있어 눈이 그것을 바닥이 아니라 무늬로 읽기 때문이다. 타일 경계와
  /// 무관하게 번지는 얼룩이 한 겹 있어야 비로소 표면이 생긴다.
  ///
  /// 세계관상 이것은 흙이 아니라 **연산 부하가 남긴 자국**이므로, 팔레트 안의
  /// 인접한 톤 사이에서만 흔든다.
  ///
  /// 번짐은 `MaskFilter.blur` 가 아니라 **방사형 그라디언트**로 만든다. 블러는
  /// 오프스크린 패스를 요구해 청크를 다시 래스터화할 때마다 값을 치르지만,
  /// 그라디언트는 셰이더 fill 이라 그 비용이 없다. 지면은 화면의 대부분을
  /// 덮으므로 이 차이가 프레임에 그대로 나타난다.
  void _drawPlateStains(
    Canvas canvas,
    int startX,
    int startY,
    int endX,
    int endY,
  ) {
    final paint = Paint()..isAntiAlias = true;

    for (var cellY = startY; cellY < endY; cellY += _stainCellTiles) {
      for (var cellX = startX; cellX < endX; cellX += _stainCellTiles) {
        // 시드를 **월드 좌표**에서 뽑는다. 청크 인덱스로 뽑으면 청크마다 같은
        // 무늬가 되풀이되어 32타일 주기가 드러난다.
        final r = ProvisBridge.groundRng(map.seed, cellX, cellY);
        if (!_cellHasFloor(cellX, cellY)) continue;

        // 큰 얼룩 하나 — 구역의 성격을 만든다.
        if (r.chance(0.85)) {
          _drawStain(
            canvas,
            paint,
            r,
            cellX,
            cellY,
            radius: r.range(240, 520),
            alpha: r.range(0.20, 0.38),
          );
        }
        // 작은 얼룩 셋 — 큰 얼룩만 있으면 해상도가 한 겹뿐이라 여전히 밋밋하다.
        for (var i = 0; i < 3; i++) {
          _drawStain(
            canvas,
            paint,
            r,
            cellX,
            cellY,
            radius: r.range(60, 170),
            alpha: r.range(0.15, 0.28),
          );
        }
      }
    }
  }

  /// 얼룩 칸 안에 바닥이 하나라도 있는지. 공백 위에는 얼룩을 뿌리지 않는다.
  bool _cellHasFloor(int cellX, int cellY) {
    for (var y = cellY; y < cellY + _stainCellTiles; y++) {
      for (var x = cellX; x < cellX + _stainCellTiles; x++) {
        if (map.tileAt(x, y) != TileType.none) return true;
      }
    }
    return false;
  }

  /// 얼룩 하나. 아이소 평면에 눕도록 가로로 두 배 넓은 타원이다.
  void _drawStain(
    Canvas canvas,
    Paint paint,
    Rng r,
    int cellX,
    int cellY, {
    required double radius,
    required double alpha,
  }) {
    final gx = cellX + r.range(0, _stainCellTiles.toDouble());
    final gy = cellY + r.range(0, _stainCellTiles.toDouble());
    final center = gridToScreen(gx, gy).toOffset();
    final tone = ProvisBridge.plateStain(r);

    // 세로를 절반으로 눌러야 바닥에 누운 것으로 읽힌다. 원 그대로 두면
    // 공중에 뜬 구체처럼 보인다.
    final rect = Rect.fromCenter(
      center: center,
      width: radius * 2,
      height: radius,
    );

    // 중심에서 곧바로 투명해지면 실제로 칠해지는 면적이 거의 없어, 값은
    // 치르면서 눈에는 아무것도 남지 않는다. 절반 지점까지 농도를 끌고 가야
    // 얼룩이 "번진 자국"으로 읽힌다.
    paint.shader = ui.Gradient.radial(
      center,
      radius,
      [
        tone.withValues(alpha: alpha),
        tone.withValues(alpha: alpha * 0.72),
        tone.withValues(alpha: 0),
      ],
      const [0.0, 0.52, 1.0],
      TileMode.clamp,
      _flattenAround(center.dy),
    );
    canvas.drawOval(rect, paint);
    paint.shader = null;
  }

  /// 지면에 눕는 provis 기물을 청크에 구워 넣는다.
  ///
  /// 여기 오는 것은 전부 `grounded == true` 인 기물뿐이다 — 지면 평면에 눕기
  /// 때문에 깊이 정렬에 참여할 필요가 없고, 그래서 이 레이어의
  /// `priority: -100000` 아래 구워도 가림이 틀리지 않는다. 나무·바위처럼
  /// **세워지는** 기물은 여기 넣으면 안 된다. 그것들은 액터보다 항상 뒤에
  /// 고정되어 플레이어가 영영 뒤로 돌아갈 수 없게 된다.
  ///
  /// ⚠️ `paintProp` 을 쓰지 않고 `prop.paint()` 를 직접 부른다. `paintProp` 은
  /// 첫 줄에서 `iso.project(tile)` 로 앵커를 잡는데, 여기 캔버스는 이미
  /// [gridToScreen] 으로 옮겨 놓은 자리라서 좌표가 두 번 더해진다.
  void _drawGroundProps(
    Canvas canvas,
    int startX,
    int startY,
    int endX,
    int endY,
  ) {
    for (var cellY = startY; cellY < endY; cellY += _stainCellTiles) {
      for (var cellX = startX; cellX < endX; cellX += _stainCellTiles) {
        final r = ProvisBridge.groundRng(map.seed ^ 0x5EED, cellX, cellY);
        if (r.chance(0.55)) continue;

        final gx = cellX + r.range(1, _stainCellTiles - 1.0);
        final gy = cellY + r.range(1, _stainCellTiles - 1.0);
        final tx = gx.floor();
        final ty = gy.floor();
        final type = map.tileAt(tx, ty);
        if (type == TileType.none) continue;

        final prop = _groundPropFor(type, r);
        if (prop == null) continue;

        final at = gridToScreen(gx, gy).toOffset();
        canvas.save();
        canvas.translate(at.dx, at.dy);
        // 눕는 기물은 지면 평면에 맞춰 세로를 절반으로 누른다.
        // `paintProp` 이 `iso.shadowRatio` 로 하는 일과 같다.
        canvas.scale(1, ProvisBridge.iso.shadowRatio);
        prop.paint(canvas, 0, ProvisBridge.light);
        canvas.restore();
      }
    }
  }

  /// 타일 종류에 어울리는 지면 기물을 고른다.
  ///
  /// 판타지 기본값을 그대로 쓰지 않는다 — `GroundPatch` 는 풀잎을 끄고
  /// (`blades: 0`) 청록 계열로, `WaterProp` 은 갈대를 끄고(`reeds: false`)
  /// 얕은 데이터 풀로 재해석한다. 색을 넘기지 않으면 provis 가 잔디 녹색과
  /// 연못 파랑을 뽑아 세계관이 무너진다.
  Prop? _groundPropFor(TileType type, Rng r) {
    switch (type) {
      case TileType.circuit:
        // 도관 대로에는 통행이 닳은 흔적. 기본 tileWidth 는 156 이므로
        // 반드시 이 월드의 128 로 맞춘다.
        return PathPatch(
          seed: r.intRange(0, 1 << 30),
          tileWidth: kTileWidth,
          color: GamePalette.floorCircuitGlow.withValues(alpha: 0.30),
        );
      case TileType.stream:
        // 연산 대역은 이미 발광하므로 얼룩만 옅게 얹는다.
        return GroundPatch(
          seed: r.intRange(0, 1 << 30),
          radius: r.range(70, 130),
          blades: 0,
          color: GamePalette.floorStreamGlow.withValues(alpha: 0.22),
        );
      case TileType.floor:
        if (r.chance(0.34)) {
          // 붕괴한 노드의 파편.
          return PebbleField(
            seed: r.intRange(0, 1 << 30),
            radius: r.range(48, 84),
            count: r.intRange(5, 11),
            color: GamePalette.wallLeft,
          );
        }
        if (r.chance(0.18)) {
          // 액체화된 데이터가 고인 웅덩이. 얕아서 지나갈 수 있고,
          // 통행 판정은 어차피 LevelMap 만 본다.
          return WaterProp(
            seed: r.intRange(0, 1 << 30),
            radius: r.range(80, 150),
            shallow: true,
            reeds: false,
            color: GamePalette.horizonGlow.withValues(alpha: 0.34),
          );
        }
        return GroundPatch(
          seed: r.intRange(0, 1 << 30),
          radius: r.range(80, 160),
          blades: 0,
          color: GamePalette.floorCircuit.withValues(alpha: 0.5),
        );
      case TileType.hazard:
      case TileType.none:
        // 방화벽 구역은 자체 발광이 강해 장식이 묻힌다.
        return null;
    }
  }

  /// [centerY] 를 기준으로 세로만 절반으로 누르는 4×4 변환.
  ///
  /// 방사형 그라디언트를 타원에 맞춰 눕히는 데 쓴다. `Matrix4` 를 쓰지 않는
  /// 것은 Flame 과 Flutter 가 서로 다른 `vector_math` 를 들여와 이름이
  /// 충돌하기 때문이다 — 열 우선 4×4 를 직접 적는 편이 분명하다.
  static Float64List _flattenAround(double centerY) => Float64List.fromList([
        1, 0, 0, 0, //
        0, 0.5, 0, 0, //
        0, 0, 1, 0, //
        0, centerY * 0.5, 0, 1, //
      ]);

  /// 플레이트의 잘린 단면.
  ///
  /// 데이터 공백과 맞닿은 변에서 지면이 그냥 끊기면 종이가 잘린 것으로 보인다.
  /// 아래로 떨어지는 벽이 한 겹 있으면 **두께를 가진 부유 플레이트**가 된다.
  /// 흙 지층 대신 회로 기판의 적층 단면으로 그린다.
  ///
  /// 화면상 아래를 향하는 두 변(동쪽·남쪽)에만 붙인다. 북쪽·서쪽 변의 단면은
  /// 그 타일 자신에게 가려 보이지 않는다.
  void _drawPlatformSkirt(
    Canvas canvas,
    int startX,
    int startY,
    int endX,
    int endY,
  ) {
    final wall = Path();
    for (var y = startY; y < endY; y++) {
      for (var x = startX; x < endX; x++) {
        if (map.tileAt(x, y) == TileType.none) continue;
        final poly = _diamond(x, y);
        // 꼭짓점: 0=북, 1=동, 2=남, 3=서.
        if (map.tileAt(x + 1, y) == TileType.none) {
          _addSkirtQuad(wall, poly[1], poly[2]);
        }
        if (map.tileAt(x, y + 1) == TileType.none) {
          _addSkirtQuad(wall, poly[2], poly[3]);
        }
      }
    }
    if (wall.getBounds().isEmpty) return;

    final b = wall.getBounds();
    canvas.drawPath(
      wall,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.linear(
          Offset(b.center.dx, b.top),
          Offset(b.center.dx, b.bottom),
          [
            GamePalette.wallLeft,
            GamePalette.wallLeft.withValues(alpha: 0.65),
            GamePalette.voidColor.withValues(alpha: 0),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );

    // 적층 사이의 회로 띠. 단면이 단색 벽이 아니라 기판으로 읽히게 한다.
    canvas.drawPath(
      wall,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.linear(
          Offset(b.center.dx, b.top),
          Offset(b.center.dx, b.bottom),
          [
            GamePalette.floorCircuitGlow.withValues(alpha: 0.28),
            GamePalette.floorCircuitGlow.withValues(alpha: 0),
          ],
          const [0.0, 0.34],
        ),
    );
  }

  /// 경계 변 하나에 아래로 떨어지는 사각 벽을 붙인다.
  static void _addSkirtQuad(Path wall, Offset a, Offset b) {
    wall
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(b.dx, b.dy + _skirtDepth)
      ..lineTo(a.dx, a.dy + _skirtDepth)
      ..close();
  }

  /// 단면의 깊이(px). 타일 세로폭의 절반을 조금 넘겨야 두께가 읽힌다.
  static const double _skirtDepth = 38;

  /// 데이터 플레이트의 이음새 격자.
  ///
  /// 칸마다 마름모를 그리는 대신 청크를 가로지르는 대각선 두 벌로 처리한다.
  void _drawTileGrid(Canvas canvas, int startX, int startY, int endX, int endY) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      // 격자는 이 세계의 이음새이므로 지우지 않는다. 다만 선이 진하면 눈이
      // 지면을 "무늬"로 읽어 그 위에 깔린 얼룩이 통째로 묻힌다 — 격자가
      // 주인공이 아니라 이음새로 물러나는 만큼만 남긴다.
      ..color = GamePalette.floorGrid.withValues(alpha: 0.30);

    for (var x = startX; x <= endX; x++) {
      final a = gridToScreen(x.toDouble(), startY.toDouble());
      final b = gridToScreen(x.toDouble(), endY.toDouble());
      canvas.drawLine(a.toOffset(), b.toOffset(), line);
    }
    for (var y = startY; y <= endY; y++) {
      final a = gridToScreen(startX.toDouble(), y.toDouble());
      final b = gridToScreen(endX.toDouble(), y.toDouble());
      canvas.drawLine(a.toOffset(), b.toOffset(), line);
    }
  }

  /// 도관·스트림 위를 흐르는 발광 배선.
  void _drawConduitTraces(
    Canvas canvas,
    int startX,
    int startY,
    int endX,
    int endY,
  ) {
    final conduitTrace = Path();
    final streamTrace = Path();
    final node = Path();

    for (var y = startY; y < endY; y++) {
      for (var x = startX; x < endX; x++) {
        final type = map.tileAt(x, y);
        if (type != TileType.circuit && type != TileType.stream) continue;

        // 배선은 통로가 이어지는 방향을 따라간다.
        final alongX = map.tileAt(x - 1, y) == type ||
            map.tileAt(x + 1, y) == type;
        final alongY = map.tileAt(x, y - 1) == type ||
            map.tileAt(x, y + 1) == type;
        final target = type == TileType.circuit ? conduitTrace : streamTrace;

        if (alongX) {
          final a = gridToScreen(x.toDouble(), y + 0.5);
          final b = gridToScreen(x + 1.0, y + 0.5);
          target
            ..moveTo(a.x, a.y)
            ..lineTo(b.x, b.y);
        }
        if (alongY) {
          final a = gridToScreen(x + 0.5, y.toDouble());
          final b = gridToScreen(x + 0.5, y + 1.0);
          target
            ..moveTo(a.x, a.y)
            ..lineTo(b.x, b.y);
        }
        // 교차점에는 접속 노드를 찍는다.
        if (alongX && alongY && (x + y) % 8 == 0) {
          final c = gridToScreen(x + 0.5, y + 0.5);
          node.addOval(Rect.fromCircle(center: c.toOffset(), radius: 3));
        }
      }
    }

    final trace = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(
      conduitTrace,
      trace..color = GamePalette.floorCircuitGlow.withValues(alpha: 0.55),
    );
    canvas.drawPath(
      streamTrace,
      trace
        ..strokeWidth = 2.6
        ..color = GamePalette.floorStreamGlow.withValues(alpha: 0.5),
    );
    canvas.drawPath(
      node,
      Paint()..color = GamePalette.floorCircuitGlow.withValues(alpha: 0.85),
    );
  }

  /// 데이터 공백과 맞닿은 가장자리에 발광 테두리를 둘러 부유감을 만든다.
  void _drawPlatformRim(
    Canvas canvas,
    int startX,
    int startY,
    int endX,
    int endY,
  ) {
    final rim = Path();
    for (var y = startY; y < endY; y++) {
      for (var x = startX; x < endX; x++) {
        if (map.tileAt(x, y) == TileType.none) continue;
        final poly = _diamond(x, y);
        // 마름모 꼭짓점: 0=북(-x-y), 1=동(+x), 2=남(+x+y), 3=서(+y)
        if (map.tileAt(x, y - 1) == TileType.none) {
          rim
            ..moveTo(poly[0].dx, poly[0].dy)
            ..lineTo(poly[1].dx, poly[1].dy);
        }
        if (map.tileAt(x + 1, y) == TileType.none) {
          rim
            ..moveTo(poly[1].dx, poly[1].dy)
            ..lineTo(poly[2].dx, poly[2].dy);
        }
        if (map.tileAt(x, y + 1) == TileType.none) {
          rim
            ..moveTo(poly[2].dx, poly[2].dy)
            ..lineTo(poly[3].dx, poly[3].dy);
        }
        if (map.tileAt(x - 1, y) == TileType.none) {
          rim
            ..moveTo(poly[3].dx, poly[3].dy)
            ..lineTo(poly[0].dx, poly[0].dy);
        }
      }
    }

    canvas.drawPath(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = GamePalette.horizonGlow.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = GamePalette.floorCircuitGlow.withValues(alpha: 0.9),
    );
  }

  // ── 렌더 ────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    for (final key in _visibleKeys) {
      final chunk = _cache[key];
      if (chunk != null) canvas.drawPicture(chunk.picture);
    }

    _drawDistanceFalloff(canvas);

    // 방화벽 구역의 맥동 발광.
    final pulse = 0.35 + 0.25 * math.sin(_time * 2.4);
    final glow = Paint()
      ..color = GamePalette.floorHazardGlow.withValues(alpha: pulse * 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = GamePalette.floorHazardGlow.withValues(alpha: pulse);

    for (final key in _visibleKeys) {
      final path = _cache[key]?.hazardPath;
      if (path == null) continue;
      canvas.drawPath(path, glow);
      canvas.drawPath(path, rim);
    }
  }

  /// 먼 쪽 지면을 환경광으로 미는 한 겹.
  ///
  /// 평면에 깊이를 주는 가장 값싼 방법이다. 화면 위쪽이 곧 월드에서 먼 쪽이고,
  /// 그쪽이 옅어지면 눈은 그것을 거리로 읽는다.
  ///
  /// ⚠️ provis 의 `paintIsoHaze` 를 여기에 쓰지 않는다. 그 함수는 **씬 전체**를
  /// 덮는 대기 원근이고, 이 레이어는 `priority: -100000` 이라 모든 액터
  /// **아래**에 있다. 여기에 전면 haze 를 칠하면 캐릭터는 하나도 흐려지지 않고
  /// 지면만 뿌예져 오히려 인물이 배경에서 떠 보인다. 그래서 **지면 전용**으로
  /// 약하게만 건다.
  void _drawDistanceFalloff(Canvas canvas) {
    final view = game.camera.visibleWorldRect;
    if (view.isEmpty) return;

    canvas.drawRect(
      view,
      Paint()
        ..shader = ui.Gradient.linear(
          view.topCenter,
          view.bottomCenter,
          [
            GamePalette.skyLow.withValues(alpha: 0.16),
            GamePalette.skyLow.withValues(alpha: 0.05),
            GamePalette.skyLow.withValues(alpha: 0),
          ],
          const [0.0, 0.38, 0.72],
        ),
    );
  }
}
