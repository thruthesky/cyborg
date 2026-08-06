import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:provis/provis.dart'
    show MoundProp, Prop, RockProp, Rng, TreeKind, TreeProp;

import '../entities/iso_entity.dart';
import '../iso.dart';
import '../palette.dart';
import '../visual/provis_bridge.dart';

/// 월드에 세워지는 절차 기물의 종류.
///
/// 판타지 자연물을 그대로 들여오지 않는다. 형상이 이미 중립이거나 사이버로
/// 읽히는 것만 고른다 — 둥근 수관을 가진 활엽수는 색을 어떻게 칠해도 나무이지만,
/// 잎이 없는 고사목은 가지 실루엣뿐이라 무너진 신호탑이 된다.
enum ProvisPropKind {
  /// 지면에서 솟은 데이터 결정.
  shard,

  /// 융기한 데이터 지층. 1 km 평면에 높이를 준다.
  ridge,

  /// 붕괴한 신호탑. `TreeKind.dead` 는 잎이 없어 캐노피가 생기지 않는다.
  mast,
}

/// 맵 위 한 자리를 차지하는 기물 정보.
///
/// [BlockSpec] 과 나란한 자리이며, 다른 점은 **통행을 막지 않는다**는 것이다.
/// 서버는 이 기물들을 전혀 모르므로 통행 판정에 끼워 넣으면 클라이언트끼리
/// 서로 다른 벽을 갖게 된다.
@immutable
class ProvisPropSpec {
  const ProvisPropSpec({
    required this.gx,
    required this.gy,
    required this.kind,
    required this.seed,
    required this.scale,
  });

  final double gx;
  final double gy;
  final ProvisPropKind kind;
  final int seed;

  /// 개체별 크기 변주. 같은 종이 전부 같은 크기면 복제로 보인다.
  final double scale;
}

/// provis 기물 하나를 게임의 깊이 축에 세운다.
///
/// **왜 `paintProp` 을 쓰지 않는가** — provis 의 `paintProp` 은 첫 줄에서
/// `iso.project(instance.tile)` 로 앵커를 잡고 캔버스를 그만큼 옮긴다. 그런데
/// [IsoEntity] 는 이미 `position = gridToScreen(grid)` 로 화면 좌표가 잡힌
/// 컴포넌트다. 월드 타일을 그대로 넘기면 좌표가 **두 번** 더해져 기물이 맵
/// 반대편에 나타난다. 그래서 `prop.paint()` 를 로컬 좌표에서 직접 부르고,
/// 세로 단축만 여기서 건다.
class ProvisPropComponent extends IsoEntity {
  ProvisPropComponent(this.spec)
      : _prop = _build(spec),
        super(
          grid: Vector2(spec.gx, spec.gy),
          // 통행을 막지 않으므로 충돌 반경은 의미가 없다. 0 으로 두어
          // 다른 계산에 끼어들지 않게 한다.
          bodyRadius: 0,
          depthBias: -0.02,
        );

  final ProvisPropSpec spec;
  final Prop _prop;

  double _time = 0;

  /// 기물이 눕는가. 눕는 것은 지면 평면(세로 절반), 서는 것은 카드(세로 0.866).
  bool get _isGrounded => _prop.grounded;

  @override
  void update(double dt) {
    // 바람 위상만 흘린다. 위치는 고정이므로 좌표 갱신은 마운트 때 한 번이면
    // 충분하지만, IsoEntity 의 계약을 깨지 않도록 super 를 그대로 부른다.
    _time += dt;
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.scale(
      spec.scale,
      spec.scale *
          (_isGrounded
              ? ProvisBridge.iso.shadowRatio
              : ProvisBridge.iso.squash),
    );

    // ⚠️ provis 의 `propShadow` 는 그림자 색을 `0xFF05070E`(거의 검정)로 **박아**
    // 두었다(`props/prop.dart:159`). 어두운 야외를 전제한 값이라 흰빛 데이터
    // 플레이트 위에서는 다소 무겁다.
    //
    // 레이어를 씌워 색을 미는 우회는 쓰지 않는다 — 그림자만 골라 밝힐 수 없어
    // 신호탑의 짙은 줄기까지 함께 지워지고, 액터마다 `saveLayer` 가 하나씩
    // 붙는다. 대신 기물 크기를 사람 기준으로 낮춰 그림자도 같이 줄였다.
    _prop.paint(canvas, _time, ProvisBridge.light);

    // 잎 없는 가지만으로는 "죽은 나무"에서 멈춘다. 가지 끝에 신호등이 깜박여야
    // 비로소 무너진 중계탑으로 읽힌다 — 형상은 provis 에서 빌리고 정체성은
    // 이쪽에서 붙이는 것이 이 게임이 판타지 기물을 쓰는 방식이다.
    if (spec.kind == ProvisPropKind.mast) _paintBeacons(canvas);

    canvas.restore();
  }

  /// 신호탑 가지 끝의 명멸 표지등.
  void _paintBeacons(Canvas canvas) {
    final r = Rng(spec.seed ^ 0xBEAC0);
    final top = -_prop.height;
    for (var i = 0; i < 3; i++) {
      // 위쪽 가지가 뻗은 대역에만 얹는다. 밑동에 등이 붙으면 나무가 아니라
      // 가로등이 된다.
      final at = Offset(
        r.range(-0.34, 0.34) * _prop.height,
        top * r.range(0.62, 0.94),
      );
      // 개체마다 위상이 달라야 숲 전체가 한 박자로 깜박이지 않는다.
      final pulse =
          0.45 + 0.55 * (0.5 + 0.5 * math.sin(_time * 2.2 + i * 2.1 + spec.gx));
      canvas.drawCircle(
        at,
        2.6,
        Paint()
          ..color = GamePalette.horizonGlow.withValues(alpha: 0.85 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
        at,
        1.1,
        Paint()..color = GamePalette.skyHigh.withValues(alpha: pulse),
      );
    }
  }

  static Prop _build(ProvisPropSpec spec) {
    final r = Rng(spec.seed);
    return switch (spec.kind) {
      // 크기는 사람(키 108px)을 기준으로 잡는다. `RockProp` 은 내부에서
      // `size` 에 최대 1.35배를 곱하고 파편이 더 벌어지므로, 사람 허리쯤에
      // 오게 하려면 40 안팎이어야 한다. 이것을 80 으로 두면 결정 하나가
      // 사람 셋을 가려 전투가 안 보인다.
      ProvisPropKind.shard => RockProp(
          seed: spec.seed,
          size: r.range(28, 48),
          // 이끼 낀 바위가 아니라 깎인 결정이다.
          mossy: false,
          shards: r.intRange(2, 5),
          color: GamePalette.wallLeft,
        ),
      ProvisPropKind.ridge => MoundProp(
          seed: spec.seed,
          radius: r.range(68, 108),
          rise: r.range(16, 26),
          // 지면과 평행한 면이 격자와 어긋나면 기물이 공중에 뜬 것처럼 보인다.
          isoRatio: ProvisBridge.iso.elevationSin,
          // 밟고 지나갈 수 있어야 한다. 통행은 LevelMap 만 정하므로,
          // 넘어갈 수 없어 보이는 언덕은 곧 관통해 보이는 언덕이 된다.
          walkOver: true,
          tufts: 0,
          grassColor: GamePalette.floorCircuit,
          soilColor: GamePalette.wallLeft,
        ),
      // 월드 중앙의 [WorldTree] 가 236px 이다. 잡다한 신호탑이 그와 비슷하면
      // 이정표가 이정표로 보이지 않는다 — 확실히 낮춰 둔다.
      ProvisPropKind.mast => TreeProp(
          seed: spec.seed,
          kind: TreeKind.dead,
          trunkHeight: r.range(115, 165),
          barkColor: GamePalette.playerArmor,
          canopyColor: GamePalette.horizonGlow,
          // 전산망 안에는 바람이 없다. 흔들리면 그 순간 나무가 된다.
          wind: 0,
        ),
    };
  }
}

/// 월드 좌표에서 결정론적으로 기물을 뽑는다.
///
/// 서버가 모르는 장식이므로 시드만 같으면 모든 클라이언트가 같은 자리에 같은
/// 것을 본다. 청크를 다시 마운트해도 자리가 바뀌지 않는다.
class ProvisPropField {
  const ProvisPropField(this.worldSeed);

  final int worldSeed;

  /// 기물을 뽑는 격자 한 변의 타일 수.
  ///
  /// 밀도가 곧 가독성이다. 전투가 벌어지는 바닥을 장식으로 덮으면 공격
  /// 표시와 캐릭터 실루엣이 묻힌다 — 랜드마크로 띄엄띄엄 두는 편이 맞다.
  /// 다만 너무 성기면 1 km 를 걸어도 아무것도 만나지 않아, 지형이 아니라
  /// 여전히 판으로 읽힌다. 화면(약 30×20타일)에 몇 개는 들어와야 한다.
  static const int cellTiles = 10;

  /// 한 칸에 기물이 설 확률.
  static const double _density = 0.55;

  /// 청크 하나에 속한 기물 목록.
  ///
  /// [walkable] 은 "그 자리에 서도 되는가"를 판정한다. 통행 불가 타일이나
  /// 구조물 위에는 놓지 않는다 — 기물이 벽을 뚫고 자란 것처럼 보인다.
  List<ProvisPropSpec> inChunk(
    int cx,
    int cy, {
    required bool Function(int gx, int gy) walkable,
    required bool Function(double gx, double gy) inSafeZone,
  }) {
    final specs = <ProvisPropSpec>[];
    final startX = cx * kChunkTiles;
    final startY = cy * kChunkTiles;

    for (var cellY = startY; cellY < startY + kChunkTiles; cellY += cellTiles) {
      for (
        var cellX = startX;
        cellX < startX + kChunkTiles;
        cellX += cellTiles
      ) {
        final r = ProvisBridge.groundRng(worldSeed ^ 0x9D07, cellX, cellY);
        if (!r.chance(_density)) continue;

        final gx = cellX + r.range(2, cellTiles - 2.0);
        final gy = cellY + r.range(2, cellTiles - 2.0);
        if (!walkable(gx.floor(), gy.floor())) continue;
        // 안전지대는 접속 지점이라 시야가 트여 있어야 한다.
        if (inSafeZone(gx, gy)) continue;

        specs.add(
          ProvisPropSpec(
            gx: gx,
            gy: gy,
            kind: _kindFor(r),
            seed: r.intRange(0, 1 << 30),
            scale: r.range(0.85, 1.2),
          ),
        );
      }
    }
    return specs;
  }

  /// 종을 고른다. 결정이 가장 흔하고, 신호탑은 드물어야 랜드마크로 읽힌다.
  static ProvisPropKind _kindFor(Rng r) {
    final roll = r.unit;
    if (roll < 0.52) return ProvisPropKind.shard;
    if (roll < 0.84) return ProvisPropKind.ridge;
    return ProvisPropKind.mast;
  }
}
