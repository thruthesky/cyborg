import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:actionrpg/game/action_rpg_game.dart';
import 'package:actionrpg/game/entities/enemy.dart';
import 'package:actionrpg/game/systems/elite.dart';
import 'package:actionrpg/game/systems/monster_codex.dart';

/// 실제 월드에서 로봇이 새 규칙대로 움직이는지 본다.
///
/// `EnemyTactics` 시험이 "어느 쪽으로 갈지" 를 잠근다면, 여기서는 그 방향이
/// 실제 이동·충돌·상태 기계를 거쳐 **정말로 자리를 바꾸는지**를 본다. 순수
/// 함수는 맞는데 아무도 그것을 부르지 않는 상태가 가장 조용한 실패다.
void main() {
  /// 안전지대 밖에 플레이어를 세운 월드 하나.
  Future<ActionRpgGame> bootGame() async {
    final game = ActionRpgGame(autoStart: true);
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    await game.ready();

    // 안전지대 안에 서 있으면 로봇은 손을 대지 못한다. 밖으로 옮긴다.
    final outside = game.map.nearestWalkable(
      game.map.worldCenter + Vector2(60, 60),
    );
    game.player.grid.setFrom(outside);
    expect(game.map.safeZone.containsPoint(game.player.grid), isFalse);
    return game;
  }

  Future<Enemy> place(
    ActionRpgGame game,
    MonsterBuild build,
    Vector2 grid, {
    EliteTrait? elite,
  }) async {
    final enemy = Enemy(
      species: MonsterCodex.ofBuild(build).first,
      grid: grid,
      elite: elite,
    );
    game.enemies.add(enemy);
    game.world.add(enemy);
    await game.ready();
    return enemy;
  }

  /// 세워 둔 로봇만 돌린다.
  ///
  /// 월드 전체(`game.update`)를 돌리지 않는 이유는 두 가지다. 보려는 것이 **이
  /// 로봇의 행동**이라는 것이 하나고, 위젯 트리 없이 도는 게임은 루트가
  /// 마운트되지 않아 Flame 이 자식 추가를 큐에 넣지 않고 그 자리에서 컴포넌트
  /// 집합을 건드린다(`Component._addChild`)는 것이 둘이다 — 그러면 전투 중 튀는
  /// 이펙트 하나가 순회 중인 집합을 바꿔, 게임 탓처럼 보이는 실패가 난다.
  void run(List<Enemy> enemies, {int frames = 90}) {
    for (var i = 0; i < frames; i++) {
      for (final enemy in enemies) {
        enemy.update(1 / 60);
      }
    }
  }

  testWidgets('원거리 기종은 코앞까지 붙으면 물러난다', (tester) async {
    await tester.runAsync(() async {
      final game = await bootGame();
      // 포격형 코앞. 여태 붙어서 쏘던 자리다.
      final enemy = await place(
        game,
        MonsterBuild.siege,
        game.player.grid + Vector2(1.5, 0),
      );
      final before = (enemy.grid - game.player.grid).length;

      run([enemy]);

      final after = (enemy.grid - game.player.grid).length;
      expect(
        after,
        greaterThan(before + 0.8),
        reason: '포격형이 코앞에 붙어 선 채로 쏘고 있다',
      );
      // 사거리를 되찾은 뒤에는 더 물러나지 않는다 — 도망이 아니라 거리 유지다.
      expect(after, lessThan(enemy.stats.attackRange));
    });
  });

  testWidgets('근접 기종은 그대로 파고든다', (tester) async {
    await tester.runAsync(() async {
      final game = await bootGame();
      final enemy = await place(
        game,
        MonsterBuild.walker,
        game.player.grid + Vector2(2.2, 0),
      );
      // 보행형의 감지 거리는 개체마다 1~2.5 m 로 굴려지므로, 2.2 m 는 알아챌
      // 수도 못 알아챌 수도 있다. 여기서 보려는 것은 감지가 아니라 **알아챈
      // 뒤의 움직임**이라 추격 상태에서 출발시킨다.
      enemy.phase = EnemyPhase.chase;
      final before = (enemy.grid - game.player.grid).length;

      run([enemy]);

      expect(
        (enemy.grid - game.player.grid).length,
        lessThan(before),
        reason: '보행형이 다가오지 않는다',
      );
    });
  });

  testWidgets('한 기가 발견하면 곁의 동료도 함께 달려든다', (tester) async {
    await tester.runAsync(() async {
      final game = await bootGame();

      // 발견하는 쪽: 플레이어 코앞의 비행체(감지 4~5 m).
      final scout = await place(
        game,
        MonsterBuild.drone,
        game.player.grid + Vector2(1.2, 0),
      );
      // 듣는 쪽: 보행형은 감지가 1~2.5 m 라 4.6 m 떨어진 플레이어를 스스로는
      // 절대 보지 못한다. 그런데도 깨어난다면 그것은 경보를 들었기 때문이다.
      final ally = await place(
        game,
        MonsterBuild.walker,
        game.player.grid + Vector2(4.6, 0),
      );
      expect(ally.aggroRange, lessThan(4.6));
      expect(ally.phase, EnemyPhase.idle);

      run([scout], frames: 4);

      expect(
        ally.phase,
        isNot(EnemyPhase.idle),
        reason: '동료가 경보를 듣지 못했다',
      );
    });
  });

  testWidgets('뒤에서 한 대 맞아도 무리가 함께 깨어난다', (tester) async {
    await tester.runAsync(() async {
      final game = await bootGame();

      // 둘 다 플레이어에게서 멀찍이, 서로는 붙어 있다. 사거리 밖에서 하나씩
      // 저격해 무리를 지우는 길을 막는 것이 이 규칙의 목적이다.
      final target = await place(
        game,
        MonsterBuild.walker,
        game.player.grid + Vector2(14, 0),
      );
      final ally = await place(
        game,
        MonsterBuild.walker,
        game.player.grid + Vector2(16, 0),
      );
      expect(target.phase, EnemyPhase.idle);
      expect(ally.phase, EnemyPhase.idle);

      target.applyDamage(5);

      expect(target.phase, EnemyPhase.chase);
      expect(ally.phase, EnemyPhase.chase, reason: '곁의 동료가 그대로 잔다');
    });
  });

  testWidgets('경계 지휘 정예는 더 넓은 범위를 깨운다', (tester) async {
    await tester.runAsync(() async {
      final game = await bootGame();

      final warden = await place(
        game,
        MonsterBuild.walker,
        game.player.grid + Vector2(20, 0),
        elite: EliteTrait.warden,
      );
      // 일반 개체의 경보 반경(4.5) 밖, 경계 지휘의 반경(12) 안이다.
      final far = await place(
        game,
        MonsterBuild.walker,
        game.player.grid + Vector2(28, 0),
      );

      warden.applyDamage(5);

      expect(far.phase, EnemyPhase.chase);
    });
  });

  testWidgets('일반 개체의 경보는 그만큼 멀리 가지 않는다', (tester) async {
    await tester.runAsync(() async {
      final game = await bootGame();

      final target = await place(
        game,
        MonsterBuild.walker,
        game.player.grid + Vector2(20, 0),
      );
      final far = await place(
        game,
        MonsterBuild.walker,
        game.player.grid + Vector2(28, 0),
      );

      target.applyDamage(5);

      // 8 m 는 일반 경보 반경(4.5) 밖이다. 여기까지 번지면 한 대 때릴 때마다
      // 월드의 절반이 깨어난다.
      expect(far.phase, EnemyPhase.idle);
    });
  });

  testWidgets('정예도 때리는 값은 레벨과 같다', (tester) async {
    await tester.runAsync(() async {
      final game = await bootGame();
      final elite = await place(
        game,
        MonsterBuild.walker,
        game.player.grid + Vector2(1.0, 0),
        elite: EliteTrait.overclocked,
      );

      final before = game.player.hp;
      run([elite], frames: 600);
      final taken = before - game.player.hp;

      // 맞긴 맞아야 이 시험에 뜻이 있다.
      expect(taken, greaterThan(0), reason: '정예가 한 대도 때리지 못했다');
      // 한 대의 크기는 언제나 그 로봇의 레벨이다. 정예 배율이 피해 축에 끼면
      // 여기서 깨진다.
      expect(taken % elite.stats.damage, closeTo(0, 1e-6));
    });
  });
}
