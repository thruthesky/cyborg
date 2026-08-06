import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../auth/cyborg_kind.dart';
import '../iso.dart';
import '../net/world_presence.dart';
import '../palette.dart';
import '../systems/weapon.dart';
import 'cyborg_design.dart';
import 'cyborg_renderer.dart';
import 'iso_entity.dart';

/// 같은 월드에 들어와 있는 **다른 플레이어**의 몸.
///
/// 조종하지 않는다. 서버가 알려 준 좌표를 향해 걸어갈 뿐이고, 공격도 피해도
/// 여기서는 판정하지 않는다([Damageable] 을 붙이지 않은 이유다). PK 를 붙일 때
/// 판정은 서버가 하고, 이 컴포넌트는 그 결과를 받아 그리기만 한다.
///
/// ## 왜 받은 좌표에 바로 세우지 않는가
///
/// 좌표는 초당 10 번 온다. 도착할 때마다 그 자리로 옮기면 초당 10 칸씩 튀는
/// 텔레포트로 보인다. 그래서 받은 값은 **목표**로만 두고 매 프레임 그쪽으로
/// 걸어가게 한다([_catchUpTime]). 눈에 보이는 것은 언제나 조금 과거지만,
/// 그 대신 남이 사람처럼 걷는다.
class RemotePlayer extends IsoEntity {
  RemotePlayer(RemotePlayerState state)
      : id = state.id,
        design = CyborgKind.fromId(state.kind).design,
        _name = state.name,
        _level = state.level,
        _alive = state.alive,
        _target = state.grid,
        super(
          grid: state.grid,
          bodyRadius: 0.28,
          // 같은 칸에 겹쳤을 때 내 몸이 앞에 오도록 한 칸 뒤에 세운다
          // (플레이어는 0.02). 내가 남의 등에 가려지면 조작이 답답해진다.
          depthBias: 0.01,
        );

  /// 서버 identity 문자열. 어떤 행이 이 몸인지 잇는 열쇠다.
  final String id;

  /// 이 사람이 고른 신체 프레임. 나와 같은 [CyborgRenderer] 로 그린다.
  final CyborgDesign design;

  String _name;
  int _level;
  bool _alive;

  /// 서버가 마지막으로 알려 준 자리. 실제 [grid] 는 여기를 향해 따라간다.
  Vector2 _target;

  /// 이 거리를 넘게 벌어지면 보간하지 않고 즉시 옮긴다(타일).
  ///
  /// 텔레포트·재가동은 월드를 가로지르는 이동이라, 보간하면 남이 지형을 뚫고
  /// 몇 초 동안 미끄러져 날아간다.
  static const double _snapDistance = 14.0;

  /// 벌어진 거리를 따라잡는 데 쓰는 시간(초).
  ///
  /// 갱신 주기(0.1초)보다 조금 길게 잡아야 도착 직전에 멈칫하지 않고,
  /// 너무 길면 남이 얼음판 위를 미끄러지듯 움직인다.
  static const double _catchUpTime = 0.14;

  /// 따라잡는 최저 속도(타일/초).
  ///
  /// 남은 거리에 비례해서만 좁히면 그 거리는 **영영 0 이 되지 않는다** —
  /// 남이 멈춰 선 뒤에도 마지막 몇 센티를 한없이 기어간다. 눈에 보이지는
  /// 않지만 "걷는 중" 판정이 어정쩡하게 오래 남아 정지 자세로 돌아가지 못한다.
  static const double _minCatchUpSpeed = 1.2;

  /// 이 속도를 넘어야 "걷는 중" 으로 본다(타일/초).
  static const double _runThreshold = 0.35;

  final Vector2 _facing = Vector2(1, 1)..normalize();
  double _renderYaw = 0;
  bool _renderYawPrimed = false;
  double _animTime = 0;
  double _speed = 0;

  /// 그림이 목표 방향을 따라잡는 최대 각속도(라디안/초). [Player] 와 같은 값이다.
  static const double _renderTurnRate = 14.0;

  TextPainter? _nameplate;

  /// 서버가 준 새 상태로 맞춘다.
  void apply(RemotePlayerState state) {
    _target = state.grid;
    _alive = state.alive;
    if (state.name != _name || state.level != _level) {
      _name = state.name;
      _level = state.level;
      // 이름표는 값이 바뀔 때만 다시 만든다. 매 프레임 레이아웃하면 남이
      // 늘어날수록 그 비용만 쌓인다.
      _nameplate = null;
    }
  }

  @override
  void update(double dt) {
    _animTime += dt;
    _followTarget(dt);
    _updateRenderYaw(dt);
    super.update(dt);
  }

  /// 서버가 알려 준 자리를 향해 걸어간다.
  void _followTarget(double dt) {
    final to = _target - grid;
    final distance = to.length;

    if (distance <= 0.0005) {
      _speed = 0;
      return;
    }
    if (distance > _snapDistance) {
      // 텔레포트다. 걸어서 갈 거리가 아니다.
      grid.setFrom(_target);
      _speed = 0;
      return;
    }

    final closing = math.max(distance / _catchUpTime, _minCatchUpSpeed);
    final step = math.min(distance, closing * dt);
    final direction = to / distance;
    grid.addScaled(direction, step);
    _speed = dt > 0 ? step / dt : 0;

    // 걷는 방향이 곧 보는 방향이다. 서버는 시선각을 보내지 않는다 — 좌표
    // 하나로 알 수 있는 것을 위해 열을 더할 이유가 없다.
    if (_speed > _runThreshold) _facing.setFrom(direction);
  }

  /// 몸이 도는 속도에 상한을 둔다. [Player._updateRenderYaw] 와 같은 규칙이다.
  void _updateRenderYaw(double dt) {
    final target = facingYaw(_facing);
    if (!_renderYawPrimed) {
      _renderYaw = target;
      _renderYawPrimed = true;
      return;
    }
    var delta = (target - _renderYaw) % (math.pi * 2);
    if (delta > math.pi) delta -= math.pi * 2;
    if (delta < -math.pi) delta += math.pi * 2;

    final maxStep = _renderTurnRate * dt;
    _renderYaw += delta.clamp(-maxStep, maxStep);
  }

  @override
  void render(Canvas canvas) {
    if (!_alive) return;

    renderShadow(canvas, 22, radiusY: 11);
    _renderAllyRing(canvas);

    final running = _speed > _runThreshold;
    final cycle = _animTime * 9;
    final swing = running ? math.sin(cycle) : 0.0;
    final bob = running
        ? math.sin(cycle * 2) * 2.0 * design.bobScale
        : math.sin(_animTime * 2) * 1.2;

    CyborgRenderer.drawBody(
      canvas,
      design: design,
      yaw: _renderYaw,
      baseY: -bob,
      swing: swing,
      armSwing: running ? -swing * 6 : 0,
      time: _animTime,
      // 등에 멘 무기는 레벨에서 그대로 유도된다. 서버가 실어 보내는 것은 누적
      // 경험치뿐이지만 등급도 계통도 레벨의 함수라(`WeaponSystem.forLevel`),
      // 저쪽 요원이 지금 무엇을 들었는지가 레벨 하나로 정확히 그려진다.
      // PK 가 허용된 월드에서는 붙기 전에 알아야 하는 정보다.
      weapon: WeaponSystem.forLevel(_level),
    );

    _renderNameplate(canvas);
  }

  /// 발밑의 옅은 링. 남을 나와 구분하는 표식이다.
  ///
  /// 몸은 같은 렌더러로 그리므로 실루엣만으로는 내 캐릭터와 구분되지 않는다.
  /// 이름표는 머리 위에 있어 발밑을 보고 있을 때는 눈에 들어오지 않는다.
  void _renderAllyRing(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 46, height: 23),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = GamePalette.playerAccent.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  /// 머리 위의 이름과 레벨.
  void _renderNameplate(Canvas canvas) {
    final painter = _nameplate ??= _buildNameplate();
    final top = -(design.totalHeight + 22);

    // 밝은 데이터 공간이 배경이라 흰 글자는 묻힌다. 어두운 판을 깔아 띄운다.
    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        -painter.width / 2 - 6,
        top - 2,
        painter.width + 12,
        painter.height + 4,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      box,
      Paint()..color = GamePalette.playerArmor.withValues(alpha: 0.72),
    );
    painter.paint(canvas, Offset(-painter.width / 2, top));
  }

  TextPainter _buildNameplate() {
    return TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: _name.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              height: 1,
            ),
          ),
          TextSpan(
            text: '  Lv.$_level',
            style: TextStyle(
              color: GamePalette.playerVisor.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }
}
