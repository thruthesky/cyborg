import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// 드물게 섞여 있는 **정예 개체**의 변종.
///
/// 1 km² 월드에 200종을 흩뿌려도 한 구역에서 만나는 상대는 결국 그 구역 등급의
/// 기종뿐이라, 같은 자리에서 오래 사냥하면 모든 교전이 똑같아진다. 정예는 그
/// 단조로움을 깨는 장치다 — 같은 기종인데 하나가 눈에 띄게 질기거나 빠르고,
/// 그만큼 잡을 값어치가 있다.
///
/// **피해에는 손대지 않는다.** "레벨 N 로봇은 정확히 N 을 때린다" 는 이 게임의
/// 전투 수치에서 가장 굳은 규격이고, 배율이 하나라도 끼면 화면의 피해 숫자는
/// 반올림되어 어긋남이 눈에 띄지 않는다. 그래서 정예가 건드리는 것은 체력·속도·
/// 예비 동작·넉백 저항, 그리고 주변을 깨우는 반경까지다. 값어치는 체력을 타고
/// 경험치로 돌아온다([LevelSystem.enemyXpValue] 가 체력 배율을 반영한다).
enum EliteTrait {
  /// 강화 장갑. 느리지만 두 배 넘게 질기고 밀리지 않는다.
  fortified(
    label: '강화 장갑',
    hpScale: 2.6,
    speedScale: 0.85,
    telegraphScale: 1.05,
    knockbackScale: 0.35,
    alertRadiusTiles: 5,
    color: Color(0xFF2E86FF),
  ),

  /// 과부하. 빠르게 달려들고 예비 동작이 짧아 회피 창이 좁다.
  overclocked(
    label: '과부하',
    hpScale: 1.7,
    speedScale: 1.45,
    telegraphScale: 0.7,
    knockbackScale: 1.0,
    alertRadiusTiles: 5,
    color: Color(0xFFFFB020),
  ),

  /// 경계 지휘. 혼자 싸우지 않는다 — 넓은 범위의 동료를 함께 깨운다.
  warden(
    label: '경계 지휘',
    hpScale: 2.0,
    speedScale: 1.1,
    telegraphScale: 0.9,
    knockbackScale: 0.7,
    alertRadiusTiles: 12,
    color: Color(0xFFB44DFF),
  );

  const EliteTrait({
    required this.label,
    required this.hpScale,
    required this.speedScale,
    required this.telegraphScale,
    required this.knockbackScale,
    required this.alertRadiusTiles,
    required this.color,
  });

  /// 이름표에 붙는 말. `과부하 사냥개 MK-III` 처럼 읽힌다.
  final String label;

  /// 체력 배율. 경험치도 이 값을 따라 오른다.
  final double hpScale;

  /// 이동 속도 배율.
  final double speedScale;

  /// 공격 예비 동작 시간 배율. 1보다 작으면 회피할 틈이 줄어든다.
  final double telegraphScale;

  /// 넉백을 받는 정도. 작을수록 밀리지 않는다.
  final double knockbackScale;

  /// 플레이어를 발견했을 때 함께 깨우는 동료의 반경(타일).
  final double alertRadiusTiles;

  /// 이 변종을 나타내는 색. 발밑 고리와 이름표가 같은 색을 쓴다.
  final Color color;

  /// 일반 개체가 동료를 깨우는 반경(타일).
  ///
  /// 정예가 아니어도 비명은 지른다 — 한 마리를 건드리면 곁의 두어 기가 함께
  /// 달려드는 것이 이 월드의 기본 긴장이다.
  static const double baseAlertRadiusTiles = 4.5;

  /// [depth](0 = 시작 지점, 1 = 월드 외곽)에서 정예가 섞일 확률.
  ///
  /// 시작 근처에서도 아주 드물게는 만나야 "정예" 라는 것이 있다는 사실을 배우고,
  /// 외곽으로 갈수록 흔해져 깊이 들어갈 이유가 된다.
  static double chanceAt(double depth) =>
      0.035 + depth.clamp(0.0, 1.0) * 0.05;

  /// [depth] 구역에서 정예 여부를 굴린다. 정예가 아니면 null.
  static EliteTrait? roll(math.Random random, double depth) {
    if (random.nextDouble() >= chanceAt(depth)) return null;
    return values[random.nextInt(values.length)];
  }
}
