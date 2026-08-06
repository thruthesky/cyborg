import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:actionrpg/game/entities/enemy.dart';
import 'package:actionrpg/game/level/level_map.dart';
import 'package:actionrpg/game/systems/elite.dart';
import 'package:actionrpg/game/systems/monster_codex.dart';
import 'package:actionrpg/game/systems/monster_population.dart';

/// 정예 개체가 지켜야 할 선을 잠근다.
///
/// 정예는 "같은 기종인데 유독 질긴 놈" 이어야 하지, **더 아프게 때리는 놈이어서는
/// 안 된다.** 이 게임의 피해는 몬스터 레벨과 항등이고(§8.5), 배율이 하나라도 끼면
/// 화면의 피해 숫자는 반올림되어 어긋남이 눈에 띄지 않는다. 그래서 여기서 잡는
/// 첫 번째 문장은 언제나 "정예도 레벨만큼 때린다" 다.
void main() {
  Enemy spawn(int level, {EliteTrait? elite}) => Enemy(
    species: MonsterCodex.byLevel(level),
    grid: Vector2(10, 10),
    elite: elite,
  );

  group('정예와 피해 규격', () {
    test('정예도 피해는 레벨과 항등이다', () {
      for (final level in [1, 7, 40, 130, 200]) {
        final plain = spawn(level);
        for (final trait in EliteTrait.values) {
          expect(
            spawn(level, elite: trait).stats.damage,
            plain.stats.damage,
            reason: '$trait 이 피해를 건드렸다',
          );
        }
      }
    });

    test('사거리와 어그로도 그대로다', () {
      // 정예가 사거리까지 늘리면 "같은 기종" 이라는 말이 거짓이 된다.
      final plain = spawn(60);
      for (final trait in EliteTrait.values) {
        final elite = spawn(60, elite: trait);
        expect(elite.stats.attackRange, plain.stats.attackRange);
        expect(elite.stats.aggroMaxMeters, plain.stats.aggroMaxMeters);
      }
    });
  });

  group('정예의 값어치', () {
    test('정예는 더 질기다', () {
      final plain = spawn(50);
      for (final trait in EliteTrait.values) {
        final elite = spawn(50, elite: trait);
        expect(elite.maxHp, greaterThan(plain.maxHp));
        expect(
          elite.maxHp,
          closeTo(plain.maxHp * trait.hpScale, 1e-6),
        );
      }
    });

    test('질긴 만큼 경험치도 오른다', () {
      // 세 배 질긴데 값어치가 같으면, 정예는 피해 다니는 것이 정답이 된다.
      final plain = spawn(50);
      for (final trait in EliteTrait.values) {
        expect(spawn(50, elite: trait).xpValue, greaterThan(plain.xpValue));
      }
    });

    test('정예가 아닌 개체는 아무것도 달라지지 않는다', () {
      final plain = spawn(80);
      expect(plain.isElite, isFalse);
      expect(plain.elite, isNull);
      expect(plain.maxHp, MonsterCodex.byLevel(80).stats.maxHp);
    });
  });

  group('정예가 나오는 빈도', () {
    test('시작 근처에서는 드물고 외곽으로 갈수록 흔해진다', () {
      expect(EliteTrait.chanceAt(0), lessThan(EliteTrait.chanceAt(1)));
      // 흔해져도 "드물다" 는 성질은 남아야 한다. 열에 하나가 정예면 정예가 아니다.
      expect(EliteTrait.chanceAt(1), lessThan(0.12));
    });

    test('굴림은 그 확률을 따른다', () {
      final random = math.Random(20260806);
      var elites = 0;
      const rolls = 20000;
      for (var i = 0; i < rolls; i++) {
        if (EliteTrait.roll(random, 0.5) != null) elites++;
      }
      expect(elites / rolls, closeTo(EliteTrait.chanceAt(0.5), 0.01));
    });

    test('세 변종이 고르게 나온다', () {
      final random = math.Random(7);
      final counts = <EliteTrait, int>{};
      for (var i = 0; i < 20000; i++) {
        final trait = EliteTrait.roll(random, 1);
        if (trait != null) counts[trait] = (counts[trait] ?? 0) + 1;
      }
      expect(counts.length, EliteTrait.values.length);
      final total = counts.values.reduce((a, b) => a + b);
      for (final count in counts.values) {
        expect(count / total, closeTo(1 / EliteTrait.values.length, 0.05));
      }
    });
  });

  group('월드 배치', () {
    test('월드에는 정예가 섞여 있지만 소수다', () {
      final map = LevelMap.generate();
      final population = MonsterPopulation.generate(map);

      var seeds = 0;
      var elites = 0;
      for (final seed in population.seedsNear(
        map.worldCenter,
        map.width.toDouble(),
      )) {
        seeds++;
        if (seed.elite != null) elites++;
      }

      expect(seeds, greaterThan(100));
      expect(elites, greaterThan(0), reason: '정예가 한 기도 없다');
      expect(
        elites / seeds,
        lessThan(0.12),
        reason: '정예가 흔해지면 정예가 아니다',
      );
    });

    test('같은 시드는 같은 정예 배치를 낸다', () {
      // 장부가 정예를 들고 있으므로, 지나쳤던 그 정예를 다시 찾아갈 수 있다.
      final map = LevelMap.generate();
      final a = MonsterPopulation.generate(map, seed: 4242);
      final b = MonsterPopulation.generate(map, seed: 4242);

      final left = a
          .seedsNear(map.worldCenter, map.width.toDouble())
          .map((seed) => seed.elite)
          .toList();
      final right = b
          .seedsNear(map.worldCenter, map.width.toDouble())
          .map((seed) => seed.elite)
          .toList();

      expect(left, right);
    });
  });
}
