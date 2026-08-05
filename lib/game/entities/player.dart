import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../audio/game_audio.dart';
import '../fx/damage_text.dart';
import '../fx/hit_spark.dart';
import '../iso.dart';
import '../level/level_map.dart';
import '../palette.dart';
import '../systems/buff.dart';
import '../systems/inventory.dart';
import '../systems/level_system.dart';
import '../systems/rest_recovery.dart';
import '../systems/weapon.dart';
import 'cyborg_design.dart';
import 'cyborg_renderer.dart';
import 'iso_entity.dart';
import 'pickup.dart';
import 'projectile.dart';
import 'weapon_art.dart';

/// 플레이어의 현재 행동 상태.
enum PlayerState { idle, run, melee, dash, hurt, dead }

/// 인간 저항군 사이보그. 플레이어가 조작하는 캐릭터.
class Player extends IsoEntity with Damageable {
  Player({
    required Vector2 grid,
    this.design = CyborgDesign.assault,
  }) : super(grid: grid, bodyRadius: 0.28, depthBias: 0.02);

  /// 이 플레이어가 쓰는 신체 프레임.
  ///
  /// 캐릭터 선택 화면에서 고른 몸이 그대로 넘어온다. 선택 화면·프리뷰와
  /// 같은 [CyborgRenderer]로 그리므로 고른 몸과 조종하는 몸이 어긋나지 않는다.
  final CyborgDesign design;

  // ── 스탯 ────────────────────────────────────────────────────────────
  // 사이보그의 몸체는 수천 단위의 내구도를 갖는다. 수리액 한 병으로는
  // 극히 일부만 메워지므로 회복은 꾸준히 이어 마셔야 한다.
  /// 1레벨 사이보그의 몸체 내구도.
  ///
  /// 몬스터가 주는 피해가 곧 그 몬스터의 레벨이므로(1~200), 이 값은
  /// "레벨 N 몬스터에게 몇 대까지 버티는가"를 그대로 뜻한다.
  static const double baseMaxHp = 2500;

  double _hp = baseMaxHp;
  double _maxHp = baseMaxHp;
  double energy = 100;
  double maxEnergy = 100;

  // 마력 회로. 스킬을 넉넉히 쓰도록 용량을 크게 잡았고, 야전에서는 거의
  // 차지 않아 안전지대나 아지트로 물러나 쉬어야 채워진다.
  double mp = 5000;
  double _maxMp = 5000;
  /// 지금까지 얻은 경험치의 총합. **성장에 관한 유일한 진실이다.**
  ///
  /// 아래 [level]·[xp] 는 여기서 나오는 파생값이고, 서버에 올리는 것도 이 값
  /// 하나다. 셋을 따로 관리하면 서로 어긋난 상태가 생기지만, 하나만 관리하고
  /// 나머지를 계산하면 그런 상태 자체가 만들어지지 않는다.
  int totalXp = 0;

  /// 지금 레벨. [totalXp] 에서 유도한 값이다.
  int level = 1;

  /// 지금 레벨 안에서 다음 레벨까지 쌓은 진행도. [totalXp] 에서 유도한 값이다.
  int xp = 0;

  int xpToNextLevel = LevelSystem.xpToNext(1);
  double meleeDamage = 26;
  double rangedDamage = 18;
  double moveSpeed = 3.6; // 초당 타일 수

  /// 맨몸의 기본 무기. **레벨이 오르면 함께 강화된다.**
  ///
  /// 저장하지 않고 [level] 에서 만들어 낸다 — [totalXp] 하나로 레벨과 진행도를
  /// 유도하는 것과 같은 이유다. 서버가 주고받는 것도 누적 경험치뿐이라, 이
  /// 무기는 같은 월드의 모든 클라이언트가 똑같이 그려 낼 수 있다.
  Weapon _innate = WeaponSystem.forLevel(1);

  /// 로봇 잔해에서 주워 든 무기. 아무것도 줍지 않았으면 null이다.
  ///
  /// 이쪽은 서버가 모르는 값이라 남의 화면에는 [_innate] 로 보인다
  /// (`GAME-DESIGN.md` 12.4 참고).
  Weapon? _found;

  /// 지금 실제로 손에 든 무기.
  ///
  /// **기본 무기와 주운 무기 중 센 쪽이다.** 어느 하나를 "장착 상태"로 따로
  /// 들고 있지 않는 것이 요점이다 — 그러면 레벨이 자라 기본 무기가 주운 것을
  /// 앞질렀는데도 옛 무기를 든 상태가 생기고, 그 어긋남을 지우려면 레벨업마다
  /// 장착을 다시 손봐야 한다. 매번 견주면 그런 상태 자체가 없다.
  Weapon get weapon {
    final found = _found;
    return found != null && found.dps > _innate.dps ? found : _innate;
  }

  /// 주운 무기를 든다. 지금 든 것보다 세지 않으면 들지 않고 false.
  ///
  /// 견주는 값이 위력이 아니라 [Weapon.dps] 인 것이 요점이다. 위력만 보면
  /// 느리게 한 대씩 때리는 망치가 언제나 이겨, 계통이 맞바꿈이 아니라 서열이
  /// 된다. 속도와 콤보까지 곱한 값으로 견주면 계통은 서로 대등해지고, 실제로
  /// 무기를 가르는 것은 레벨과 벼림이 된다.
  bool equipFoundWeapon(Weapon dropped) {
    if (dropped.dps <= weapon.dps) return false;
    _found = dropped;
    return true;
  }

  /// 방어력. 받는 피해를 [defenseConstant] 기준의 승수로 깎는다.
  ///
  /// 기본값은 0이며, 이때 받는 피해는 때린 몬스터의 레벨과 정확히 같다.
  /// 지금은 올릴 방법이 없다 — 성장·장비·버프 중 어디에 붙일지 정해지지
  /// 않았기 때문이다. 축만 먼저 세워 둔다.
  double defense = 0;

  /// 방어력이 이 값과 같아지면 받는 피해가 절반이 된다.
  ///
  /// 감산형(`피해 - 방어력`)이 아니라 승수형을 쓰는 이유는 몬스터 레벨이
  /// 1~200으로 넓고 구역마다 레벨대가 묶여 배치되기 때문이다. 감산형이면
  /// 방어력이 조금만 올라도 저레벨 구역 하나가 통째로 무해해진다.
  /// 값 자체는 잠정이다 — 방어력을 얻는 경로가 생기면 그때 역산한다.
  static const double defenseConstant = 100;

  /// 바닥의 전리품을 자동으로 끌어당기는 반경(타일 단위).
  double lootRadius = 2.8;

  /// 포션으로 얻은 강화 효과들.
  final BuffSet buffs = BuffSet();

  /// 안전지대·아지트에서 쉬는 동안의 회복을 맡는다.
  final RestRecovery rest = RestRecovery();

  @override
  double get hp => _hp;

  /// 마력 최대치.
  double get maxMp => _maxMp;

  /// 지금 거점에서 쉬며 회복하는 중인지.
  bool get isResting => rest.isRecovering;

  @override
  double get maxHp => _maxHp;

  /// 무기 위력과 버프가 반영된 근접 피해량.
  ///
  /// 계통의 몫이 여기에만 곱해진다. 망치의 ×1.32 는 한 대가 크다는 뜻이지
  /// 캐릭터가 강하다는 뜻이 아니다 — 그만큼 느리게 휘두르므로 초당 피해는
  /// 다른 계통과 같다([WeaponClass] 참고).
  double get effectiveMeleeDamage =>
      meleeDamage *
      weapon.power *
      weapon.weaponClass.damage *
      buffs.damageMultiplier;

  /// 무기 위력과 버프가 반영된 원거리 피해량.
  ///
  /// 플라즈마 볼트도 같은 무기에서 나간다. 칼과 총을 따로 두지 않는 이유는
  /// 이 사이보그의 팔 자체가 무기이기 때문이다 — 칼날을 뽑는 것과 볼트를
  /// 쏘는 것은 같은 방출기의 두 가지 출력이다.
  double get effectiveRangedDamage =>
      rangedDamage * weapon.power * buffs.damageMultiplier;

  /// 무기가 더해 준 몫까지 포함한 실제 근접 사거리(타일).
  ///
  /// 자동 사냥이 접근 거리를 정할 때도 이 값을 읽는다. [meleeRange] 를 직접
  /// 쓰면 무기가 길어진 만큼 필요 없이 더 붙는다.
  double get meleeReach => meleeRange + weapon.reachBonus;

  /// 버프가 반영된 이동 속도.
  double get effectiveMoveSpeed => moveSpeed * buffs.speedMultiplier;

  // ── 상태 ────────────────────────────────────────────────────────────
  PlayerState state = PlayerState.idle;

  /// 그리드 좌표계 기준의 입력 방향(정규화 전).
  final Vector2 moveInput = Vector2.zero();

  /// 마지막으로 바라본 방향(그리드 좌표계).
  final Vector2 facing = Vector2(1, 1)..normalize();

  /// 클릭·탭으로 지정한 이동 목표(그리드 좌표). null이면 수동 조작만 따른다.
  Vector2? moveTarget;

  /// 목표를 향하는데 나아가지 못한 시간. 벽에 끼었는지 판정한다.
  double _stuckTime = 0;

  /// **그리는 데만** 쓰는 시선각(라디안).
  ///
  /// [facing]은 입력을 즉시 반영해야 한다 — 근접 판정·사격·대시가 모두 그
  /// 값을 읽으므로, 보간을 걸면 "보이는 방향으로 안 때리는" 조작이 된다.
  /// 대신 그림만 각속도 상한을 두고 따라오게 해서 한 프레임에 180° 홱 도는
  /// 것을 막는다.
  double _renderYaw = 0;
  bool _renderYawPrimed = false;

  /// 그림이 목표 방향을 따라잡는 최대 각속도(라디안/초).
  ///
  /// 낮추면 부드럽지만 조작이 굼떠 보인다. 0.1초 안에 반 바퀴를 돌 수 있는
  /// 수준이라 체감 지연은 거의 없다.
  static const double _renderTurnRate = 14.0;

  final Vector2 _velocity = Vector2.zero();
  final Vector2 _knockback = Vector2.zero();

  double _animTime = 0;
  double _meleeTimer = 0;

  /// 지금 휘두르는 한 번에 걸리는 시간. 무기 계통의 속도에서 나온다.
  double _meleeSpan = _meleeDuration;
  double _meleeCooldown = 0;
  double _shootCooldown = 0;
  double _dashTimer = 0;
  double _dashCooldown = 0;
  double _invulnerable = 0;
  double _hazardTick = 0;
  double _deathTimer = 0;
  double _stepTimer = 0;
  int _comboStep = 0;
  double _comboWindow = 0;
  bool _meleeHitApplied = false;
  final List<_DashGhost> _ghosts = [];

  static const double _meleeDuration = 0.32;

  /// 맨몸의 근접 사거리(타일). 대상의 몸 반경은 여기에 더해 판정한다.
  ///
  /// 실제로 닿는 거리는 무기 길이가 더해진 [meleeReach] 다. 판정도 자동
  /// 사냥의 접근 거리도 그쪽을 읽어야 한다 — 둘이 어긋나면 닿지도 않는
  /// 자리에서 계속 헛스윙한다.
  static const double meleeRange = 1.5;
  /// 대시가 지속되는 시간. [_dashSpeed] 와 곱한 만큼(약 3.4 타일) 미끄러진다.
  ///
  /// 무적 시간도 여기서 파생되므로(대시 시간 + 0.08) 이 값을 늘리면 PK 에서
  /// 회피로 버티는 구간도 같이 길어진다.
  static const double _dashDuration = 0.26;
  static const double _dashSpeed = 13.0;

  bool get isDashing => _dashTimer > 0;
  bool get isInvulnerable => _invulnerable > 0;
  double get dashCooldownRatio =>
      (_dashCooldown / 0.9).clamp(0.0, 1.0).toDouble();

  // ── 입력 진입점 ─────────────────────────────────────────────────────

  /// 근접 공격을 시도한다. 무엇을 어떻게 휘두를지는 무기 계통이 정한다.
  void tryMelee() {
    if (!isAlive || _meleeCooldown > 0 || isDashing) return;
    final weaponClass = weapon.weaponClass;
    _comboStep =
        _comboWindow > 0 ? (_comboStep + 1) % weaponClass.comboLength : 0;
    _comboWindow = 0.65;
    // 계통마다 한 번의 스윙에 걸리는 시간이 다르다. 시작할 때 재어 두는 이유는
    // 휘두르는 도중에 무기가 바뀌어도 이번 스윙의 진행도가 튀지 않게 하기
    // 위해서다 — 그림과 판정 시점이 같은 값을 봐야 한다.
    _meleeSpan = _meleeDuration / weaponClass.speed;
    _meleeTimer = _meleeSpan;
    _meleeCooldown = _meleeSpan + 0.06;
    _meleeHitApplied = false;
    state = PlayerState.melee;
    // 콤보 마무리는 더 묵직한 스윙음으로 구분한다. 망치는 매 타가 묵직하다.
    GameAudio.play(
      _isFinisher || weaponClass == WeaponClass.maul
          ? Sfx.bladeSwingHeavy
          : Sfx.bladeSwing,
    );
  }

  /// 지금 타가 콤보의 마무리인지. 계통마다 콤보 길이가 다르다.
  bool get _isFinisher => _comboStep == weapon.weaponClass.comboLength - 1;

  /// 한 발에 드는 마력.
  ///
  /// 1레벨 마력 5,000으로 약 83발을 쏠 수 있다. 사냥 한 바퀴를 넉넉히
  /// 돌 만큼이되, 무한정 난사하면 거점으로 돌아가 쉬어야 한다.
  static const double plasmaMpCost = 60;

  /// 플라즈마 볼트를 발사한다. 마력을 쓴다.
  void tryShoot() {
    if (!isAlive || _shootCooldown > 0) return;
    if (mp < plasmaMpCost) {
      GameAudio.play(Sfx.uiError);
      return;
    }
    _shootCooldown = 0.24;
    mp -= plasmaMpCost;
    final dir = facing.clone()..normalize();
    game.spawnProjectile(
      Projectile(
        grid: grid + dir * 0.4,
        direction: dir,
        speed: 9.5,
        damage: effectiveRangedDamage,
        owner: ProjectileOwner.player,
        z: 0.62,
        // 볼트도 같은 방출기에서 나가므로 무기 색을 그대로 띤다.
        color: weapon.glow,
      ),
    );
    game.shakeCamera(2.5, 0.08);
    GameAudio.play(Sfx.plasmaShot);
  }

  /// 회피 대시를 시도한다.
  void tryDash() {
    if (!isAlive || _dashCooldown > 0) return;
    if (energy < 20) {
      GameAudio.play(Sfx.uiError);
      return;
    }
    if (moveInput.length2 > 0.01) {
      facing.setFrom(moveInput.normalized());
    }
    energy -= 20;
    _dashTimer = _dashDuration;
    _dashCooldown = 0.9;
    _invulnerable = math.max(_invulnerable, _dashDuration + 0.08);
    state = PlayerState.dash;
    GameAudio.play(Sfx.dash);
  }

  // ── 갱신 ────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    _animTime += dt;
    _tickTimers(dt);

    // 거리에 따른 소리 감쇠는 플레이어를 기준으로 계산한다.
    GameAudio.listener = grid;

    if (!isAlive) {
      _deathTimer += dt;
      super.update(dt);
      return;
    }

    buffs.update(dt);
    energy = math.min(
      maxEnergy,
      energy + dt * 16 * buffs.energyRegenMultiplier,
    );
    _updateRest(dt);

    _updateMovement(dt);
    _updateRenderYaw(dt);
    _updateSteps(dt);
    _updateMelee();
    _updateHazard(dt);
    _updateGhosts(dt);

    super.update(dt);
  }

  /// 거점 안에서 쉬는 동안 체력과 마력을 채운다.
  ///
  /// 지금 거점은 월드 한가운데의 안전지대뿐이다. 아지트가 생기면
  /// 판정만 넓히면 되고 회복 규칙은 그대로 쓴다.
  void _updateRest(double dt) {
    rest.update(dt, sheltered: game.map.safeZone.containsPoint(grid));

    final hpGain = rest.hpGain(dt, _maxHp);
    if (hpGain > 0) _hp = math.min(_maxHp, _hp + hpGain);

    final mpGain = rest.mpGain(dt, _maxMp);
    if (mpGain > 0) mp = math.min(_maxMp, mp + mpGain);
  }

  /// 이동 속도에 맞춰 발소리 간격을 조절한다.
  void _updateSteps(double dt) {
    final speed = _velocity.length;
    if (isDashing || speed < 0.5) {
      // 멈췄다가 다시 걸으면 곧바로 첫 발소리가 나도록 짧게 남겨 둔다.
      _stepTimer = 0.1;
      return;
    }
    _stepTimer -= dt;
    if (_stepTimer <= 0) {
      // 다리 애니메이션(_animTime * 9)의 반주기에 맞춘 간격.
      _stepTimer = (1.26 / speed).clamp(0.18, 0.5);
      GameAudio.play(Sfx.step);
    }
  }

  void _tickTimers(double dt) {
    if (_meleeTimer > 0) _meleeTimer -= dt;
    if (_meleeCooldown > 0) _meleeCooldown -= dt;
    if (_shootCooldown > 0) _shootCooldown -= dt;
    if (_dashCooldown > 0) _dashCooldown -= dt;
    if (_invulnerable > 0) _invulnerable -= dt;
    if (_comboWindow > 0) _comboWindow -= dt;
    if (_dashTimer > 0) {
      _dashTimer -= dt;
      if (_dashTimer <= 0 && state == PlayerState.dash) {
        state = PlayerState.idle;
      }
    }
  }

  void _updateMovement(double dt) {
    if (isDashing) {
      _velocity
        ..setFrom(facing)
        ..normalize()
        ..scale(_dashSpeed);
      if (_ghosts.length < 12) {
        _ghosts.add(_DashGhost(grid.clone(), facing.clone()));
      }
    } else if (moveInput.length2 > 0.001) {
      // 키보드·조이스틱이 들어오면 클릭 목표를 버린다. 손으로 잡은 조작이
      // 항상 이긴다.
      clearMoveTarget();
      final dir = moveInput.normalized();
      facing.setFrom(dir);
      final speedFactor = state == PlayerState.melee ? 0.35 : 1.0;
      _velocity
        ..setFrom(dir)
        ..scale(effectiveMoveSpeed * speedFactor);
      if (state != PlayerState.melee) state = PlayerState.run;
    } else if (moveTarget != null) {
      _steerToTarget();
    } else {
      _velocity.setZero();
      if (state == PlayerState.run) state = PlayerState.idle;
    }

    // 넉백은 지수적으로 감쇠시킨다.
    if (_knockback.length2 > 0.0001) {
      _velocity.add(_knockback);
      _knockback.scale(math.max(0, 1 - dt * 9));
    }

    final before = grid.clone();
    _moveWithCollision(_velocity * dt);

    // 목표를 향하는데 실제로 나아가지 못하면(벽에 막힘) 오래 붙어 있지 않고
    // 목표를 버린다. 경로 탐색 없이도 캐릭터가 벽에 비비지 않게 하는 장치다.
    if (moveTarget != null && !isDashing) {
      final progressed = (grid - before).length;
      if (progressed < effectiveMoveSpeed * dt * 0.25) {
        _stuckTime += dt;
        if (_stuckTime > 0.35) clearMoveTarget();
      } else {
        _stuckTime = 0;
      }
    }
  }

  /// 클릭으로 지정한 지점을 향해 방향과 속도를 잡는다.
  void _steerToTarget() {
    final target = moveTarget!;
    final to = target - grid;
    // 목표에 충분히 가까우면 멈춘다. 반경을 두지 않으면 목표 위에서 떨린다.
    if (to.length < 0.18) {
      clearMoveTarget();
      _velocity.setZero();
      if (state == PlayerState.run) state = PlayerState.idle;
      return;
    }

    final dir = to.normalized();
    facing.setFrom(dir);
    final speedFactor = state == PlayerState.melee ? 0.35 : 1.0;
    // 목표 직전에는 속도를 줄여 부드럽게 선다.
    final arrive = to.length < 0.6 ? to.length / 0.6 : 1.0;
    _velocity
      ..setFrom(dir)
      ..scale(effectiveMoveSpeed * speedFactor * arrive);
    if (state != PlayerState.melee) state = PlayerState.run;
  }

  /// 클릭·탭으로 [target](그리드 좌표)까지 걸어가게 한다.
  ///
  /// 경로 탐색은 하지 않는다. 직선으로 향하되 벽에는 기존 슬라이딩 충돌로
  /// 미끄러지고, 그래도 나아가지 못하면 스스로 목표를 버린다.
  void moveTo(Vector2 target) {
    if (!isAlive) return;
    moveTarget = target.clone();
    _stuckTime = 0;
  }

  /// 진행 중인 클릭 이동을 취소한다.
  void clearMoveTarget() {
    moveTarget = null;
    _stuckTime = 0;
  }

  /// 제자리에서 [point] 쪽으로 몸을 돌린다.
  ///
  /// 근접 공격은 전방 약 120° 부채꼴만 때리는데, 멈춰 서 있으면 [facing] 은
  /// 갱신되지 않는다([_updateMovement] 는 이동할 때만 방향을 잡는다). 자동
  /// 사냥처럼 붙어서 멈춘 뒤 때리는 경우 이 메서드로 방향을 맞추지 않으면
  /// 옆이나 등 뒤의 대상을 향해 계속 헛스윙한다.
  void faceTowards(Vector2 point) {
    if (!isAlive) return;
    final to = point - grid;
    if (to.length2 < 1e-6) return;
    facing.setFrom(to.normalized());
  }

  /// 축을 분리해 이동시켜 벽을 따라 미끄러지도록 한다.
  void _moveWithCollision(Vector2 delta) {
    final map = game.map;
    final r = bodyRadius;

    bool free(double gx, double gy) {
      return map.isWalkableAt(gx - r, gy - r) &&
          map.isWalkableAt(gx + r, gy - r) &&
          map.isWalkableAt(gx - r, gy + r) &&
          map.isWalkableAt(gx + r, gy + r);
    }

    if (delta.x != 0 && free(grid.x + delta.x, grid.y)) {
      grid.x += delta.x;
    }
    if (delta.y != 0 && free(grid.x, grid.y + delta.y)) {
      grid.y += delta.y;
    }
  }

  void _updateMelee() {
    if (state != PlayerState.melee) return;
    if (_meleeTimer <= 0) {
      state = moveInput.length2 > 0.001 ? PlayerState.run : PlayerState.idle;
      return;
    }
    // 스윙 중반에 한 번만 판정한다. 망치는 머리가 바닥에 닿는 순간이라 늦다 —
    // 그림이 그 시점을 그리므로 판정도 같은 값을 읽어야 한다.
    final progress = 1 - (_meleeTimer / _meleeSpan);
    final hitAt = weapon.weaponClass == WeaponClass.maul
        ? WeaponArt.maulImpact
        : 0.35;
    if (!_meleeHitApplied && progress >= hitAt) {
      _meleeHitApplied = true;
      _resolveMeleeHit();
    }
  }

  void _resolveMeleeHit() {
    final dir = facing.normalized();
    final finisher = _isFinisher;
    final comboBonus = finisher ? 1.6 : 1.0;
    final damage = effectiveMeleeDamage * comboBonus;
    final reach = meleeReach;
    // 부채꼴의 넓이는 계통이 정한다. 창은 겨눈 하나만, 리퍼는 사방을 친다.
    final arcDot = weapon.weaponClass.arcDot;
    var hitAny = false;

    for (final target in game.meleeTargets()) {
      // 목록은 스냅샷이다. 앞선 대상을 때려 죽인 뒤에도 계속 돌기 때문에,
      // 이미 쓰러진 대상은 여기서 걸러야 시체에 타격 이펙트가 남지 않는다.
      if (!target.isAlive) continue;
      final toTarget = target.grid - grid;
      final distance = toTarget.length;
      if (distance > reach + target.bodyRadius) continue;
      if (distance > 0.001) {
        final alignment = toTarget.normalized().dot(dir);
        if (alignment < arcDot) continue;
      }
      hitAny = true;
      final knock = distance > 0.001 ? toTarget.normalized() : dir;
      target.applyDamage(
        damage,
        knockback: knock * (finisher ? 3.4 : 1.9),
        critical: finisher,
      );
      game.spawnEffect(
        HitSpark(
          grid: target.grid.clone(),
          z: 0.55,
          // 불꽃도 지금 든 무기의 색으로 튄다. 칼날만 바뀌고 타격 불꽃이
          // 옛 색이면 두 그림이 서로 다른 무기를 말하게 된다.
          color: weapon.glow,
        ),
      );
    }

    if (hitAny) {
      // 망치의 착탄은 그 자체가 사건이라 흔들림을 한 단 더 준다.
      final heavy = finisher || weapon.weaponClass == WeaponClass.maul;
      game.shakeCamera(heavy ? 8 : 4, 0.12);
      energy = math.min(maxEnergy, energy + 4);
      GameAudio.play(finisher ? Sfx.meleeCrit : Sfx.meleeHit);
    }
  }

  void _updateHazard(double dt) {
    final tile = game.map.tileAt(grid.x.floor(), grid.y.floor());
    if (tile != TileType.hazard) {
      _hazardTick = 0;
      return;
    }
    GameAudio.play(Sfx.hazardBurn);
    _hazardTick += dt;
    if (_hazardTick >= 0.5) {
      _hazardTick = 0;
      // 방화벽은 무적도 방어력도 무시한다. 지형 위험은 장갑으로 버티는 것이
      // 아니라 밟지 않고 지나가는 것이다. 피해량은 몬스터 레벨과 무관한
      // 별도 축이므로 최대 체력에 비례해 정한다(1초에 약 8%).
      applyDamage(
        _maxHp * 0.04,
        ignoreInvulnerable: true,
        ignoreDefense: true,
      );
    }
  }

  void _updateGhosts(double dt) {
    for (final ghost in _ghosts) {
      ghost.life -= dt * 3.2;
    }
    _ghosts.removeWhere((ghost) => ghost.life <= 0);
  }

  // ── 피해 / 성장 ─────────────────────────────────────────────────────

  /// 방어력을 적용하고 남은 피해.
  ///
  /// 방어력이 0이면 들어온 값을 그대로 돌려준다 — "레벨 N 몬스터는 N" 이라는
  /// 규격이 성립하는 지점이다.
  ///
  /// 상태에 기대지 않는 순수 함수로 두었다. 전투를 서버 권위로 옮길 때
  /// 이 함수만 Rust 로 옮기면 되고, 지금은 게임 객체 없이 테스트할 수 있다.
  static double damageAfterDefense(double amount, double defense) {
    if (defense <= 0) return amount;
    return amount * defenseConstant / (defenseConstant + defense);
  }

  @override
  void applyDamage(
    double amount, {
    Vector2? knockback,
    bool critical = false,
    bool ignoreInvulnerable = false,
    bool ignoreDefense = false,
  }) {
    if (!isAlive) return;
    if (!ignoreInvulnerable && (isInvulnerable || isDashing)) return;
    // 안전지대 안에서는 어떤 피해도 통하지 않는다. 재접속 직후의 무방비
    // 상태를 지켜 주는 것이 이 구역의 존재 이유다.
    if (game.map.isInSafeZone(grid.x, grid.y)) return;

    // 방어력 → 버프 순으로 깎은 뒤 마지막에 한 번만 정수로 만든다.
    //
    // 정수화를 한 번만 하는 이유는 HP에서 깎이는 값과 화면에 뜨는 숫자와
    // 피격음 크기가 모두 같은 값이어야 하기 때문이다. 중간에서 반올림하면
    // 방어력이나 장갑 경화가 걸렸을 때 표시와 실제가 어긋난다.
    final afterDefense =
        ignoreDefense ? amount : damageAfterDefense(amount, defense);
    final taken = (afterDefense * buffs.damageTakenMultiplier).roundToDouble();

    _hp = math.max(0, _hp - taken);
    _invulnerable = math.max(_invulnerable, 0.55);
    if (knockback != null) _knockback.add(knockback);
    // 얻어맞자마자 거점으로 뛰어들어 즉시 회복하는 것을 막는다.
    rest.notifyDamaged();

    game.spawnEffect(
      DamageText(
        grid: grid.clone(),
        z: 1.0,
        amount: taken,
        color: GamePalette.hpFillLow,
      ),
    );
    game.shakeCamera(9, 0.2);
    game.onPlayerDamaged();

    if (_hp <= 0) {
      state = PlayerState.dead;
      GameAudio.play(Sfx.playerDeath);
      // 이 세계에 게임 오버는 없다. 게임 본체가 곧바로 안전지대에서
      // 재가동시킨다.
      game.onPlayerDied();
    } else {
      // 큰 피해일수록 크게 들리도록 한다.
      GameAudio.play(
        Sfx.playerHurt,
        // 최대 체력 대비로 재야 한다. 고정 분모를 쓰면 체력이 1만인 지금은
        // 어떤 피해를 입어도 항상 최소 볼륨으로 들린다.
        volumeScale: (0.5 + taken / (_maxHp * 0.02)).clamp(0.5, 1.2),
      );
    }
  }

  /// 재가동 직후 유지되는 무적 시간(초).
  ///
  /// 안전지대 안은 어차피 무적이지만, 밖으로 걸어 나가는 순간 대기하던
  /// 로봇에게 즉사하지 않도록 짧은 유예를 준다.
  static const double respawnInvulnerability = 2.0;

  /// [point]에서 즉시 재가동한다.
  ///
  /// 사망 직후 게임 본체가 안전지대 좌표를 넘겨 호출한다. 죽은 것은 몸체일
  /// 뿐이고 의식은 백업되어 있으므로, 레벨·경험치·버프는 그대로 두고
  /// 전투 상태만 되돌린다.
  void respawnAt(Vector2 point) {
    grid.setFrom(point);
    _hp = _maxHp;
    energy = maxEnergy;
    mp = _maxMp;
    rest.reset();
    state = PlayerState.idle;

    moveInput.setZero();
    _velocity.setZero();
    _knockback.setZero();
    _ghosts.clear();
    // 쓰러지기 전에 향하던 클릭 목표는 죽은 자리 근처다. 그대로 두면 재가동
    // 직후 아무도 조작하지 않았는데 혼자 안전지대 밖으로 걸어 나간다.
    clearMoveTarget();

    _deathTimer = 0;
    _meleeTimer = 0;
    _meleeCooldown = 0;
    _shootCooldown = 0;
    _dashTimer = 0;
    _dashCooldown = 0;
    _comboStep = 0;
    _comboWindow = 0;
    _meleeHitApplied = true;
    _hazardTick = 0;
    _invulnerable = respawnInvulnerability;

    // 순간이동이므로 화면 좌표도 이번 프레임에 바로 맞춘다.
    syncTransform();
  }

  /// [point]로 순간이동한다.
  ///
  /// [respawnAt]과 달리 **체력과 에너지를 건드리지 않는다.** 죽어서 새 몸체를
  /// 받는 것이 아니라 멀쩡한 몸으로 자리만 옮기는 것이므로, 회복시켜 주면
  /// 위험할 때마다 텔레포트로 몸을 추스르는 편법이 된다. 같은 이유로 공격·대시
  /// 쿨다운도 그대로 둔다.
  ///
  /// 다만 이동 관성과 진행 중이던 동작은 정리한다. 그러지 않으면 도착하자마자
  /// 떠나온 곳에서 밀리던 방향으로 미끄러진다.
  void teleportTo(Vector2 point) {
    if (!isAlive) return;

    grid.setFrom(point);
    state = PlayerState.idle;

    moveInput.setZero();
    _velocity.setZero();
    _knockback.setZero();
    // 잔상은 떠나온 자리의 것이라 그대로 두면 월드를 가로지르는 선이 된다.
    _ghosts.clear();
    // 떠나온 곳의 클릭 목표도 함께 버린다. 남겨 두면 도착하자마자 왔던
    // 방향으로 되돌아 걷는다.
    clearMoveTarget();

    _dashTimer = 0;
    _meleeTimer = 0;
    _comboStep = 0;
    _comboWindow = 0;
    _meleeHitApplied = true;
    // 밟고 있던 유해 지형의 누적을 새 지형으로 끌고 가지 않는다.
    _hazardTick = 0;

    syncTransform();
  }

  /// 체력을 회복하고 실제로 채워진 양을 돌려준다.
  ///
  /// [showText]가 false면 회복 수치를 띄우지 않는다. 포션처럼 호출한 쪽이
  /// 따로 라벨을 표시할 때 쓴다.
  double heal(double amount, {bool showText = true}) {
    if (!isAlive) return 0;
    final before = _hp;
    _hp = math.min(_maxHp, _hp + amount);
    final healed = _hp - before;
    if (showText && healed > 0) {
      game.spawnEffect(
        DamageText(
          grid: grid.clone(),
          z: 1.0,
          amount: healed,
          color: GamePalette.healGlow,
          prefix: '+',
        ),
      );
    }
    return healed;
  }

  /// 에너지를 회복하고 실제로 채워진 양을 돌려준다.
  double restoreEnergy(double amount) {
    final before = energy;
    energy = math.min(maxEnergy, energy + amount);
    return energy - before;
  }

  /// 포션 한 개를 마신다. 회복과 강화 효과가 함께 적용된다.
  ///
  /// 인벤토리에서 개수를 줄인 뒤 호출되므로 여기서는 효과만 적용한다.
  PotionUseResult drinkPotion(PickupKind kind, PotionEffect effect) {
    final healed = effect.heal > 0 ? heal(effect.heal, showText: false) : 0.0;
    final energized =
        effect.energy > 0 ? restoreEnergy(effect.energy) : 0.0;

    final buff = effect.buff;
    if (buff != null) buffs.apply(buff);

    // 마시는 순간 몸이 달아오르는 느낌을 준다.
    game.spawnEffect(
      HitSpark(
        grid: grid.clone(),
        z: 0.7,
        color: PickupSpec.table[kind]!.color,
      ),
    );

    return PotionUseResult(
      kind: kind,
      healed: healed,
      energized: energized,
      buffed: buff != null,
    );
  }

  /// 경험치를 획득하고 필요 시 레벨업한다. 한 번에 여러 레벨이 오를 수 있다.
  ///
  /// **만렙이 없다.** 레벨 상한 대신 곡선이 속도를 조절하므로, 경험치는 언제나
  /// 쌓이고 레벨은 언제나 오를 수 있다.
  void gainXp(int amount, {bool showText = true}) {
    if (!isAlive || amount <= 0) return;

    totalXp = math.min(LevelSystem.maxTotalXp, totalXp + amount);
    if (showText) {
      game.spawnEffect(
        DamageText(
          grid: grid.clone(),
          z: 1.25,
          amount: amount.toDouble(),
          color: GamePalette.xpGlow,
          prefix: '+',
        ),
      );
    }

    // 누적에서 새 레벨을 구한다. 몇 레벨이 한꺼번에 올랐든 그 수만큼 연출을
    // 내보내야 하므로 차이만큼 반복한다.
    final reached = LevelSystem.levelForTotalXp(totalXp);
    while (level < reached) {
      _levelUp();
    }
    xp = LevelSystem.progressWithin(totalXp);
  }

  /// 서버에 저장된 성장 상태를 그대로 이어받는다.
  ///
  /// 접속할 때마다 1 레벨로 태어나면 서버는 이미 더 많은 누적을 알고 있으므로
  /// 뒤로 가는 보고를 전부 버린다 — 아무리 사냥해도 예전 기록을 넘기 전까지
  /// 순위가 미동도 하지 않는다. 그래서 출격 시점에 서버 값을 먼저 채운다.
  ///
  /// 받는 값이 **누적 경험치 하나**인 것이 중요하다. 레벨과 진행도를 따로 받으면
  /// 셋이 어긋난 상태(레벨 20 인데 누적은 3 레벨분)가 만들어질 수 있는데,
  /// 하나만 받아 나머지를 계산하면 그런 상태가 존재할 수 없다.
  ///
  /// [_levelUp] 을 반복해서 부르지 않는 이유도 있다. 그쪽은 배너·효과음·서버
  /// 보고를 함께 일으키므로, 25 레벨 캐릭터로 접속하면 레벨업 연출이 24 번
  /// 터지고 그만큼의 보고가 되돌아 나간다. 여기서는 **스탯만** 맞춘다.
  void restoreProgress({required int totalXp}) {
    this.totalXp = math.max(0, math.min(LevelSystem.maxTotalXp, totalXp));
    final target = LevelSystem.levelForTotalXp(this.totalXp);

    for (var next = level + 1; next <= target; next++) {
      _applyGains(LevelSystem.gainsFor(next));
      level = next;
    }
    xpToNextLevel = LevelSystem.xpToNext(level);
    xp = LevelSystem.progressWithin(this.totalXp);
    // 무기도 함께 따라온다. 25 레벨로 접속했는데 1 레벨 무기를 들고 있으면
    // 스탯은 25 레벨인데 화면에는 초보의 칼이 보인다.
    //
    // 주워 든 무기는 여기서 버린다. 서버가 보관하는 것은 누적 경험치뿐이라
    // 지난 접속에서 주운 무기는 어차피 되살릴 값이 없다.
    _innate = WeaponSystem.forLevel(level);
    _found = null;

    // 복원 직후에는 만신창이가 아니라 온전한 몸으로 시작한다.
    _hp = _maxHp;
    energy = maxEnergy;
    mp = _maxMp;
  }

  /// 레벨 한 단계가 올려 주는 스탯. 성장과 복원이 같은 계산을 쓰게 묶어 둔다.
  void _applyGains(LevelGains gains) {
    _maxHp += gains.maxHp;
    maxEnergy += gains.maxEnergy;
    _maxMp += gains.maxMp;
    meleeDamage += gains.meleeDamage;
    rangedDamage += gains.rangedDamage;
    moveSpeed += gains.moveSpeed;
  }

  void _levelUp() {
    level++;
    final gains = LevelSystem.gainsFor(level);
    _applyGains(gains);
    xpToNextLevel = LevelSystem.xpToNext(level);

    // 레벨업 한 번은 곧 무기 강화 한 번이다. 등급까지 바뀌었는지는 새 무기와
    // 옛 무기를 견줘서 안다 — 경계 레벨을 여기서 다시 세면 표와 어긋난다.
    //
    // 견주는 것은 **실제로 손에 든 무기**다. 주운 무기가 아직 더 세다면 기본
    // 무기의 등급이 올라도 화면의 칼은 그대로이므로, 그때 "무기가 바뀌었다"고
    // 알리면 바뀌지 않은 것을 알리는 셈이 된다.
    final held = weapon;
    _innate = WeaponSystem.forLevel(level);
    final forged = weapon;
    final gradeUp = forged.gradeIndex != held.gradeIndex;

    // 레벨업하면 완전히 회복하고 잠깐 무적이 된다.
    _hp = _maxHp;
    energy = maxEnergy;
    mp = _maxMp;
    _invulnerable = math.max(_invulnerable, 0.6);

    game.spawnEffect(
      HitSpark(
        grid: grid.clone(),
        z: 0.6,
        color: GamePalette.xpGlow,
      ),
    );
    // 새 등급의 무기는 그 무기 색으로 한 번 더 터뜨린다. 경험치 보라색만
    // 쓰면 등급이 바뀐 순간과 그냥 레벨이 오른 순간이 구분되지 않는다.
    if (gradeUp) {
      game.spawnEffect(
        HitSpark(
          grid: grid.clone(),
          z: 0.75,
          color: forged.glow,
          count: 12,
          spread: 40,
        ),
      );
    }
    GameAudio.play(Sfx.levelUp);
    // 배너와 화면 흔들림 등 연출은 게임 본체가 담당한다.
    game.onLevelUp(level, milestone: gains.milestone, weaponGradeUp: gradeUp);
  }

  // ── 렌더링 ──────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    renderShadow(canvas, 22, radiusY: 11);

    for (final ghost in _ghosts) {
      _renderGhost(canvas, ghost);
    }

    if (!isAlive) {
      _renderDeath(canvas);
      return;
    }

    if (!buffs.isEmpty) _renderBuffAura(canvas);

    // 피격 무적 중 깜빡임.
    final blink = isInvulnerable && !isDashing;
    if (blink && (_animTime * 18).floor().isEven) {
      return;
    }

    _drawFrame(canvas);

    if (state == PlayerState.melee) {
      _renderWeaponSwing(canvas);
    }
  }

  /// 포션 강화 중임을 알리는 발밑 링과 떠오르는 입자.
  void _renderBuffAura(Canvas canvas) {
    for (final buff in buffs.active) {
      final color = buff.spec.color;
      // 효과가 끝나갈수록 옅어져 남은 시간을 짐작할 수 있게 한다.
      final fade = buff.ratio < 0.25 ? buff.ratio / 0.25 : 1.0;
      final pulse = 0.75 + math.sin(_animTime * 6) * 0.25;

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: 58 + pulse * 8,
          height: 29 + pulse * 4,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = color.withValues(alpha: 0.45 * fade * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );

      // 몸을 따라 올라가는 작은 입자 세 개.
      for (var i = 0; i < 3; i++) {
        final phase = (_animTime * 0.8 + i / 3) % 1.0;
        final radius = 22 - phase * 6;
        final angle = phase * math.pi * 2 + i * 2.1;
        canvas.drawCircle(
          Offset(math.cos(angle) * radius, -phase * 72),
          2.2 * (1 - phase),
          Paint()..color = color.withValues(alpha: 0.7 * fade * (1 - phase)),
        );
      }
    }
  }

  void _renderGhost(Canvas canvas, _DashGhost ghost) {
    final offset = gridToScreen(ghost.grid.x, ghost.grid.y, z) -
        gridToScreen(grid.x, grid.y, z);
    canvas.save();
    canvas.translate(offset.x, offset.y);
    canvas.saveLayer(
      Rect.fromCenter(center: const Offset(0, -50), width: 140, height: 160),
      Paint()
        ..color = GamePalette.playerAccent
            .withValues(alpha: (ghost.life * 0.45).clamp(0.0, 0.45))
        ..colorFilter = ColorFilter.mode(
          GamePalette.playerAccent,
          BlendMode.srcATop,
        ),
    );
    _drawFrame(canvas, yaw: facingYaw(ghost.facing));
    canvas.restore();
    canvas.restore();
  }

  /// 사이보그 본체. 원점은 발밑, 화면 정렬(빌보드)로 그린다.

  /// 사이보그 본체를 [dir] 방향으로 그린다.
  ///
  /// 캐릭터 선택 화면·프리뷰와 **같은 [CyborgRenderer]** 를 쓴다. 방향은
  /// 8방향 같은 이산값이 아니라 [facingYaw]가 주는 **연속 각도**라, 몸이
  /// 도는 동안 눈에 띄는 계단이 생기지 않는다.
  /// 렌더용 시선각을 [facing] 쪽으로 각속도 상한 안에서 굴린다.
  void _updateRenderYaw(double dt) {
    final target = facingYaw(facing);
    if (!_renderYawPrimed) {
      _renderYaw = target;
      _renderYawPrimed = true;
      return;
    }
    // 각도 차이를 -π~π 로 접어야 359°→1° 전환에서 한 바퀴를 되돌지 않는다.
    var delta = (target - _renderYaw) % (math.pi * 2);
    if (delta > math.pi) delta -= math.pi * 2;
    if (delta < -math.pi) delta += math.pi * 2;

    final maxStep = _renderTurnRate * dt;
    _renderYaw += delta.clamp(-maxStep, maxStep);
  }

  /// 본체를 그린다.
  ///
  /// [yaw]를 주면 그 각도로, 없으면 보간된 [_renderYaw]로 그린다. 대시 잔상은
  /// 남긴 순간의 방향을 그대로 써야 하므로 직접 넘긴다.
  void _drawFrame(Canvas canvas, {double? yaw}) {
    final running = state == PlayerState.run || isDashing;
    final cycle = _animTime * (isDashing ? 20 : 9);
    final swing = running ? math.sin(cycle) : 0.0;
    final bob = running
        ? math.sin(cycle * 2) * 2.0 * design.bobScale
        : math.sin(_animTime * 2) * 1.2;

    CyborgRenderer.drawBody(
      canvas,
      design: design,
      yaw: yaw ?? _renderYaw,
      baseY: -bob,
      swing: swing,
      armSwing: running ? -swing * 6 : 0,
      time: _animTime,
      // 등에 멘 칼과 손의 방출기가 지금 등급을 그대로 드러낸다. 휘두를 때만
      // 등급이 보이면 서 있는 다른 플레이어의 무기는 알 수 없다.
      weapon: weapon,
    );
  }

  /// 근접 공격의 궤적.
  ///
  /// 실제로 그리는 일은 [WeaponArt] 가 맡는다. 계통마다 궤적의 성격이 통째로
  /// 다르므로(베기·내리찍기·찌르기·회전) 여기서는 **언제 어느 방향으로** 휘두르는
  /// 중인지만 정해 넘긴다. 길이·굵기·색·표면 무늬는 모두 [weapon] 에서 읽히므로,
  /// 무기가 바뀌는 순간 스윙 자체가 눈에 띄게 달라진다 — 숫자만 오르고 그림이
  /// 그대로면 "무기가 바뀌었다"는 화면에 존재하지 않는 사실이 된다.
  void _renderWeaponSwing(Canvas canvas) {
    final progress =
        (1 - (_meleeTimer / _meleeSpan)).clamp(0.0, 1.0).toDouble();
    final screenDir = gridDirToScreenDir(facing.normalized())..normalize();

    WeaponArt.drawSwing(
      canvas,
      weapon: weapon,
      progress: progress,
      baseAngle: math.atan2(screenDir.y, screenDir.x),
      comboStep: _comboStep,
      finisher: _isFinisher,
    );
  }

  void _renderDeath(Canvas canvas) {
    final t = _deathTimer.clamp(0.0, 1.0).toDouble();
    canvas.save();
    canvas.translate(0, -6 * (1 - t));
    canvas.rotate(-math.pi / 2 * t);
    canvas.scale(1, 1 - t * 0.15);
    _drawFrame(canvas);
    canvas.restore();

    // 파손된 코어에서 새어 나오는 스파크
    if (t < 1) {
      final flicker = math.Random(_deathTimer.floor()).nextDouble();
      canvas.drawCircle(
        Offset(10 * t, -20),
        6 * (1 - t) * (0.5 + flicker * 0.5),
        Paint()
          ..color = GamePalette.playerAccent.withValues(alpha: 0.6 * (1 - t))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }
}

class _DashGhost {
  _DashGhost(this.grid, this.facing);

  final Vector2 grid;
  final Vector2 facing;
  double life = 1;
}
