import 'dart:math' as math;

import 'monster_codex.dart';
import 'weapon.dart';
import '../entities/pickup.dart';

/// 드롭 테이블의 한 줄. 각 항목은 서로 독립적으로 굴린다.
class DropEntry {
  const DropEntry(
    this.kind, {
    required this.chance,
    this.minCount = 1,
    this.maxCount = 1,
    this.amountScale = 1.0,
  });

  /// 떨어질 전리품 종류.
  final PickupKind kind;

  /// 이 항목이 나올 확률(0~1). 1이면 확정 드롭이다.
  final double chance;

  /// 당첨되었을 때 떨어지는 최소/최대 개수.
  final int minCount;
  final int maxCount;

  /// [PickupSpec.amount]에 곱해지는 효과량 배율.
  final double amountScale;
}

/// 실제로 굴려서 결정된 드롭 하나.
class DropResult {
  const DropResult(this.kind, this.amount, {this.weapon});

  final PickupKind kind;
  final double amount;

  /// [PickupKind.weaponCache] 일 때 그 안에 든 무기. 나머지는 null이다.
  final Weapon? weapon;
}

/// 대상 하나가 파괴되었을 때 굴리는 드롭 표.
class DropTable {
  const DropTable(this.entries, {this.maxDrops = 4, this.weaponChance = 0});

  final List<DropEntry> entries;

  /// 한 번에 떨어질 수 있는 최대 개수. 화면이 전리품으로 덮이지 않게 막는다.
  final int maxDrops;

  /// 무기 상자가 나올 확률(0~1).
  ///
  /// 무기를 [entries] 의 한 줄로 두지 않은 이유는 굴림의 축이 다르기 때문이다.
  /// 나머지 항목은 개수와 효과량을 굴리지만 무기는 **레벨과 벼림**을 굴리며,
  /// 그러려면 떨군 로봇의 레벨이 필요하다([roll] 의 `weaponLevel`).
  final double weaponChance;

  /// 표를 굴려 떨어질 전리품 목록을 만든다.
  ///
  /// [luck]은 확률에 더해지는 보너스로, 후반 웨이브일수록 조금 후해진다.
  /// [amountMultiplier]는 효과량 전체에 곱해진다.
  /// [weaponLevel]을 넘기면 [weaponChance]로 무기 상자를 함께 굴린다.
  List<DropResult> roll(
    math.Random rng, {
    double luck = 0,
    double amountMultiplier = 1.0,
    int? weaponLevel,
  }) {
    final results = <DropResult>[];

    // 무기를 맨 먼저 굴려 목록의 앞에 둔다. 뒤에 붙이면 [maxDrops] 에 잘려
    // 나가는 것이 하필 가장 드물고 가장 큰 전리품이 된다.
    //
    // 행운은 더하지 않는다. 웨이브 보정은 소모품을 조금 후하게 주자는 장치인데
    // 무기 확률은 그 자릿수가 훨씬 작아(0.01 수준) 같은 값을 더하면 후반에
    // 무기가 소모품보다 흔해진다.
    if (weaponLevel != null &&
        weaponChance > 0 &&
        rng.nextDouble() < weaponChance) {
      results.add(
        DropResult(
          PickupKind.weaponCache,
          0,
          weapon: WeaponSystem.rollDrop(rng, monsterLevel: weaponLevel),
        ),
      );
    }

    for (final entry in entries) {
      if (results.length >= maxDrops) break;
      if (rng.nextDouble() >= (entry.chance + luck).clamp(0.0, 1.0)) continue;

      final span = entry.maxCount - entry.minCount;
      final count = entry.minCount + (span > 0 ? rng.nextInt(span + 1) : 0);
      final base = PickupSpec.table[entry.kind]!.amount;

      for (var i = 0; i < count && results.length < maxDrops; i++) {
        // 같은 종류라도 회수량이 조금씩 달라 단조롭지 않게 한다.
        final jitter = 0.85 + rng.nextDouble() * 0.3;
        results.add(
          DropResult(
            entry.kind,
            base * entry.amountScale * amountMultiplier * jitter,
          ),
        );
      }
    }

    return results;
  }
}

/// 이 게임에서 쓰는 모든 드롭 표.
///
/// 밸런스 조정은 이 파일만 고치면 된다.
abstract final class DropTables {
  // ── 회복 물약 드롭 정책 ───────────────────────────────────────────────
  //
  // 1등급(100 HP)만 흔하게 나온다. 2등급(200) 이상은 **의도적으로 매우 드물다** —
  // 회복은 물약에 기대는 것이 아니라 큰 체력 풀로 버티는 것이 이 게임의
  // 설계이기 때문이다. 상위 등급은 "운 좋으면 나오는 보너스"이지
  // 사냥 지속 시간을 좌우하는 자원이 아니다.
  //
  // 잡몹 기준 기대 확률: 200 → 2%, 300 → 0.8%, 500 → 0.2%, 1000 → 0.05%

  // ── 무기 드롭 정책 ───────────────────────────────────────────────────
  //
  // 골격이 단단할수록 후하다: 드론 1% → 보행 2% → 메크 4.5% → 보스 35%.
  // 잡몹 기준으로 50~100마리에 한 자루라 사냥 도중 이따금 걸리는 사건이고,
  // 그중 실제로 바꿔 드는 것은 벼림이 좋거나 레벨이 높게 굴려진 일부뿐이다
  // (`WeaponTemper` 참고). 확률을 이보다 올리면 레벨로 자라는 기본 무기가
  // 배경이 되고, 성장 축이 통째로 드롭 운으로 넘어간다.

  /// 정찰 드론. 값싼 잡몹이라 회복류 위주로 조금만 떨군다.
  static const scout = DropTable(
    [
      DropEntry(PickupKind.nanoVial, chance: 0.16),
      DropEntry(PickupKind.nanoCanister, chance: 0.012),
      DropEntry(PickupKind.energyCell, chance: 0.20),
      DropEntry(PickupKind.dataChip, chance: 0.12),
    ],
    maxDrops: 2,
    weaponChance: 0.01,
  );

  /// 순찰 보행 로봇. 표준적인 드롭.
  static const sentry = DropTable(
    [
      DropEntry(PickupKind.nanoVial, chance: 0.22),
      DropEntry(PickupKind.nanoCanister, chance: 0.02),
      DropEntry(PickupKind.repairCell, chance: 0.008),
      DropEntry(PickupKind.energyCell, chance: 0.24),
      DropEntry(PickupKind.dataChip, chance: 0.18),
      DropEntry(PickupKind.scrapCore, chance: 0.10),
    ],
    maxDrops: 3,
    weaponChance: 0.02,
  );

  /// 중장갑 메크. 단단한 만큼 보상이 두둑하다.
  static const heavy = DropTable(
    [
      DropEntry(PickupKind.nanoVial, chance: 0.30, maxCount: 2),
      DropEntry(PickupKind.nanoCanister, chance: 0.035),
      DropEntry(PickupKind.repairCell, chance: 0.015),
      DropEntry(PickupKind.regenAmpoule, chance: 0.004),
      DropEntry(PickupKind.overhaulKit, chance: 0.001),
      DropEntry(PickupKind.energyCell, chance: 0.32),
      DropEntry(PickupKind.dataChip, chance: 0.26),
      DropEntry(PickupKind.scrapCore, chance: 0.20),
    ],
    maxDrops: 4,
    weaponChance: 0.045,
  );

  /// 지휘 유닛(보스). 전부 확정 드롭이다.
  static const commander = DropTable(
    [
      DropEntry(PickupKind.nanoCanister, chance: 1, minCount: 2, maxCount: 2),
      // 구역 보스만이 상위 등급을 기대할 수 있는 자리다. 그래도 확정은 아니다.
      DropEntry(PickupKind.repairCell, chance: 0.35),
      DropEntry(PickupKind.regenAmpoule, chance: 0.08),
      DropEntry(PickupKind.overhaulKit, chance: 0.02),
      DropEntry(PickupKind.overchargeCell, chance: 1),
      DropEntry(PickupKind.energyCell, chance: 1, maxCount: 2),
      DropEntry(PickupKind.dataChip, chance: 1, minCount: 2, maxCount: 3),
      DropEntry(PickupKind.scrapCore, chance: 1, minCount: 2, maxCount: 3),
    ],
    maxDrops: 10,
    // 구역 보스를 잡을 이유가 하나 더 있어야 한다. 그래도 확정은 아니다 —
    // 확정이면 보스 사냥이 무기를 얻는 유일한 길이 되어 잡몹의 굴림이 죽는다.
    weaponChance: 0.35,
  );

  /// 파괴 가능한 보급 상자.
  static const crate = DropTable(
    [
      DropEntry(PickupKind.nanoVial, chance: 0.42),
      DropEntry(PickupKind.energyCell, chance: 0.46),
      DropEntry(PickupKind.dataChip, chance: 0.10),
    ],
    maxDrops: 2,
    // 보급 상자에서 나오는 것은 인간이 숨겨 둔 물자다. 로봇 잔해보다 드물다.
    weaponChance: 0.008,
  );

  /// [kind]에 해당하는 적의 드롭 표.
  static DropTable forEnemy(MonsterBuild build) => switch (build) {
        MonsterBuild.drone => scout,
        MonsterBuild.walker => sentry,
        MonsterBuild.siege => heavy,
        MonsterBuild.sovereign => commander,
      };
}
