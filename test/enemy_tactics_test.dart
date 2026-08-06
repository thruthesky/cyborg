import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:actionrpg/game/systems/enemy_tactics.dart';
import 'package:actionrpg/game/systems/monster_codex.dart';

/// 계통마다 다르게 싸운다는 약속을 잠근다.
///
/// 여태 모든 기종은 일직선으로 걸어와 그 자리에 못 박힌 채 때렸다. 몸집과
/// 사거리는 달라도 움직임이 같으니 교전의 모양이 하나뿐이었다. 여기서 지키는
/// 것은 그 셋이다 — **포격은 물러나고, 비행은 비껴 오고, 보행은 파고든다.**
void main() {
  /// [from] 기준으로 플레이어가 [distance] 만큼 오른쪽에 있는 상황.
  Vector2 toPlayer(double distance) => Vector2(distance, 0);

  group('원거리 기종의 거리 유지', () {
    test('사거리 안이라도 너무 붙으면 물러난다', () {
      // 붙어서 쏘는 포격 기체는 근접 무기의 밥이어야 한다. 그것이 이 계통의
      // 약점이고, 플레이어가 파고들 이유다.
      final direction = EnemyTactics.chaseDirection(
        build: MonsterBuild.siege,
        ranged: true,
        toPlayer: toPlayer(1.0),
        attackRange: 7.5,
      );
      expect(direction.x, lessThan(0), reason: '플레이어 반대쪽으로 물러나야 한다');
    });

    test('적당한 거리에서는 다가간다', () {
      final direction = EnemyTactics.chaseDirection(
        build: MonsterBuild.siege,
        ranged: true,
        toPlayer: toPlayer(9.0),
        attackRange: 7.5,
      );
      expect(direction.x, greaterThan(0));
    });

    test('물러나고 다가가는 경계는 사거리에 비례한다', () {
      // 사거리가 두 배인 기종은 두 배 먼 거리에서 물러나기 시작한다.
      for (final range in [4.0, 7.5, 9.0]) {
        final boundary = range * EnemyTactics.kiteRatio;
        final inside = EnemyTactics.chaseDirection(
          build: MonsterBuild.siege,
          ranged: true,
          toPlayer: toPlayer(boundary - 0.1),
          attackRange: range,
        );
        final outside = EnemyTactics.chaseDirection(
          build: MonsterBuild.siege,
          ranged: true,
          toPlayer: toPlayer(boundary + 0.1),
          attackRange: range,
        );
        expect(inside.x, lessThan(0));
        expect(outside.x, greaterThan(0));
      }
    });
  });

  group('비행 기종의 선회', () {
    test('곧장 오지 않고 비껴 온다', () {
      final direction = EnemyTactics.chaseDirection(
        build: MonsterBuild.drone,
        ranged: false,
        toPlayer: toPlayer(6),
        attackRange: 1.2,
      );
      // 옆으로 흐르는 성분이 있어야 선회다.
      expect(direction.y.abs(), greaterThan(0.1));
      // 그래도 다가오기는 해야 한다 — 원만 그리면 영영 닿지 않는다.
      expect(direction.x, greaterThan(0));
    });

    test('개체마다 도는 쪽이 갈린다', () {
      // 위상이 다르면 도는 방향도 갈려, 여러 기가 한 몸처럼 돌지 않는다.
      final left = EnemyTactics.chaseDirection(
        build: MonsterBuild.drone,
        ranged: false,
        toPlayer: toPlayer(6),
        attackRange: 1.2,
        swayPhase: math.pi / 2,
      );
      final right = EnemyTactics.chaseDirection(
        build: MonsterBuild.drone,
        ranged: false,
        toPlayer: toPlayer(6),
        attackRange: 1.2,
        swayPhase: -math.pi / 2,
      );
      expect(left.y.sign, isNot(right.y.sign));
    });
  });

  group('보행 기종', () {
    test('곧장 파고든다', () {
      final direction = EnemyTactics.chaseDirection(
        build: MonsterBuild.walker,
        ranged: false,
        toPlayer: toPlayer(5),
        attackRange: 1.4,
      );
      expect(direction.x, closeTo(1, 1e-9));
      expect(direction.y, closeTo(0, 1e-9));
    });
  });

  group('공격 직후', () {
    test('근접은 사거리를 벗어났으면 다시 붙는다', () {
      final step = EnemyTactics.recoverDirection(
        ranged: false,
        toPlayer: toPlayer(3),
        attackRange: 1.4,
      );
      expect(step, isNotNull);
      expect(step!.x, greaterThan(0));
    });

    test('근접은 이미 붙어 있으면 움직이지 않는다', () {
      expect(
        EnemyTactics.recoverDirection(
          ranged: false,
          toPlayer: toPlayer(1.0),
          attackRange: 1.4,
        ),
        isNull,
      );
    });

    test('원거리는 붙어 있으면 물러난다', () {
      final step = EnemyTactics.recoverDirection(
        ranged: true,
        toPlayer: toPlayer(1.0),
        attackRange: 7.5,
      );
      expect(step, isNotNull);
      expect(step!.x, lessThan(0));
    });

    test('원거리는 충분히 멀면 굳이 더 물러나지 않는다', () {
      expect(
        EnemyTactics.recoverDirection(
          ranged: true,
          toPlayer: toPlayer(7),
          attackRange: 7.5,
        ),
        isNull,
      );
    });

    test('경직 구간은 제 속도로 다니지 않는다', () {
      expect(EnemyTactics.recoverSpeedScale, lessThan(1));
      expect(EnemyTactics.recoverSpeedScale, greaterThan(0));
    });
  });

  group('안전장치', () {
    test('겹쳐 선 순간에도 방향은 언제나 단위 벡터다', () {
      // 0으로 나누면 NaN 이 나오고, NaN 좌표는 그 개체를 월드에서 지워 버린다.
      for (final build in MonsterBuild.values) {
        for (final ranged in [true, false]) {
          final direction = EnemyTactics.chaseDirection(
            build: build,
            ranged: ranged,
            toPlayer: Vector2.zero(),
            attackRange: 5,
          );
          expect(direction.length, closeTo(1, 1e-6));
          expect(direction.x.isNaN, isFalse);
        }
      }
      expect(
        EnemyTactics.recoverDirection(
          ranged: true,
          toPlayer: Vector2.zero(),
          attackRange: 5,
        ),
        isNull,
      );
    });

    test('모든 방향은 단위 길이다', () {
      for (final build in MonsterBuild.values) {
        for (final distance in [0.5, 3.0, 12.0]) {
          final direction = EnemyTactics.chaseDirection(
            build: build,
            ranged: true,
            toPlayer: Vector2(distance * 0.6, distance * 0.8),
            attackRange: 7.5,
          );
          expect(direction.length, closeTo(1, 1e-6));
        }
      }
    });
  });
}
