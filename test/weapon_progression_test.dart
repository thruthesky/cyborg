import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:actionrpg/game/entities/player.dart';
import 'package:actionrpg/game/systems/level_system.dart';
import 'package:actionrpg/game/systems/weapon.dart';

/// 무기는 **레벨의 함수**다. 이 파일이 지키는 것은 그 한 문장이다.
///
/// 무기를 따로 저장하지 않는 덕분에 서버는 누적 경험치만 주고받으면 되고,
/// 같은 월드의 모든 클라이언트가 남의 무기까지 똑같이 그린다. 그 전제가
/// 깨지면 무기는 동기화해야 하는 또 하나의 상태가 된다.
void main() {
  Player freshPlayer() => Player(grid: Vector2.zero());

  group('무기 강화 곡선', () {
    test('레벨업 한 번은 반드시 무기를 강화한다', () {
      // 요구는 "레벨업마다 무기가 강해진다" 이므로, 한 레벨이라도 위력이
      // 제자리면 그 레벨에서는 강화가 없었던 것이다.
      for (var level = 1; level < LevelSystem.maxLevel; level++) {
        expect(
          WeaponSystem.powerAt(level + 1),
          greaterThan(WeaponSystem.powerAt(level)),
          reason: '$level → ${level + 1} 레벨에서 무기가 강해지지 않았다',
        );
      }
    });

    test('1레벨 무기는 배율이 없다', () {
      // 기준점이 1.0이어야 캐릭터 화면의 근접 피해가 설계 문서의 초기값과 같다.
      expect(WeaponSystem.powerAt(1), 1.0);
    });

    test('위력은 상한 안에 머문다', () {
      // 근접·원거리 피해는 레벨마다 **더해서** 이미 자란다. 무기 배율까지
      // 선형이면 둘의 곱이 제곱으로 뻗어 몬스터 체력이 무의미해진다.
      final cap = 1 + WeaponSystem.maxPowerGain;
      expect(WeaponSystem.powerAt(LevelSystem.maxLevel), lessThan(cap));
      expect(
        WeaponSystem.powerAt(LevelSystem.maxLevel),
        greaterThan(cap - 0.05),
        reason: '만렙이면 상한에 거의 닿아 있어야 곡선이 제 몫을 한 것이다',
      );
    });

    test('초반 한 레벨의 상승이 체감할 만큼은 된다', () {
      // 1% 아래로 내려가면 레벨업 배너의 "무기 강화"가 빈말이 된다.
      final gain = WeaponSystem.powerAt(2) / WeaponSystem.powerAt(1) - 1;
      expect(gain, greaterThan(0.01));
    });
  });

  group('등급', () {
    test('등급표는 레벨 순으로 겹치지 않게 놓여 있다', () {
      for (var i = 1; i < WeaponSystem.grades.length; i++) {
        expect(
          WeaponSystem.grades[i].fromLevel,
          greaterThan(WeaponSystem.grades[i - 1].fromLevel),
        );
      }
      expect(WeaponSystem.grades.first.fromLevel, 1);
      expect(
        WeaponSystem.grades.last.fromLevel,
        lessThanOrEqualTo(LevelSystem.maxLevel),
        reason: '도달할 수 없는 등급은 없는 등급이다',
      );
    });

    test('등급은 오를 뿐 내려가지 않는다', () {
      var previous = 0;
      for (var level = 1; level <= LevelSystem.maxLevel; level++) {
        final index = WeaponSystem.gradeIndexFor(level);
        expect(index, greaterThanOrEqualTo(previous));
        previous = index;
      }
      expect(previous, WeaponSystem.grades.length - 1);
    });

    test('경계 레벨에서만 등급이 바뀐다', () {
      for (var level = 2; level <= LevelSystem.maxLevel; level++) {
        final changed = WeaponSystem.gradeIndexFor(level) !=
            WeaponSystem.gradeIndexFor(level - 1);
        expect(
          changed,
          WeaponSystem.isGradeUp(level),
          reason: '$level 레벨의 등급 전환 여부가 표와 어긋난다',
        );
      }
    });

    test('등급 안에서는 이름 뒤에 벼린 횟수가 붙는다', () {
      expect(WeaponSystem.forLevel(1).label, 'SCRAP EDGE');
      expect(WeaponSystem.forLevel(3).label, 'SCRAP EDGE +2');
      // 5레벨은 다음 등급의 첫 레벨이라 다시 `+0`(생략)으로 돌아간다. 계통도
      // 함께 갈리므로 이름은 등급 앞말에 새 계통의 끝말이 붙은 것이 된다.
      expect(WeaponSystem.forLevel(5).label, '${WeaponSystem.grades[1].tier} '
          '${WeaponSystem.classForLevel(5).noun}');
    });

    test('사거리는 5레벨 구간 안에서 고정된다', () {
      // 레벨마다 흔들리면 자동 사냥의 접근 거리가 계속 미세하게 달라져 붙었다
      // 떨어졌다 한다. 계단을 만드는 값이 둘(등급·계통)이 되었지만 둘 다 5의
      // 배수에서만 바뀌므로, 구간 안에서는 여전히 한 값으로 고정된다.
      for (final start in [10, 20, 45, 120]) {
        final first = WeaponSystem.forLevel(start);
        final end = start + WeaponSystem.innateStep;
        for (var level = start; level < end; level++) {
          expect(
            WeaponSystem.forLevel(level).reachBonus,
            first.reachBonus,
            reason: '$level 레벨에서 사거리가 구간 안인데도 흔들렸다',
          );
        }
      }
    });

    test('같은 레벨은 언제나 같은 무기를 준다', () {
      // 남의 무기를 레벨에서 그려 내는 근거다. 값이 흔들리면 사람마다 다른
      // 무기가 보인다.
      expect(identical(WeaponSystem.forLevel(42), WeaponSystem.forLevel(42)),
          isTrue);
    });
  });

  group('5레벨마다 갈리는 계통', () {
    test('계통은 5의 배수에서만, 그리고 반드시 갈린다', () {
      // "5레벨마다 새 무기" 라는 요구가 그대로 이 한 줄이다. 한쪽이라도
      // 어긋나면 — 4레벨에서 갈리거나 10레벨에서 안 갈리거나 — 성장의 리듬이
      // 레벨 숫자와 따로 논다.
      for (var level = 2; level <= LevelSystem.maxLevel; level++) {
        expect(
          WeaponSystem.isClassSwap(level),
          level % WeaponSystem.innateStep == 0,
          reason: '$level 레벨의 계통 전환 여부가 5레벨 주기와 어긋난다',
        );
      }
    });

    test('주기는 스탯 강화 구간과 같은 자리에 온다', () {
      // 계통끼리 초당 피해가 최대 5% 다르므로, 계통만 갈리는 레벨이 있으면
      // 그 레벨에서는 새 무기가 **약해진 것**으로 읽힐 수 있다. 스탯이 가장
      // 크게 뛰는 레벨에 얹어야 그 차이가 도약에 묻힌다.
      for (var level = 2; level <= 200; level++) {
        if (!WeaponSystem.isClassSwap(level)) continue;
        expect(
          LevelSystem.gainsFor(level).milestone,
          isTrue,
          reason: '$level 레벨은 계통만 갈리고 스탯은 평범하게 오른다',
        );
      }
    });

    test('일곱 계통이 모두 차례로 손에 들어온다', () {
      // 하나라도 빠지면 그 계통은 주워야만 만나는 무기로 남는다.
      final seen = <WeaponClass>{};
      for (var level = 1; level < 35; level++) {
        seen.add(WeaponSystem.classForLevel(level));
      }
      expect(seen, WeaponClass.values.toSet());
    });

    test('끝나지 않고 돈다', () {
      // 목록이 소진되면 멈추는 것이 아니라 처음으로 돌아온다. 그래야 만렙까지
      // "5레벨마다 새 무기" 가 계속 참이다.
      final cycle = WeaponSystem.innateCycle.length * WeaponSystem.innateStep;
      for (var level = 1; level + cycle <= LevelSystem.maxLevel; level++) {
        expect(
          WeaponSystem.classForLevel(level + cycle),
          WeaponSystem.classForLevel(level),
          reason: '$level 레벨과 한 바퀴 뒤의 계통이 다르다',
        );
      }
    });

    test('돌아온 계통은 같은 무기가 아니다', () {
      // 한 바퀴 도는 동안 등급이 올라 있어야 "또 그 칼" 이 아니라 "그 칼의
      // 다음 판" 이 된다. 이름·색·날의 수가 모두 등급에서 오므로 등급만
      // 확인하면 된다.
      final cycle = WeaponSystem.innateCycle.length * WeaponSystem.innateStep;
      final first = WeaponSystem.forLevel(1);
      final second = WeaponSystem.forLevel(1 + cycle);
      expect(second.weaponClass, first.weaponClass);
      expect(second.gradeIndex, greaterThan(first.gradeIndex));
      expect(second.label, isNot(first.label));
    });

    test('처음 손에 쥐는 것은 블레이드다', () {
      // 사이보그의 팔에 처음부터 달려 있는 것이 블레이드다. 첫 구간이 낯선
      // 계통이면 게임을 시작하자마자 배워야 할 것이 하나 더 생긴다.
      for (var level = 1; level < WeaponSystem.innateStep; level++) {
        expect(WeaponSystem.forLevel(level).weaponClass, WeaponClass.blade);
      }
      expect(WeaponSystem.innateCycle.first, WeaponClass.blade);
    });

    test('계통이 갈려도 무기가 눈에 띄게 약해지지는 않는다', () {
      // 계통은 맞바꿈이라 초당 피해가 최대 5% 흔들린다. 레벨업의 상승분이 그
      // 흔들림을 덮어야 "새 무기를 받았는데 약해졌다" 가 안 나온다.
      for (var level = 1; level < LevelSystem.maxLevel; level++) {
        expect(
          WeaponSystem.forLevel(level + 1).dps,
          greaterThan(WeaponSystem.forLevel(level).dps * 0.97),
          reason: '$level → ${level + 1} 레벨에서 무기가 3% 넘게 약해졌다',
        );
      }
    });

    test('한 바퀴를 돌면 반드시 세진다', () {
      // 구간 하나하나는 맞바꿈이라 오르내릴 수 있어도, 한 바퀴의 끝은 언제나
      // 시작보다 위여야 성장 축이 성립한다.
      final cycle = WeaponSystem.innateCycle.length * WeaponSystem.innateStep;
      for (var level = 1; level + cycle <= LevelSystem.maxLevel; level++) {
        expect(
          WeaponSystem.forLevel(level + cycle).dps,
          greaterThan(WeaponSystem.forLevel(level).dps),
          reason: '$level 레벨에서 한 바퀴를 돌았는데 세지지 않았다',
        );
      }
    });

    test('이웃한 구간은 서로 다른 리듬이다', () {
      // 5레벨을 들여 받은 무기가 방금 쓰던 것과 속도까지 비슷하면 바뀐 줄도
      // 모른다. 속도든 부채꼴이든 하나는 확실히 달라야 한다.
      final cycle = WeaponSystem.innateCycle;
      for (var i = 0; i < cycle.length; i++) {
        final a = cycle[i];
        final b = cycle[(i + 1) % cycle.length];
        final speedGap = (a.speed - b.speed).abs() / a.speed;
        final arcGap = (a.arcDegrees - b.arcDegrees).abs() / a.arcDegrees;
        expect(
          math.max(speedGap, arcGap),
          greaterThan(0.25),
          reason: '$a 다음에 오는 $b 가 너무 비슷하다',
        );
      }
    });

    test('무게로 때리는 계통만 타격이 늦다', () {
      // 판정 시점은 그림과 같은 값을 읽는다. 들어 올렸다 내리찍는 시간이
      // 곧 그 계통의 성격이라, 무겁지 않은 계통이 늦으면 그냥 굼뜬 것이 된다.
      for (final weaponClass in WeaponClass.values) {
        expect(
          weaponClass.hitAt > 0.5,
          weaponClass.heavy,
          reason: '$weaponClass 의 타격 시점과 무게감이 서로 어긋난다',
        );
      }
    });
  });

  group('플레이어와 맞물림', () {
    test('레벨을 복원하면 무기도 그 레벨의 것이 된다', () {
      final player = freshPlayer()
        ..restoreProgress(totalXp: LevelSystem.totalXpForLevel(37));

      expect(player.level, 37);
      expect(player.weapon.level, 37);
      expect(player.weapon.grade.name, WeaponSystem.forLevel(37).grade.name);
    });

    test('무기 위력이 실제 피해에 곱해진다', () {
      final novice = freshPlayer();
      final veteran = freshPlayer()
        ..restoreProgress(totalXp: LevelSystem.totalXpForLevel(30));

      // 스탯 상승만으로 오른 몫과 무기가 곱한 몫을 분리해서 확인한다.
      //
      // 근접에는 계통의 몫까지 곱해진다. 30레벨의 기본 무기는 블레이드가
      // 아니므로(5레벨마다 계통이 돈다) 그 배율이 1.0 이 아니다 — 이 숫자만
      // 보고 약해졌다고 읽으면 안 된다. 계통은 세기를 속도와 맞바꾼다.
      expect(
        veteran.effectiveMeleeDamage,
        closeTo(
          veteran.meleeDamage *
              veteran.weapon.power *
              veteran.weapon.weaponClass.damage,
          1e-9,
        ),
      );
      expect(
        veteran.effectiveRangedDamage,
        closeTo(veteran.rangedDamage * veteran.weapon.power, 1e-9),
      );
      expect(novice.effectiveMeleeDamage, closeTo(novice.meleeDamage, 1e-9));
    });

    test('무기가 길어지면 근접 사거리도 함께 늘어난다', () {
      final novice = freshPlayer();
      final veteran = freshPlayer()
        ..restoreProgress(totalXp: LevelSystem.totalXpForLevel(300));

      expect(novice.meleeReach, Player.meleeRange);
      expect(veteran.meleeReach, greaterThan(novice.meleeReach));
      expect(
        veteran.meleeReach,
        Player.meleeRange + veteran.weapon.reachBonus,
      );
    });
  });
}
