import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../palette.dart';
import '../systems/weapon.dart';

/// 무기를 그리는 일을 통째로 맡는 곳.
///
/// **계통 하나가 실루엣·표면 무늬·휘두르는 궤적을 함께 갖는다.** 셋을 한 파일에
/// 모아 둔 이유는 그것들이 같은 하나를 말하기 때문이다 — 등에 멘 망치가 뭉툭한데
/// 휘두를 때 얇은 호가 지나가면 두 그림이 서로 다른 무기를 말하게 된다. 새 계통을
/// 더할 때 고쳐야 할 곳도 [WeaponClass] 와 이 파일 둘뿐이다.
///
/// 이 게임에는 이미지 에셋이 없으므로 "텍스처"도 [Canvas] 명령이다. 표면 무늬는
/// **등급에 따라 촘촘해진다** — 색만으로는 밝은 데이터 공간에서 등급 차이가 잘
/// 읽히지 않고, 무늬는 축소해도 밀도로 남는다.
abstract final class WeaponArt {
  // ── 스윙 ────────────────────────────────────────────────────────────

  /// 근접 공격의 궤적을 그린다.
  ///
  /// 원점은 발밑, [baseAngle] 은 바라보는 방향의 화면 각도(라디안),
  /// [progress] 는 스윙의 진행도(0~1)다. [finisher] 는 콤보의 마지막 타로,
  /// 계통마다 그 타가 커지는 방식이 다르다.
  static void drawSwing(
    Canvas canvas, {
    required Weapon weapon,
    required double progress,
    required double baseAngle,
    required int comboStep,
    required bool finisher,
  }) {
    switch (weapon.weaponClass) {
      case WeaponClass.blade:
        _bladeSwing(canvas, weapon, progress, baseAngle, comboStep, finisher);
      case WeaponClass.maul:
        _maulSwing(canvas, weapon, progress, baseAngle, finisher);
      case WeaponClass.lance:
        _lanceSwing(canvas, weapon, progress, baseAngle, comboStep, finisher);
      case WeaponClass.reaper:
        _reaperSwing(canvas, weapon, progress, baseAngle, comboStep, finisher);
      case WeaponClass.driver:
        _driverSwing(canvas, weapon, progress, baseAngle);
      case WeaponClass.talon:
        _talonSwing(canvas, weapon, progress, baseAngle, comboStep, finisher);
      case WeaponClass.vortex:
        _vortexSwing(canvas, weapon, progress, baseAngle, comboStep, finisher);
    }
  }

  /// 스윙의 중심. 어깨 높이다 — 발밑에서 휘두르면 칼이 땅을 쓴다.
  static const Offset _pivot = Offset(0, -52);

  /// 에너지 블레이드 — 부채꼴로 베어 넘긴다.
  ///
  /// 콤보 단계마다 방향을 뒤집어 리듬을 만들고, 마무리는 한 바퀴 가까이 크게
  /// 돈다. 높은 등급은 날이 여러 갈래로 갈라져 함께 지나간다.
  static void _bladeSwing(
    Canvas canvas,
    Weapon weapon,
    double progress,
    double baseAngle,
    int comboStep,
    bool finisher,
  ) {
    final reverse = comboStep.isOdd;
    final sweep = finisher ? math.pi * 1.6 : math.pi * 1.05;
    final start = reverse ? sweep / 2 : -sweep / 2;
    final angle = baseAngle +
        (reverse ? start - sweep * progress : start + sweep * progress);

    final length = weapon.grade.length * (finisher ? 1.19 : 1.0);
    final fade = math.sin(progress * math.pi);

    _trailArc(
      canvas,
      radius: length * 0.78,
      from: baseAngle + start,
      sweep: (reverse ? -1 : 1) * sweep * progress,
      color: weapon.glow,
      width: 16 * fade,
      alpha: 0.35 * fade,
    );

    // 갈래를 각도로 벌리는 이유는 축소 내성 때문이다. 굵기만 키우면 최소
    // 배율에서 뭉툭한 막대 하나로 뭉치지만, 벌어진 갈래는 실루엣으로 남는다.
    const splay = 0.09;
    for (var i = 0; i < weapon.grade.edges; i++) {
      final offset = (i - (weapon.grade.edges - 1) / 2) * splay;
      final edgeAngle = angle + offset;
      final edgeLength = length * (1 - offset.abs() * 0.9);
      final direction = Offset(math.cos(edgeAngle), math.sin(edgeAngle));
      final tip = _pivot + direction * edgeLength;
      final hilt = _pivot + direction * 18;

      _glowLine(canvas, hilt, tip, weapon, width: weapon.grade.coreWidth);
      // 중심 갈래에만 무늬를 새긴다. 갈래마다 다 새기면 지나가는 순간
      // 잔무늬가 뭉쳐 오히려 실루엣이 흐려진다.
      if (i == (weapon.grade.edges - 1) ~/ 2) {
        _etchTicks(canvas, hilt, tip, weapon, spacing: 9);
      }
    }
  }

  /// 파일 해머 — 머리 위로 들었다가 내리찍는다.
  ///
  /// 각도를 시간에 비례시키지 않고 뒤로 갈수록 빨라지게(progress²·⁵) 만드는 것이
  /// 이 계통의 전부다. 등속으로 내려오면 무게가 사라져 큰 막대를 휘두르는
  /// 그림이 되고, 마지막 순간에 몰아치면 같은 시간에도 묵직하게 떨어진다.
  static void _maulSwing(
    Canvas canvas,
    Weapon weapon,
    double progress,
    double baseAngle,
    bool finisher,
  ) {
    // 머리 위 뒤쪽에서 발치 앞(+0.78 rad)까지. 끝각을 발치까지 내리는 것이
    // 중요하다 — 중간에서 멈추면 망치가 허공을 치고 충격파만 공중에 뜬다.
    const from = -2.2;
    const to = 0.78;

    // 세 마디로 나눈다: 들어 올리고(35%) 내리찍고(35%) 그 자리에 둔다(30%).
    //
    // 한 곡선으로 끝까지 가속시키면 타격 판정이 들어가는 순간
    // ([WeaponClass.hitAt]) 망치가 아직 머리 위에 있다 — 그림과 판정이 어긋나면
    // "맞지도 않았는데 죽었다"로 읽힌다. 마지막 마디를 남겨 두는 덕에 충격파가
    // 퍼지는 동안 머리가 바닥에 박혀 있는 그림도 함께 얻는다.
    final impact = WeaponClass.maul.hitAt;
    final double eased;
    if (progress < 0.35) {
      eased = -0.09 * (progress / 0.35);
    } else if (progress < impact) {
      final local = (progress - 0.35) / (impact - 0.35);
      eased = -0.09 + 1.09 * math.pow(local, 1.55).toDouble();
    } else {
      eased = 1;
    }
    final angle = baseAngle + from + (to - from) * eased;

    final length = weapon.grade.length * (finisher ? 1.12 : 0.98);
    final direction = Offset(math.cos(angle), math.sin(angle));
    final head = _pivot + direction * length;
    final grip = _pivot + direction * 14;

    // 자루. 금속이라 발광하지 않는다 — 무기 전체가 빛나면 머리의 무게가 죽는다.
    canvas.drawLine(
      grip,
      head,
      Paint()
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round
        ..color = GamePalette.robotShellDark,
    );
    canvas.drawLine(
      grip,
      head,
      Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = GamePalette.robotShellLight.withValues(alpha: 0.8),
    );

    _maulHead(canvas, weapon, head, angle, scale: finisher ? 1.15 : 1.0);

    // 내리찍는 동안만 짧은 잔상이 따라온다. 호가 길면 베는 무기로 읽힌다.
    final fade = math.sin(math.min(progress, impact) / impact * math.pi);
    _trailArc(
      canvas,
      radius: length * 0.9,
      from: baseAngle + from + (to - from) * math.max(0, eased - 0.3),
      sweep: (to - from) * math.min(eased.abs(), 0.3),
      color: weapon.glow,
      width: 13 * fade,
      alpha: 0.3 * fade,
    );

    // 착탄. 머리가 박힌 자리에서 충격파 고리가 퍼진다.
    if (progress > impact) {
      final since = ((progress - impact) / (1 - impact)).clamp(0.0, 1.0);
      _shockwave(
        canvas,
        head,
        weapon,
        since.toDouble(),
        scale: finisher ? 1.35 : 1.0,
      );
    }
  }

  /// 이온 랜스 — 앞으로 찔러 넣었다가 거둔다.
  ///
  /// 뻗을 때(앞의 35%)는 빠르고 거둘 때는 느리다. 같은 속도로 오가면 찌르기가
  /// 아니라 밀대가 된다.
  static void _lanceSwing(
    Canvas canvas,
    Weapon weapon,
    double progress,
    double baseAngle,
    int comboStep,
    bool finisher,
  ) {
    final extend = progress < 0.35
        ? progress / 0.35
        : 1 - (progress - 0.35) / 0.65 * 0.8;

    // 콤보 단계마다 찌르는 높이를 조금 어긋내 세 번이 같은 그림이 되지 않게 한다.
    final tilt = (comboStep - 1) * 0.12;
    final angle = baseAngle + tilt;
    final direction = Offset(math.cos(angle), math.sin(angle));

    final reachOut = weapon.grade.length * (finisher ? 1.55 : 1.32) * extend;
    final tip = _pivot + direction * (26 + reachOut);
    final butt = _pivot - direction * 16;

    // 찌르는 축을 따라 길게 늘어지는 잔상. 호가 아니라 직선이라야 찌르기다.
    canvas.drawLine(
      _pivot + direction * 20,
      tip,
      Paint()
        ..strokeWidth = 13 * extend
        ..strokeCap = StrokeCap.round
        ..color = weapon.glow.withValues(alpha: 0.28 * extend)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // 자루. 뒤로도 조금 튀어나와 있어야 손이 자루 한가운데를 쥔 것으로 보인다.
    canvas.drawLine(
      butt,
      tip,
      Paint()
        ..strokeWidth = weapon.grade.coreWidth * 0.9
        ..strokeCap = StrokeCap.round
        ..color = GamePalette.robotShellDark,
    );
    _fluteRings(canvas, butt, tip, weapon);
    _glowLine(
      canvas,
      _pivot + direction * (10 + reachOut * 0.55),
      tip,
      weapon,
      width: weapon.grade.coreWidth * 0.85,
    );
    _lanceTip(canvas, weapon, tip, angle, scale: finisher ? 1.25 : 1.0);
  }

  /// 리퍼 — 몸을 축으로 한 바퀴 돈다.
  ///
  /// 초승달 날이 원을 그리며 지나가고 지나온 만큼 고리가 남는다. 320°를 도는
  /// 무기라 궤적이 곧 판정 범위의 설명이 된다.
  static void _reaperSwing(
    Canvas canvas,
    Weapon weapon,
    double progress,
    double baseAngle,
    int comboStep,
    bool finisher,
  ) {
    final reverse = comboStep.isOdd;
    final sweep = math.pi * (finisher ? 2.15 : 1.78);
    final direction = reverse ? -1.0 : 1.0;
    final angle = baseAngle + direction * sweep * progress;

    final radius = weapon.grade.length * (finisher ? 1.05 : 0.92);
    final fade = math.sin(progress * math.pi);

    // 지나온 고리. 끝까지 남겨 두어 "한 바퀴 돌았다"가 화면에 남게 한다.
    _trailArc(
      canvas,
      radius: radius * 0.86,
      from: baseAngle,
      sweep: direction * sweep * progress,
      color: weapon.glow,
      width: 14 * fade,
      alpha: 0.3 * fade,
    );

    // 자루 — 몸에서 날까지 이어 주는 짧은 대.
    final shaftDir = Offset(math.cos(angle), math.sin(angle));
    canvas.drawLine(
      _pivot + shaftDir * 12,
      _pivot + shaftDir * (radius * 0.74),
      Paint()
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round
        ..color = GamePalette.robotShellDark,
    );

    _crescent(canvas, weapon, angle, radius, direction, finisher: finisher);
  }

  /// 파일 드라이버 — 말뚝을 뒤로 물렸다가 한 번에 쏘아 박는다.
  ///
  /// 콤보가 없는 계통이라 **매 타가 같은 그림**이다. 그래서 이 스윙은 각도가
  /// 아니라 오직 뻗는 거리 하나로 이야기한다 — 장전(45%) 동안 뒤로 물러나고,
  /// 격발(27%)에서 앞이 무겁게 빠르게 나가고, 남은 동안 반동으로 되돌아온다.
  ///
  /// [finisher] 를 받지 않는 것도 같은 이유다. 콤보 길이가 1이라 모든 타가
  /// 마무리이므로, 마무리일 때만 커지는 연출은 "언제나 커진다"와 같은 말이다.
  static void _driverSwing(
    Canvas canvas,
    Weapon weapon,
    double progress,
    double baseAngle,
  ) {
    final impact = WeaponClass.driver.hitAt;

    // 말뚝이 나가 있는 정도. 음수면 통 안으로 물러난 것이다.
    final double stroke;
    if (progress < 0.45) {
      // 장전. 천천히 물러나야 다음 순간의 빠름이 대비로 읽힌다.
      stroke = -0.4 * (progress / 0.45);
    } else if (progress < impact) {
      // 격발. 지수를 1보다 작게 잡아 **처음이 가장 빠르다** — 화약이 미는
      // 힘은 격발 순간에 다 들어가고 그 뒤로는 관성만 남기 때문이다.
      final local = (progress - 0.45) / (impact - 0.45);
      stroke = -0.4 + 1.4 * math.pow(local, 0.5).toDouble();
    } else {
      // 반동. 통 쪽으로 되돌아오지만 끝까지는 안 들어간다.
      stroke = 1 - 0.5 * ((progress - impact) / (1 - impact));
    }

    final direction = Offset(math.cos(baseAngle), math.sin(baseAngle));
    final normal = Offset(-direction.dy, direction.dx);

    // 반동이 몸을 뒤로 민다. 총열째로 밀려나야 한 방의 무게가 보인다.
    final recoil = progress > impact
        ? -6.0 * (1 - (progress - impact) / (1 - impact))
        : 0.0;
    final breech = _pivot + direction * (10 + recoil);
    final muzzle = breech + direction * (weapon.grade.length * 0.5);
    final spike = muzzle + direction * (weapon.grade.length * 0.62 * stroke);

    _driverBarrel(canvas, weapon, breech, muzzle, baseAngle);

    // 말뚝. 통에서 나온 만큼만 그린다 — 물러나 있는 동안은 통에 가려 안 보인다.
    if (stroke > 0) {
      _glowLine(
        canvas,
        muzzle,
        spike,
        weapon,
        width: weapon.grade.coreWidth * 1.5,
      );
      // 말뚝 끝의 쐐기.
      _lanceTip(canvas, weapon, spike, baseAngle, scale: 0.9);
    }

    // 총구 화염. 격발 직전에 부풀었다가 나가면서 꺼진다.
    if (progress > 0.42 && progress < impact + 0.12) {
      final flash = 1 - ((progress - 0.45).abs() / 0.28).clamp(0.0, 1.0);
      canvas.drawCircle(
        muzzle,
        (6 + weapon.grade.coreWidth * 2.2) * flash,
        Paint()
          ..color = weapon.core.withValues(alpha: 0.75 * flash)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * flash + 1),
      );
    }

    // 착탄. 박힌 자리에서 고리가 퍼지고, 뒤로는 배기가 뿜어져 나온다.
    if (progress > impact) {
      final since = ((progress - impact) / (1 - impact)).clamp(0.0, 1.0);
      _shockwave(canvas, spike, weapon, since.toDouble(), scale: 1.25);

      final vent = Paint()
        ..color = weapon.glow.withValues(alpha: 0.45 * (1 - since))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      for (final side in [-1.0, 1.0]) {
        canvas.drawCircle(
          breech + normal * side * (5 + 9 * since) - direction * 4,
          5 * (1 - since) + 2,
          vent,
        );
      }
    }
  }

  /// 트윈 탈론 — 갈고리 세 갈래로 짧게 긁는다.
  ///
  /// 콤보가 4타라 한 타가 아주 짧다. 그래서 이 계통은 **날이 아니라 남는 자국**
  /// 으로 읽힌다 — 갈고리 자체는 거의 보이지 않을 만큼 빨리 지나가고, 화면에는
  /// 나란한 세 줄이 남는다. 콤보 단계마다 방향과 높이를 바꿔 네 타가 서로 다른
  /// 자리를 긋게 했다.
  static void _talonSwing(
    Canvas canvas,
    Weapon weapon,
    double progress,
    double baseAngle,
    int comboStep,
    bool finisher,
  ) {
    final reverse = comboStep.isOdd;
    final sweep = math.pi * (finisher ? 0.92 : 0.6);
    final direction = reverse ? -1.0 : 1.0;
    final start = baseAngle - direction * sweep / 2;
    // 3·4타는 조금 위를 긁는다. 두 타씩 짝지어 리듬이 두 박자로 들린다.
    final tilt = comboStep >= 2 ? 0.16 : -0.16;
    final angle = start + direction * sweep * progress + tilt;

    final radius = weapon.grade.length * (finisher ? 0.9 : 0.76);
    final fade = math.sin(progress * math.pi);

    // 세 줄의 자국. 반지름을 어긋내 나란히 남게 한다 — 한 줄이면 블레이드의
    // 궤적과 구분되지 않는다.
    const claws = 3;
    for (var i = 0; i < claws; i++) {
      final spread = (i - (claws - 1) / 2) * 0.13;
      _trailArc(
        canvas,
        radius: radius * (0.72 + i * 0.15),
        from: start + tilt + spread,
        sweep: direction * sweep * progress,
        color: weapon.glow,
        width: 5 * fade,
        alpha: 0.5 * fade,
      );
    }

    // 갈고리 그 자체. 손등판에서 세 갈래가 짧게 뻗어 나온다.
    final knuckle = _pivot + Offset(math.cos(angle), math.sin(angle)) * 16;
    canvas.save();
    canvas.translate(knuckle.dx, knuckle.dy);
    canvas.rotate(angle);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: 9,
          height: 6 + weapon.grade.coreWidth,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = GamePalette.robotShellDark,
    );

    final clawLength = radius * 0.42;
    for (var i = 0; i < claws; i++) {
      final gap = 3.4 + weapon.grade.coreWidth * 0.4;
      final offset = (i - (claws - 1) / 2) * gap;
      // 안쪽으로 살짝 휘어야 "긁는" 갈고리가 된다. 곧게 뻗으면 삼지창이다.
      final hook = Path()
        ..moveTo(4, offset)
        ..quadraticBezierTo(
          clawLength * 0.6,
          offset * 1.25,
          clawLength,
          offset * 0.55,
        );
      canvas.drawPath(
        hook,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = weapon.grade.coreWidth * 1.7
          ..strokeCap = StrokeCap.round
          ..color = weapon.glow.withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawPath(
        hook,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = weapon.grade.coreWidth * 0.7
          ..strokeCap = StrokeCap.round
          ..color = weapon.core,
      );
    }
    canvas.restore();
  }

  /// 볼텍스 디스크 — 원반을 던졌다가 되받는다.
  ///
  /// 190°를 훑는 계통이라 궤적이 곧 판정 범위의 설명이다. 한쪽 끝에서 던져
  /// 반대쪽 끝으로 받으므로 각도는 스윙 내내 한 방향으로 흐르고, 거리는
  /// `sin(πt)` 로 나갔다 돌아온다 — 가장 멀리 나간 순간이 정확히 정면이다.
  ///
  /// 손과 원반을 잇는 자기력선을 함께 그린다. 그것이 없으면 원반이 날아가
  /// 사라지는 그림이 되어 **돌아온다**는 사실이 화면에 없다.
  static void _vortexSwing(
    Canvas canvas,
    Weapon weapon,
    double progress,
    double baseAngle,
    int comboStep,
    bool finisher,
  ) {
    final direction = comboStep.isOdd ? -1.0 : 1.0;
    final half = WeaponClass.vortex.arcDegrees / 2 * math.pi / 180;
    final angle = baseAngle + direction * (-half + 2 * half * progress);

    final radius = weapon.grade.length * (finisher ? 1.35 : 1.15);
    final out = math.sin(progress * math.pi);
    final unit = Offset(math.cos(angle), math.sin(angle));
    final disc = _pivot + unit * (14 + radius * out);

    // 지나온 고리. 원반이 훑은 만큼만 남아 부채꼴이 눈에 보인다.
    _trailArc(
      canvas,
      radius: 14 + radius * 0.62,
      from: baseAngle - direction * half,
      sweep: direction * 2 * half * progress,
      color: weapon.glow,
      width: 11 * out,
      alpha: 0.26 * out,
    );

    // 자기력선. 팽팽할수록(멀리 나갈수록) 옅어진다.
    canvas.drawLine(
      _pivot,
      disc,
      Paint()
        ..strokeWidth = 1.6
        ..color = weapon.glow.withValues(alpha: 0.3 * (1 - out * 0.6)),
    );

    // 잔상. 방금 지나온 자리에 원반이 옅게 겹쳐 회전 속도가 읽힌다.
    for (var i = 1; i <= 2; i++) {
      final back = progress - i * 0.07;
      if (back <= 0) break;
      final ghostAngle = baseAngle + direction * (-half + 2 * half * back);
      final ghost = _pivot +
          Offset(math.cos(ghostAngle), math.sin(ghostAngle)) *
              (14 + radius * math.sin(back * math.pi));
      _vortexDisc(canvas, weapon, ghost, back * 26, alpha: 0.22 / i);
    }

    _vortexDisc(canvas, weapon, disc, progress * 26);
  }

  // ── 계통별 부품 ─────────────────────────────────────────────────────

  /// 망치 머리. 판금 상자에 배기 슬릿과 리벳이 박혀 있다.
  static void _maulHead(
    Canvas canvas,
    Weapon weapon,
    Offset at,
    double angle, {
    double scale = 1.0,
  }) {
    final w = (12 + weapon.grade.coreWidth * 2.4) * scale;
    final h = (16 + weapon.grade.coreWidth * 3.0) * scale;

    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);

    // 발광 — 머리 뒤로 번지게 해서 덩어리의 크기를 알린다.
    canvas.drawCircle(
      Offset.zero,
      h * 0.72,
      Paint()
        ..color = weapon.glow.withValues(alpha: 0.32)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.5),
    );

    final body = Rect.fromCenter(center: Offset.zero, width: h, height: w);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(w * 0.22)),
      Paint()..color = GamePalette.robotShellDark,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(w * 0.22)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = GamePalette.robotShellLight.withValues(alpha: 0.85),
    );

    // 배기 슬릿. 등급이 오를수록 한 줄씩 늘어 표면이 촘촘해진다.
    final vents = 2 + weapon.gradeIndex ~/ 3;
    final slitPaint = Paint()..color = weapon.glow.withValues(alpha: 0.9);
    for (var i = 0; i < vents; i++) {
      final t = (i + 1) / (vents + 1);
      final x = body.left + body.width * t;
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x, 0), width: 1.8, height: w * 0.52),
        slitPaint,
      );
    }

    // 타격면. 앞쪽에만 심지색을 대어 어디로 때리는지 읽히게 한다.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(body.right - h * 0.16, body.top, h * 0.16, w),
        Radius.circular(w * 0.2),
      ),
      Paint()..color = weapon.core.withValues(alpha: 0.9),
    );

    // 리벳.
    final rivet = Paint()
      ..color = GamePalette.robotShellLight.withValues(alpha: 0.7);
    for (final corner in [
      Offset(body.left + 3, body.top + 3),
      Offset(body.left + 3, body.bottom - 3),
    ]) {
      canvas.drawCircle(corner, 1.5, rivet);
    }

    canvas.restore();
  }

  /// 드라이버의 통. 팔에 물린 굵은 약실이라 발광하지 않는다.
  ///
  /// 망치 자루와 같은 이유로 금속색이다 — 통까지 빛나면 튀어나오는 말뚝이
  /// 배경에 묻혀, 이 계통의 유일한 사건인 "쏘아 박는 순간"이 안 보인다.
  static void _driverBarrel(
    Canvas canvas,
    Weapon weapon,
    Offset breech,
    Offset muzzle,
    double angle,
  ) {
    final width = 8 + weapon.grade.coreWidth * 1.5;
    final length = (muzzle - breech).distance;

    canvas.save();
    canvas.translate(breech.dx, breech.dy);
    canvas.rotate(angle);

    final body = Rect.fromLTWH(-6, -width / 2, length + 6, width);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(width * 0.26)),
      Paint()..color = GamePalette.robotShellDark,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(width * 0.26)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = GamePalette.robotShellLight.withValues(alpha: 0.85),
    );

    // 약실의 압력 눈금. 등급이 오를수록 한 칸씩 늘어 통이 촘촘해진다.
    final gauges = 2 + weapon.gradeIndex ~/ 3;
    final gaugePaint = Paint()..color = weapon.glow.withValues(alpha: 0.9);
    for (var i = 0; i < gauges; i++) {
      final t = (i + 1) / (gauges + 1);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(body.left + body.width * t * 0.7, 0),
          width: 2.2,
          height: width * 0.34,
        ),
        gaugePaint,
      );
    }

    // 총구 링. 말뚝이 어디서 나오는지 알린다.
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(body.right - 2, 0),
        width: 3.2,
        height: width * 0.92,
      ),
      Paint()..color = weapon.core.withValues(alpha: 0.9),
    );

    canvas.restore();
  }

  /// 볼텍스의 원반. 속이 빈 고리에 톱니가 박혀 있다.
  ///
  /// [spin] 은 회전각(라디안)이다. 원반은 좌우대칭이라 돌려도 티가 안 나므로
  /// 톱니를 홀수로 두어 **돌고 있다**가 보이게 했다.
  static void _vortexDisc(
    Canvas canvas,
    Weapon weapon,
    Offset at,
    double spin, {
    double alpha = 1.0,
  }) {
    final outer = 9 + weapon.grade.coreWidth * 1.35;

    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(spin);

    canvas.drawCircle(
      Offset.zero,
      outer * 1.1,
      Paint()
        ..color = weapon.glow.withValues(alpha: 0.4 * alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, outer * 0.6),
    );

    // 톱니. 고리 바깥으로 삐죽하게 나와 회전이 보이게 한다.
    const teeth = 5;
    final toothPaint = Paint()
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = weapon.core.withValues(alpha: 0.95 * alpha);
    for (var i = 0; i < teeth; i++) {
      final a = i / teeth * math.pi * 2;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(dir * (outer * 0.72), dir * (outer * 1.18), toothPaint);
    }

    canvas.drawCircle(
      Offset.zero,
      outer * 0.78,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = weapon.grade.coreWidth * 1.1
        ..color = weapon.core.withValues(alpha: alpha),
    );
    // 안쪽 고리는 어둡게 비워 둔다. 꽉 찬 원이면 원반이 아니라 구슬로 보인다.
    canvas.drawCircle(
      Offset.zero,
      outer * 0.44,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = GamePalette.robotShellLight.withValues(alpha: 0.7 * alpha),
    );

    canvas.restore();
  }

  /// 착탄 충격파. 바닥에 눕힌 타원이라 아이소메트릭 지면 위에 놓인 것으로 보인다.
  static void _shockwave(
    Canvas canvas,
    Offset at,
    Weapon weapon,
    double t, {
    double scale = 1.0,
  }) {
    final radius = (14 + 46 * t) * scale;
    final alpha = (1 - t) * 0.75;
    canvas.drawOval(
      Rect.fromCenter(
        center: at,
        width: radius * 2,
        height: radius,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5 * (1 - t) + 1
        ..color = weapon.glow.withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    // 안쪽에 한 겹 더 두르면 고리가 퍼져 나가는 방향이 읽힌다.
    canvas.drawOval(
      Rect.fromCenter(
        center: at,
        width: radius * 1.3,
        height: radius * 0.65,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = weapon.core.withValues(alpha: alpha * 0.7),
    );
  }

  /// 창끝. 좁고 긴 마름모라 찌르는 방향이 실루엣만으로 드러난다.
  static void _lanceTip(
    Canvas canvas,
    Weapon weapon,
    Offset at,
    double angle, {
    double scale = 1.0,
  }) {
    final len = (16 + weapon.grade.coreWidth * 2.2) * scale;
    final half = (3.2 + weapon.grade.coreWidth * 0.5) * scale;

    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);

    final head = Path()
      ..moveTo(len * 0.5, 0)
      ..lineTo(-len * 0.5, -half)
      ..lineTo(-len * 0.34, 0)
      ..lineTo(-len * 0.5, half)
      ..close();

    canvas.drawPath(
      head,
      Paint()
        ..color = weapon.glow.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, half * 1.6),
    );
    canvas.drawPath(head, Paint()..color = weapon.core);
    canvas.drawPath(
      head,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = weapon.glow,
    );
    canvas.restore();
  }

  /// 초승달 날. 안쪽이 비어 있어 얇게 휘어진 실루엣이 남는다.
  static void _crescent(
    Canvas canvas,
    Weapon weapon,
    double angle,
    double radius,
    double direction, {
    bool finisher = false,
  }) {
    // 초승달은 넉넉히 벌려야 회전하는 동안 "낫"으로 읽힌다. 좁으면 돌아가는
    // 막대 하나가 되어 블레이드의 궤적과 구분되지 않는다.
    final span = finisher ? 1.5 : 1.25;
    final rect = Rect.fromCircle(center: _pivot, radius: radius * 0.86);
    final from = angle - direction * span * 0.5;

    // 바깥 날.
    canvas.drawArc(
      rect,
      from,
      direction * span,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = weapon.grade.coreWidth * 3.2
        ..strokeCap = StrokeCap.round
        ..color = weapon.glow.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawArc(
      rect,
      from,
      direction * span,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = weapon.grade.coreWidth * 1.5
        ..strokeCap = StrokeCap.round
        ..color = weapon.core,
    );

    // 날 등의 톱니. 등급이 오를수록 촘촘해진다.
    final teeth = 3 + weapon.gradeIndex ~/ 2;
    final toothPaint = Paint()
      ..strokeWidth = 1.4
      ..color = weapon.glow.withValues(alpha: 0.85);
    for (var i = 0; i < teeth; i++) {
      final t = (i + 0.5) / teeth;
      final a = from + direction * span * t;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        _pivot + dir * (radius * 0.86),
        _pivot + dir * (radius * 0.86 + 4.5),
        toothPaint,
      );
    }
  }

  // ── 공통 붓질 ───────────────────────────────────────────────────────

  /// 발광 심지가 있는 날 한 줄.
  static void _glowLine(
    Canvas canvas,
    Offset from,
    Offset to,
    Weapon weapon, {
    required double width,
  }) {
    canvas.drawLine(
      from,
      to,
      Paint()
        ..strokeWidth = width * 2.6
        ..strokeCap = StrokeCap.round
        ..color = weapon.glow.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawLine(
      from,
      to,
      Paint()
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = weapon.core,
    );
  }

  /// 궤적의 호.
  static void _trailArc(
    Canvas canvas, {
    required double radius,
    required double from,
    required double sweep,
    required Color color,
    required double width,
    required double alpha,
  }) {
    if (width <= 0 || alpha <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: _pivot, radius: radius),
      from,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  /// 칼날에 새긴 가로 눈금. 블레이드 계통의 표면 무늬다.
  ///
  /// 등급이 오르면 [spacing] 이 좁아져 눈금이 촘촘해진다. 색을 바꾸는 것보다
  /// 이쪽이 축소에 강하다 — 멀리서는 무늬가 뭉쳐 "밝은 날"로 보이고, 가까이서는
  /// 등급마다 다른 결이 보인다.
  static void _etchTicks(
    Canvas canvas,
    Offset from,
    Offset to,
    Weapon weapon, {
    required double spacing,
  }) {
    final gap = spacing - weapon.gradeIndex * 0.45;
    final delta = to - from;
    final length = delta.distance;
    if (length < gap * 2) return;

    final dir = delta / length;
    final normal = Offset(-dir.dy, dir.dx);
    final half = weapon.grade.coreWidth * 0.85;
    final paint = Paint()
      ..strokeWidth = 1.1
      ..color = weapon.glow.withValues(alpha: 0.75);

    for (var d = gap; d < length - gap * 0.5; d += gap) {
      final at = from + dir * d;
      // 끝으로 갈수록 날이 좁아지므로 눈금도 함께 줄인다.
      final taper = 1 - (d / length) * 0.55;
      canvas.drawLine(
        at - normal * half * taper,
        at + normal * half * taper,
        paint,
      );
    }
  }

  /// 창대의 마디 고리. 랜스 계통의 표면 무늬다.
  static void _fluteRings(
    Canvas canvas,
    Offset from,
    Offset to,
    Weapon weapon,
  ) {
    final delta = to - from;
    final length = delta.distance;
    final rings = 3 + weapon.gradeIndex ~/ 3;
    if (length < 24) return;

    final dir = delta / length;
    final normal = Offset(-dir.dy, dir.dx);
    final half = weapon.grade.coreWidth * 0.7;
    final paint = Paint()
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = GamePalette.robotShellLight.withValues(alpha: 0.85);

    for (var i = 0; i < rings; i++) {
      final at = from + dir * (length * (i + 1) / (rings + 1.6));
      canvas.drawLine(at - normal * half, at + normal * half, paint);
    }
  }

  // ── 몸에 붙어 있는 모습 ─────────────────────────────────────────────

  /// 등에 멘 무기. **서 있는 사람이 무엇을 들었는지 이것 하나로 읽힌다.**
  ///
  /// [at] 은 어깨 위의 기준점, [span] 은 키에서 유도한 길이, [reveal] 은 시선각에
  /// 따른 노출도(0이면 몸에 가려 보이지 않는다)다.
  ///
  /// 어깨 **위로** 비스듬히 세워 그리는 것이 요점이다. 몸통은 이 그림 뒤에
  /// 덧그려지므로, 아래로 늘어뜨리면 무기가 통째로 등에 가려 계통이 보이지
  /// 않는다. 어깨선을 넘어가는 윗동강만이 실루엣으로 남는다 — PK 가 허용된
  /// 월드에서 상대가 무엇을 들었는지는 붙기 전에 알아야 하는 정보다.
  static void drawHolstered(
    Canvas canvas,
    Weapon weapon, {
    required Offset at,
    required double span,
    required double reveal,
  }) {
    final width = 2.2 + weapon.grade.coreWidth * 0.36;
    final glow = weapon.glow.withValues(alpha: 0.6 * reveal);
    final metal =
        GamePalette.robotShellLight.withValues(alpha: 0.75 * reveal);

    canvas.save();
    // 손잡이는 허리께, 날 끝은 반대쪽 어깨 너머로 간다.
    canvas.translate(at.dx, at.dy + span * 0.3);
    canvas.rotate(-0.55);

    // 이 아래는 국소 좌표다. y가 음수면 어깨 너머(위), 양수면 허리 쪽(아래).
    final grip = span * 0.3;
    final tip = -span * 0.78;

    switch (weapon.weaponClass) {
      case WeaponClass.blade:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-width / 2, tip, width, grip - tip),
            Radius.circular(width / 2),
          ),
          Paint()..color = glow,
        );
        // 코등이. 칼이라는 것을 한 획으로 말한다.
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(0, grip * 0.35),
            width: width * 3.2,
            height: width * 0.8,
          ),
          Paint()..color = metal,
        );

      case WeaponClass.maul:
        // 자루는 어둡게, 머리는 밝게. 위쪽이 무거운 실루엣이 곧 망치다.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-width * 0.45, tip * 0.55, width * 0.9, grip),
            Radius.circular(width / 2),
          ),
          Paint()..color = metal,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-width * 2.1, tip, width * 4.2, span * 0.3),
            Radius.circular(width * 0.7),
          ),
          Paint()..color = glow,
        );

      case WeaponClass.lance:
        // 더 길고 더 가늘다. 끝에 창끝 삼각형이 달린다.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-width * 0.31, tip * 1.12, width * 0.62, grip * 2.6),
            Radius.circular(width / 2),
          ),
          Paint()..color = metal,
        );
        canvas.drawPath(
          Path()
            ..moveTo(0, tip * 1.34)
            ..lineTo(width * 1.5, tip * 1.02)
            ..lineTo(-width * 1.5, tip * 1.02)
            ..close(),
          Paint()..color = glow,
        );

      case WeaponClass.reaper:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-width * 0.4, tip * 0.75, width * 0.8, grip * 2.1),
            Radius.circular(width / 2),
          ),
          Paint()..color = metal,
        );
        // 자루 끝에서 옆으로 휘어 나가는 초승달.
        canvas.drawPath(
          Path()
            ..moveTo(0, tip * 0.78)
            ..quadraticBezierTo(span * 0.42, tip * 0.95, span * 0.30, tip * 0.3),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = width * 1.3
            ..strokeCap = StrokeCap.round
            ..color = glow,
        );

      case WeaponClass.driver:
        // 짧고 굵은 통 하나. 다른 계통이 모두 긴 실루엣이라, **짧다**는 것
        // 자체가 이 계통의 표식이 된다.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-width * 1.5, tip * 0.62, width * 3.0, span * 0.42),
            Radius.circular(width * 0.6),
          ),
          Paint()..color = metal,
        );
        // 약실의 발광 띠. 통 한가운데를 가로지른다.
        canvas.drawRect(
          Rect.fromLTWH(-width * 1.5, tip * 0.4, width * 3.0, width * 0.7),
          Paint()..color = glow,
        );

      case WeaponClass.talon:
        // 어깨 너머로 갈고리 세 갈래가 부챗살처럼 솟는다.
        for (var i = -1; i <= 1; i++) {
          canvas.drawPath(
            Path()
              ..moveTo(i * width * 1.1, grip * 0.2)
              ..quadraticBezierTo(
                i * width * 2.4,
                tip * 0.45,
                i * width * 1.7,
                tip * 0.82,
              ),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = width * 0.85
              ..strokeCap = StrokeCap.round
              ..color = glow,
          );
        }

      case WeaponClass.vortex:
        // 등에 붙인 원반. 유일하게 둥근 실루엣이라 멀리서도 바로 갈린다.
        final ringCenter = Offset(0, tip * 0.55);
        canvas.drawCircle(
          ringCenter,
          span * 0.2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = width * 1.2
            ..color = glow,
        );
        canvas.drawCircle(
          ringCenter,
          span * 0.09,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = width * 0.5
            ..color = metal,
        );
    }

    canvas.restore();
  }

  /// 바닥에 떨어진 무기 상자의 아이콘.
  ///
  /// 잔해에 꽂힌 무기 그 자체를 그린다. 상자 껍데기를 그리면 등급색이 그 안에
  /// 갇혀 멀리서 안 보이지만, 무기를 세워 두면 색과 실루엣이 곧 아이콘이다.
  static void drawPickup(Canvas canvas, WeaponClass weaponClass, Color color) {
    // 잔해 받침. 무엇이 꽂혀 있든 같은 자리에서 시작한다.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-7, 8, 14, 5),
        const Radius.circular(2),
      ),
      Paint()..color = GamePalette.robotShellDark,
    );

    final metal = Paint()..color = GamePalette.robotShellLight;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: 0.7);

    switch (weaponClass) {
      case WeaponClass.blade:
        canvas.drawRect(const Rect.fromLTWH(-1.6, -1, 3.2, 10), metal);
        canvas.drawRect(const Rect.fromLTWH(-6, -2.4, 12, 2.6), metal);
        final blade = Path()
          ..moveTo(0, -17)
          ..lineTo(3.4, -2.4)
          ..lineTo(-3.4, -2.4)
          ..close();
        canvas.drawPath(blade, Paint()..color = color);
        canvas.drawPath(blade, edge);

      case WeaponClass.maul:
        canvas.drawRect(const Rect.fromLTWH(-1.8, -6, 3.6, 15), metal);
        final head = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-8, -17, 16, 11),
          const Radius.circular(2.5),
        );
        canvas.drawRRect(head, Paint()..color = color);
        canvas.drawRRect(head, edge);
        // 배기 슬릿 두 줄이 망치 머리의 무늬다.
        final slit = Paint()..color = GamePalette.robotShellDark;
        canvas.drawRect(const Rect.fromLTWH(-3.4, -15, 1.6, 7), slit);
        canvas.drawRect(const Rect.fromLTWH(1.8, -15, 1.6, 7), slit);

      case WeaponClass.lance:
        canvas.drawRect(const Rect.fromLTWH(-1.2, -8, 2.4, 17), metal);
        // 마디 고리.
        canvas.drawRect(const Rect.fromLTWH(-3, -2, 6, 1.6), metal);
        canvas.drawRect(const Rect.fromLTWH(-3, 3, 6, 1.6), metal);
        final tip = Path()
          ..moveTo(0, -19)
          ..lineTo(2.6, -7)
          ..lineTo(0, -9.5)
          ..lineTo(-2.6, -7)
          ..close();
        canvas.drawPath(tip, Paint()..color = color);
        canvas.drawPath(tip, edge);

      case WeaponClass.reaper:
        canvas.drawRect(const Rect.fromLTWH(-1.4, -12, 2.8, 21), metal);
        final crescent = Path()
          ..moveTo(-1, -12)
          ..quadraticBezierTo(11, -14, 8, -3)
          ..quadraticBezierTo(8, -10, -1, -9)
          ..close();
        canvas.drawPath(crescent, Paint()..color = color);
        canvas.drawPath(crescent, edge);

      case WeaponClass.driver:
        // 굵은 통에서 말뚝이 위로 튀어나와 있다.
        canvas.drawRect(const Rect.fromLTWH(-1.5, -18, 3, 8), metal);
        final barrel = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-6.5, -11, 13, 20),
          const Radius.circular(3),
        );
        canvas.drawRRect(barrel, Paint()..color = color);
        canvas.drawRRect(barrel, edge);
        // 압력 눈금 두 줄.
        final gauge = Paint()..color = GamePalette.robotShellDark;
        canvas.drawRect(const Rect.fromLTWH(-4, -8, 8, 1.8), gauge);
        canvas.drawRect(const Rect.fromLTWH(-4, -3, 8, 1.8), gauge);

      case WeaponClass.vortex:
        // 링 하나. 자루가 없는 유일한 아이콘이라 실루엣만으로 갈린다.
        canvas.drawCircle(
          const Offset(0, -5),
          9,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = color,
        );
        canvas.drawCircle(
          const Offset(0, -5),
          4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = GamePalette.robotShellLight,
        );
        // 톱니 다섯.
        final tooth = Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = color;
        for (var i = 0; i < 5; i++) {
          final a = i / 5 * math.pi * 2 - math.pi / 2;
          final dir = Offset(math.cos(a), math.sin(a));
          canvas.drawLine(
            const Offset(0, -5) + dir * 9,
            const Offset(0, -5) + dir * 13,
            tooth,
          );
        }

      case WeaponClass.talon:
        // 손등판에서 갈고리 세 갈래.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-6, 1, 12, 7),
            const Radius.circular(2),
          ),
          metal,
        );
        for (var i = -1; i <= 1; i++) {
          final hook = Path()
            ..moveTo(i * 4.0, 2)
            ..quadraticBezierTo(i * 7.5, -8, i * 5.0, -16);
          canvas.drawPath(
            hook,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round
              ..color = color,
          );
        }
    }
  }
}
