import 'dart:math' as math;

import 'package:flame/components.dart';

import 'monster_codex.dart';

/// 로봇이 플레이어를 향해(또는 등지고) 어느 쪽으로 움직일지 정하는 규칙.
///
/// 여태까지 모든 기종은 **똑같이 싸웠다** — 사거리에 들어갈 때까지 일직선으로
/// 걸어와, 그 자리에 못 박힌 채 때리고, 다시 걸어왔다. 계통마다 몸집과 사거리는
/// 달라도 움직임이 같으니 교전의 모양이 하나뿐이었다.
///
/// 여기서 계통별로 다른 답을 낸다.
///
/// - **비행([MonsterBuild.drone])** — 곧장 오지 않고 비껴 돈다. 작고 빠른 것이
///   직선으로 오면 그냥 쉬운 표적이다.
/// - **포격([MonsterBuild.siege])·지휘** — 원거리 기종은 붙으면 불리하다.
///   너무 가까우면 물러나며 사거리를 되찾는다.
/// - **보행([MonsterBuild.walker])** — 근접이 답이므로 곧장 파고든다.
///
/// 방향만 계산하고 실제 이동·충돌은 부르는 쪽이 한다. 그래야 Flame 없이 시험할
/// 수 있다.
class EnemyTactics {
  EnemyTactics._();

  /// 원거리 기종이 이 비율보다 가까워지면 물러난다(사거리 대비).
  ///
  /// 너무 크면 사거리 언저리에서 앞뒤로 떠는 춤이 되고, 너무 작으면 코앞까지
  /// 붙어도 물러나지 않아 물러나는 의미가 없다.
  static const double kiteRatio = 0.55;

  /// 비껴 도는 각도(라디안). 45°면 접근을 멈추고 원을 그리므로 그보다 얕게 준다.
  static const double droneArc = math.pi / 5;

  /// 추격 중인 로봇이 향할 방향(단위 벡터).
  ///
  /// [toPlayer] 는 로봇에서 플레이어로 향하는 벡터, [attackRange] 는 그 기종의
  /// 사거리다. [swayPhase] 는 개체마다 다른 위상으로, 같은 자리의 비행체 여럿이
  /// 한 몸처럼 도는 것을 막는다.
  static Vector2 chaseDirection({
    required MonsterBuild build,
    required bool ranged,
    required Vector2 toPlayer,
    required double attackRange,
    double swayPhase = 0,
  }) {
    final distance = toPlayer.length;
    if (distance < 0.0001) return Vector2(1, 0);
    final toward = toPlayer / distance;

    // 원거리 기종이 코앞까지 붙렸다. 사거리를 되찾는 것이 먼저다.
    if (ranged && distance < attackRange * kiteRatio) {
      return -toward;
    }

    // 비행체는 파고들면서도 옆으로 흐른다.
    if (build == MonsterBuild.drone) {
      final sway = math.sin(swayPhase) >= 0 ? 1.0 : -1.0;
      return _rotate(toward, droneArc * sway);
    }

    return toward;
  }

  /// 공격 직후(경직 해제 구간)에 취할 방향.
  ///
  /// 여태 이 구간에서는 아무도 움직이지 않아, 때린 자리에 그대로 서 있었다.
  /// 근접은 놓치지 않으려 파고들고 원거리는 거리를 벌린다 — 그래야 "치고
  /// 빠진다" 는 모양이 생긴다. 움직일 이유가 없으면 null.
  static Vector2? recoverDirection({
    required bool ranged,
    required Vector2 toPlayer,
    required double attackRange,
  }) {
    final distance = toPlayer.length;
    if (distance < 0.0001) return null;
    final toward = toPlayer / distance;

    if (ranged) {
      // 이미 충분히 멀면 굳이 더 물러나지 않는다.
      if (distance >= attackRange * kiteRatio) return null;
      return -toward;
    }

    // 근접은 사거리 안이면 그대로 붙어 있고, 벗어났으면 다시 붙는다.
    if (distance <= attackRange) return null;
    return toward;
  }

  /// 경직 구간에서 쓰는 속도 배율. 제 속도로 다니면 경직이 아니다.
  static const double recoverSpeedScale = 0.45;

  static Vector2 _rotate(Vector2 v, double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return Vector2(v.x * cos - v.y * sin, v.x * sin + v.y * cos);
  }
}
