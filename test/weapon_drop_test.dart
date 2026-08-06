import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:actionrpg/game/entities/pickup.dart';
import 'package:actionrpg/game/entities/player.dart';
import 'package:actionrpg/game/systems/drop_table.dart';
import 'package:actionrpg/game/systems/level_system.dart';
import 'package:actionrpg/game/systems/weapon.dart';

/// 로봇 잔해에서 나오는 무기 드롭을 잠근다.
///
/// 이 파일이 지키는 문장은 둘이다.
///
/// 1. **떨어지는 무기는 굴린 값이다.** 레벨과 벼림이 굴림에서 나오므로 같은
///    로봇도 매번 다른 무기를 떨군다.
/// 2. **주운 무기는 레벨에서 자라는 기본 무기를 대체하지 않는다.** 둘 중 센
///    쪽이 손에 들리므로, 드롭 운이 없어도 무기는 레벨을 따라 자란다.
///
/// 2가 깨지면 성장 축이 통째로 드롭 운으로 넘어간다 — 잡몹이 떨군 낡은 칼
/// 하나에 무기가 도로 약해지는 게임이 된다.
/// 원하는 계통·레벨·벼림의 무기가 나올 때까지 굴린다.
///
/// 생성자가 비공개라 굴림 말고는 무기를 만들 길이 없다. 그것이 의도된 제약이다 —
/// 무기는 레벨에서 유도되거나 잔해에서 나오는 둘 중 하나여야 하고, 테스트라고
/// 세 번째 길을 뚫으면 그 제약이 코드에서만 지켜지는 규칙이 된다.
Weapon _drop(
  WeaponClass weaponClass, {
  required int level,
  WeaponTemper temper = WeaponTemper.field,
}) {
  for (var seed = 0; seed < 20000; seed++) {
    final rolled = WeaponSystem.rollDrop(math.Random(seed), monsterLevel: level);
    if (rolled.weaponClass == weaponClass &&
        rolled.level == level &&
        rolled.temper == temper) {
      return rolled;
    }
  }
  throw StateError('$weaponClass Lv.$level $temper 를 굴려 내지 못했다');
}

void main() {
  Player freshPlayer() => Player(grid: Vector2.zero());

  group('무기 굴림', () {
    test('굴린 무기의 등급은 그 무기 레벨의 등급이다', () {
      // 등급이 레벨과 따로 놀면 색과 위력이 어긋난다 — 화면에서 강해 보이는
      // 칼이 약한 칼이 된다.
      for (var seed = 0; seed < 200; seed++) {
        final rng = math.Random(seed);
        final weapon = WeaponSystem.rollDrop(rng, monsterLevel: 40);
        expect(weapon.gradeIndex, WeaponSystem.gradeIndexFor(weapon.level));
      }
    });

    test('무기 레벨은 떨군 로봇의 레벨 언저리에서 나온다', () {
      const monsterLevel = 60;
      for (var seed = 0; seed < 300; seed++) {
        final weapon =
            WeaponSystem.rollDrop(math.Random(seed), monsterLevel: monsterLevel);
        expect(
          (weapon.level - monsterLevel).abs(),
          lessThanOrEqualTo(WeaponSystem.dropLevelSpread),
        );
      }
    });

    test('레벨 경계 밖으로는 나가지 않는다', () {
      for (var seed = 0; seed < 200; seed++) {
        final low = WeaponSystem.rollDrop(math.Random(seed), monsterLevel: 1);
        final high = WeaponSystem.rollDrop(
          math.Random(seed),
          monsterLevel: LevelSystem.maxLevel,
        );
        expect(low.level, greaterThanOrEqualTo(1));
        expect(high.level, lessThanOrEqualTo(LevelSystem.maxLevel));
      }
    });

    test('위력은 레벨 곡선에 벼림 배율을 곱한 값이다', () {
      for (var seed = 0; seed < 100; seed++) {
        final weapon =
            WeaponSystem.rollDrop(math.Random(seed), monsterLevel: 25);
        expect(
          weapon.power,
          closeTo(
            WeaponSystem.powerAt(weapon.level) * weapon.temper.power,
            1e-9,
          ),
        );
      }
    });

    test('벼림은 다섯 등급이 모두 나오되 좋은 쪽이 드물다', () {
      // 무게대로 뽑히지 않으면 드롭의 긴장이 사라진다. APEX 가 흔하면 첫 몇
      // 마리에서 만렙 무기가 나오고, 아예 안 나오면 표에 없는 등급이 된다.
      final counts = <WeaponTemper, int>{};
      final rng = math.Random(1234);
      for (var i = 0; i < 20000; i++) {
        final temper = WeaponSystem.rollTemper(rng);
        counts[temper] = (counts[temper] ?? 0) + 1;
      }

      for (final temper in WeaponTemper.values) {
        expect(counts[temper], isNotNull, reason: '$temper 가 한 번도 안 나왔다');
      }
      expect(counts[WeaponTemper.apex]!, lessThan(counts[WeaponTemper.prime]!));
      expect(counts[WeaponTemper.prime]!, lessThan(counts[WeaponTemper.honed]!));
      expect(counts[WeaponTemper.honed]!, lessThan(counts[WeaponTemper.field]!));

      // 절반 이상은 기본 무기와 같거나 못한 것이 나와야 한다. 그래야 레벨로
      // 자라는 기본 무기가 여전히 성장의 주축이다.
      final notBetter =
          counts[WeaponTemper.worn]! + counts[WeaponTemper.field]!;
      expect(notBetter / 20000, greaterThan(0.5));
    });

    test('이름에 벼림이 드러난다', () {
      // 바닥에 떨어진 무기가 지금 든 것보다 나은지 이름만 보고도 알아야 한다.
      expect(WeaponTemper.field.prefix, isEmpty, reason: '기본 벼림은 이름을 더럽히지 않는다');
      for (final temper in WeaponTemper.values) {
        if (temper == WeaponTemper.field) continue;
        expect(temper.prefix, isNotEmpty);
      }
    });
  });

  group('계통', () {
    test('네 계통의 초당 피해는 서로 5% 안쪽이다', () {
      // 계통은 서열이 아니라 맞바꿈이다. 한 계통이 수치로 앞서면 나머지 셋은
      // 주웠을 때 실망하는 무기가 되고, 계통이 있다는 사실 자체가 무의미해진다.
      final factors =
          WeaponClass.values.map((weaponClass) => weaponClass.dpsFactor);
      final low = factors.reduce(math.min);
      final high = factors.reduce(math.max);
      expect(
        high / low,
        lessThan(1.05),
        reason: '가장 센 계통이 가장 약한 계통보다 5% 넘게 앞선다',
      );
    });

    test('어느 계통도 다른 계통을 모든 축에서 앞서지 않는다', () {
      // 초당 피해가 같아도 한 계통이 세기·속도·사거리·부채꼴을 모두 앞서면
      // 나머지는 주울 이유가 없는 무기가 된다. 모든 계통은 무언가를 내준다.
      for (final a in WeaponClass.values) {
        for (final b in WeaponClass.values) {
          if (a == b) continue;
          final dominates = a.damage >= b.damage &&
              a.speed >= b.speed &&
              a.reach >= b.reach &&
              a.arcDegrees >= b.arcDegrees;
          expect(dominates, isFalse, reason: '$a 가 $b 를 모든 축에서 앞선다');
        }
      }
    });

    test('멀리 닿는 계통은 좁게, 넓게 치는 계통은 짧게', () {
      // 사거리와 부채꼴이 함께 커지면 그 계통이 모든 상황에서 우월해진다.
      expect(WeaponClass.lance.reach, greaterThan(WeaponClass.reaper.reach));
      expect(
        WeaponClass.lance.arcDegrees,
        lessThan(WeaponClass.reaper.arcDegrees),
      );
      expect(WeaponClass.maul.arcDegrees,
          greaterThan(WeaponClass.blade.arcDegrees));
    });

    test('부채꼴 판정값은 각도와 맞물려 있다', () {
      // 넓은 부채꼴일수록 문턱이 낮아야 더 많이 맞는다.
      expect(WeaponClass.lance.arcDot, greaterThan(WeaponClass.blade.arcDot));
      expect(WeaponClass.blade.arcDot, greaterThan(WeaponClass.maul.arcDot));
      // 320°는 사실상 사방이라 뒤쪽도 맞는다.
      expect(WeaponClass.reaper.arcDot, lessThan(0));
    });

    test('기본 무기의 계통도 레벨 하나에서 나온다', () {
      // 5레벨마다 계통이 갈리지만 그 규칙이 **레벨의 순수 함수**인 것이
      // 중요하다. 굴림이 끼면 남의 화면(레벨로 그린다)과 내 화면이 갈린다.
      for (final level in [1, 5, 40, 300, LevelSystem.maxLevel]) {
        expect(
          WeaponSystem.forLevel(level).weaponClass,
          WeaponSystem.classForLevel(level),
        );
      }
    });

    test('드롭은 네 계통을 모두 내놓되 블레이드가 가장 흔하다', () {
      final counts = <WeaponClass, int>{};
      final rng = math.Random(4242);
      for (var i = 0; i < 10000; i++) {
        final weaponClass = WeaponSystem.rollClass(rng);
        counts[weaponClass] = (counts[weaponClass] ?? 0) + 1;
      }
      for (final weaponClass in WeaponClass.values) {
        expect(counts[weaponClass], isNotNull,
            reason: '$weaponClass 가 한 번도 안 나왔다');
      }
      // 낯선 계통만 쏟아지면 처음 익힌 리듬이 매번 갈아엎힌다.
      final most =
          counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      expect(most, WeaponClass.blade);
    });

    test('이름은 등급 앞말에 계통 끝말을 붙인다', () {
      // 벼림·등급·계통이 모두 전투에 영향을 주므로 셋 다 이름에 드러나야
      // 바닥의 무기를 주울지 이름만 보고 정할 수 있다.
      final grade = WeaponSystem.grades[2]; // PULSE BLADE
      expect(grade.tier, 'PULSE');
      expect(WeaponClass.maul.noun, 'MAUL');
      expect(WeaponClass.blade.noun, isEmpty, reason: '기본 계통은 등급 이름을 그대로 쓴다');

      final maul = _drop(WeaponClass.maul, level: 12);
      expect(maul.label, contains('PULSE MAUL'));
      // 기본 무기도 마찬가지다 — 12레벨의 계통은 블레이드가 아니므로 등급
      // 이름(`PULSE BLADE`)이 아니라 그 계통의 이름이 나와야 한다.
      expect(WeaponSystem.forLevel(12).label, 'PULSE LANCE +2');
      // `title` 은 벼림과 벼린 횟수를 뺀 이름이다. 무기가 바뀐 순간의 배너가
      // 이것을 쓴다 — 거기서 `+2` 까지 읽히면 정작 바뀐 것이 묻힌다.
      expect(WeaponSystem.forLevel(12).title, 'PULSE LANCE');
      expect(maul.title, 'PULSE MAUL');
    });

    test('주운 계통끼리, 그리고 기본 무기와 색이 뚜렷하게 다르다', () {
      // 실루엣은 붙어야 보이지만 색은 화면 반대편에서도 보인다. 두 계통의
      // 색상각이 붙어 있으면 바닥의 상자를 주우러 갈지 이름을 읽어야 정한다.
      //
      // 견주는 대상에 **1레벨 블레이드**를 넣는다. 블레이드는 등급을 따라
      // 청록에서 금빛까지 90° 넘게 흐르므로 모든 레벨에서 떨어져 있게 할 수는
      // 없다 — 마젠타(적)를 빼고 나면 색상환에 그만한 자리가 없다. 대신 대부분의
      // 플레이 시간이 놓인 낮은 등급의 청록에서 확실히 갈라 둔다. 높은 등급의
      // 블레이드와 색이 겹치는 자리는 실루엣과 이름이 갈라 준다.
      //
      // 문턱이 60°가 아니라 45°인 이유는 계통이 일곱이기 때문이다. 마젠타
      // 대역(300~355)을 뺀 305°에 일곱을 60°씩 벌려 놓으려면 420°가 필요하다.
      // 45°는 채도 높은 색끼리는 확실히 갈리는 폭이고, 여기서 계통을 더
      // 늘리려면 색이 아니라 실루엣에 기대야 한다.
      final fixed = WeaponClass.values.where((c) => c.hue != null).toList();
      final hues = <String, double>{
        for (final c in fixed) c.name: c.hue!,
        'blade(Lv.1)': HSLColor.fromColor(WeaponSystem.forLevel(1).glow).hue,
      };

      final names = hues.keys.toList();
      for (var i = 0; i < names.length; i++) {
        for (var j = i + 1; j < names.length; j++) {
          final gap = (hues[names[i]]! - hues[names[j]]!).abs();
          expect(
            math.min(gap, 360 - gap),
            greaterThan(44),
            reason: '${names[i]} 와 ${names[j]} 의 색이 서로 45° 안쪽이라 헷갈린다',
          );
        }
      }
    });

    test('굴린 무기의 색은 계통의 색상각을 그대로 띤다', () {
      for (final weaponClass in WeaponClass.values) {
        final hue = weaponClass.hue;
        if (hue == null) continue;
        for (final level in [1, 35, 120, 700]) {
          final glow = _drop(weaponClass, level: level).glow;
          expect(
            HSLColor.fromColor(glow).hue,
            closeTo(hue, 2),
            reason: '$weaponClass Lv.$level 이 계통 색을 잃었다',
          );
        }
      }
    });

    test('마젠타 계열은 쓰지 않는다', () {
      // 이 게임의 색 언어에서 마젠타는 "적"이다. 플레이어의 무기가 그 색을
      // 띠면 난전 중에 적으로 읽힌다.
      for (final weaponClass in WeaponClass.values) {
        for (final level in [1, 20, 80, 300, 700]) {
          final hue = HSLColor.fromColor(_drop(weaponClass, level: level).glow)
              .hue;
          expect(
            hue > 300 && hue < 355,
            isFalse,
            reason: '$weaponClass Lv.$level 의 색이 적의 마젠타 대역에 들어갔다',
          );
        }
      }
    });

    test('블레이드는 등급 색 흐름을 그대로 쓴다', () {
      // 레벨업이 무기 색을 바꾸는 것이 성장의 신호다. 블레이드까지 한 색으로
      // 묶으면 그 신호가 사라진다.
      //
      // 블레이드 구간만 골라 본다. 5레벨마다 계통이 도는 지금은 아무 레벨이나
      // 집으면 그 계통의 색이 씌워져 있어(`WeaponClass.tint`) 당연히 다르다.
      var checked = 0;
      for (var level = 1; level <= LevelSystem.maxLevel; level++) {
        if (WeaponSystem.classForLevel(level) != WeaponClass.blade) continue;
        final blade = WeaponSystem.forLevel(level);
        expect(blade.glow, blade.grade.glow);
        expect(blade.core, blade.grade.core);
        checked++;
      }
      expect(checked, greaterThan(0), reason: '블레이드를 드는 레벨이 하나도 없다');
    });

    test('색을 갈아 끼워도 등급의 밝기는 남는다', () {
      // 계통이 색상을, 등급이 밝기를 맡는다. 밝기까지 고정하면 같은 계통의
      // 1레벨과 만렙이 똑같아 보인다.
      final low = HSLColor.fromColor(_drop(WeaponClass.maul, level: 1).glow);
      final high = HSLColor.fromColor(_drop(WeaponClass.maul, level: 700).glow);
      expect(low.hue, closeTo(high.hue, 1));
      expect(high.lightness, greaterThan(low.lightness));
    });

    test('계통은 사거리에 자기 몫을 더한다', () {
      final lance = _drop(WeaponClass.lance, level: 1);
      final blade = WeaponSystem.forLevel(1);
      expect(
        lance.reachBonus - blade.reachBonus,
        closeTo(WeaponClass.lance.reach, 1e-9),
      );
    });

    test('바꿔 들지는 위력이 아니라 초당 피해로 정한다', () {
      // 위력만 보면 느리고 한 대가 큰 망치가 언제나 이겨 계통이 서열이 된다.
      final player = freshPlayer();
      final innate = player.weapon;
      final sameTierMaul = _drop(WeaponClass.maul, level: innate.level);

      expect(sameTierMaul.power, innate.power, reason: '같은 레벨·같은 벼림이라 위력은 같다');
      expect(
        player.equipFoundWeapon(sameTierMaul),
        isFalse,
        reason: '초당 피해가 앞서지 않는데 계통만 다르다고 바꿔 들면 안 된다',
      );
    });
  });

  group('드롭 표', () {
    test('로봇 레벨을 넘기지 않으면 무기는 나오지 않는다', () {
      // 무기 레벨을 굴릴 근거가 없는 자리(웨이브 보상 등)에서 0 레벨 무기가
      // 튀어나오는 일을 막는다.
      const table = DropTable([], weaponChance: 1);
      for (var seed = 0; seed < 50; seed++) {
        expect(table.roll(math.Random(seed)), isEmpty);
      }
    });

    test('확률 1이면 반드시 무기가 나온다', () {
      const table = DropTable([], weaponChance: 1);
      for (var seed = 0; seed < 50; seed++) {
        final results = table.roll(math.Random(seed), weaponLevel: 10);
        expect(results, hasLength(1));
        expect(results.single.kind, PickupKind.weaponCache);
        expect(results.single.weapon, isNotNull);
      }
    });

    test('확률 0이면 절대 나오지 않는다', () {
      const table = DropTable([DropEntry(PickupKind.nanoVial, chance: 1)]);
      for (var seed = 0; seed < 50; seed++) {
        final results = table.roll(math.Random(seed), weaponLevel: 10);
        expect(
          results.every((r) => r.kind != PickupKind.weaponCache),
          isTrue,
        );
      }
    });

    test('무기는 maxDrops에 잘려 나가지 않는다', () {
      // 가장 드물고 가장 큰 전리품이 흔한 소모품에 밀려 사라지면, 그 굴림은
      // 없었던 것이나 같다.
      const table = DropTable(
        [
          DropEntry(PickupKind.nanoVial, chance: 1, minCount: 5, maxCount: 5),
          DropEntry(PickupKind.energyCell, chance: 1, minCount: 5, maxCount: 5),
        ],
        maxDrops: 2,
        weaponChance: 1,
      );
      for (var seed = 0; seed < 30; seed++) {
        final results = table.roll(math.Random(seed), weaponLevel: 10);
        expect(results, hasLength(2));
        expect(results.first.kind, PickupKind.weaponCache);
      }
    });

    test('무기 종류에만 무기가 실린다', () {
      const table = DropTable(
        [DropEntry(PickupKind.dataChip, chance: 1)],
        weaponChance: 1,
      );
      final results = table.roll(math.Random(3), weaponLevel: 10);
      for (final result in results) {
        expect(
          result.weapon != null,
          result.kind == PickupKind.weaponCache,
        );
      }
    });

    test('실전 드롭 표의 무기 확률은 골격이 단단할수록 후하다', () {
      expect(DropTables.scout.weaponChance,
          lessThan(DropTables.sentry.weaponChance));
      expect(DropTables.sentry.weaponChance,
          lessThan(DropTables.heavy.weaponChance));
      expect(DropTables.heavy.weaponChance,
          lessThan(DropTables.commander.weaponChance));
      // 보스라도 확정은 아니다. 확정이면 보스 사냥이 무기를 얻는 유일한 길이
      // 되어 잡몹의 굴림이 죽는다.
      expect(DropTables.commander.weaponChance, lessThan(1));
    });

    test('잡몹이 떨구는 빈도는 사냥 도중 이따금 걸리는 수준이다', () {
      // 너무 잦으면 레벨로 자라는 기본 무기가 배경이 되고, 너무 드물면
      // 드롭이 있다는 사실 자체를 모른 채 사냥하게 된다.
      var weapons = 0;
      final rng = math.Random(99);
      for (var i = 0; i < 10000; i++) {
        final results = DropTables.sentry.roll(rng, weaponLevel: 30);
        if (results.any((r) => r.kind == PickupKind.weaponCache)) weapons++;
      }
      expect(weapons / 10000, greaterThan(0.005));
      expect(weapons / 10000, lessThan(0.05));
    });
  });

  group('주운 무기를 드는 규칙', () {
    test('지금 든 것보다 셀 때만 손에 든다', () {
      final player = freshPlayer();
      final innate = player.weapon;

      final worse = WeaponSystem.rollDrop(math.Random(0), monsterLevel: 1);
      // 1 레벨 언저리에서 굴린 WORN 이면 기본 무기보다 못하다. 못한 것이
      // 나올 때까지 굴려 그 상황을 만든다.
      var seed = 0;
      var weak = worse;
      while (weak.power >= innate.power && seed < 500) {
        weak = WeaponSystem.rollDrop(math.Random(seed++), monsterLevel: 1);
      }
      expect(weak.power, lessThan(innate.power), reason: '약한 무기를 못 만들었다');

      expect(player.equipFoundWeapon(weak), isFalse);
      expect(player.weapon, same(innate), reason: '약한 무기에 무기가 바뀌었다');
    });

    test('센 무기를 주우면 그 무기를 든다', () {
      final player = freshPlayer();
      final strong = WeaponSystem.rollDrop(math.Random(7), monsterLevel: 40);

      expect(player.equipFoundWeapon(strong), isTrue);
      expect(player.weapon, same(strong));
      // 계통의 몫은 근접 피해에만 곱해진다. 창을 들면 한 대가 작아지는 대신
      // 빨라지므로, 이 숫자만 보고 약해졌다고 읽으면 안 된다.
      expect(
        player.effectiveMeleeDamage,
        closeTo(
          player.meleeDamage * strong.power * strong.weaponClass.damage,
          1e-9,
        ),
      );
      expect(
        player.meleeReach,
        Player.meleeRange + strong.reachBonus,
      );
    });

    test('더 센 무기를 주우면 다시 바꿔 든다', () {
      final player = freshPlayer();
      final first = WeaponSystem.rollDrop(math.Random(7), monsterLevel: 20);
      final second = WeaponSystem.rollDrop(math.Random(7), monsterLevel: 60);

      expect(player.equipFoundWeapon(first), isTrue);
      expect(second.power, greaterThan(first.power));
      expect(player.equipFoundWeapon(second), isTrue);
      expect(player.weapon, same(second));
      // 되돌아가지는 않는다.
      expect(player.equipFoundWeapon(first), isFalse);
      expect(player.weapon, same(second));
    });

    test('레벨이 앞지른 무기는 손에서 내려간다', () {
      // 접속 때 되살아나는 것은 누적 경험치뿐이라 주운 무기는 남지 않는다.
      // 30 레벨로 다시 들어온 사람이 20 레벨짜리 주운 칼을 계속 들고 있으면
      // 스탯과 화면의 무기가 어긋난다.
      final player = freshPlayer()
        ..equipFoundWeapon(
          WeaponSystem.rollDrop(math.Random(7), monsterLevel: 20),
        );
      expect(player.weapon.level, isNot(1));

      player.restoreProgress(totalXp: LevelSystem.totalXpForLevel(30));
      expect(player.weapon, same(WeaponSystem.forLevel(30)));
      expect(player.weapon.temper, WeaponTemper.field);
    });
  });
}
