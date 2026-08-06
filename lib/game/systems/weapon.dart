import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'level_system.dart';

/// 무기의 계통. **손에 들었을 때 싸우는 방식이 통째로 달라진다.**
///
/// 등급([WeaponGrade])이 "얼마나 좋은 무기인가"라면 계통은 "어떤 무기인가"다.
/// 둘을 나눈 이유는 축이 다르기 때문이다 — 등급은 레벨을 따라 **오르는** 값이라
/// 순서가 있지만, 계통은 서로 우열이 없는 **맞바꿈**이다. 망치는 느리고 무겁고,
/// 창은 빠르고 멀리 닿되 좁게 찌른다.
///
/// 그래서 일곱 계통의 초당 피해는 일부러 서로 5% 안쪽으로 맞춰 두었다
/// (`test/weapon_drop_test.dart` 가 감시한다). 한 계통이 수치로 앞서면 나머지는
/// 손에 들어왔을 때 실망하는 무기가 되고, 계통이 있다는 사실 자체가 무의미해진다.
/// 고르는 근거는 세기가 아니라 **부채꼴의 넓이와 사거리**여야 한다.
///
/// 이 균형이 특히 중요해진 이유는 계통이 이제 **5레벨마다 저절로 손에 들어오기**
/// 때문이다([WeaponSystem.innateCycle]). 주워야만 만나던 시절에는 실망스러운
/// 계통을 안 주우면 그만이었지만, 지금은 안 고를 수가 없다.
enum WeaponClass {
  /// 에너지 블레이드. 사이보그의 팔에 처음부터 달려 있는 기본 계통이다.
  ///
  /// 모든 수치의 기준점(1.0)이라 다른 계통은 이것과의 차이로 읽힌다.
  blade(
    noun: '',
    hue: null,
    damage: 1.00,
    speed: 1.00,
    reach: 0,
    arcDegrees: 120,
    comboLength: 3,
    weight: 30,
  ),

  /// 파일 해머. 느리게 내리찍고 착탄점에 충격파를 남긴다.
  ///
  /// 한 대가 크고 부채꼴이 넓어 몰려드는 잡몹을 정리하기 좋지만, 휘두르는
  /// 동안 움직이지 못하는 시간이 길어 맞으면서 싸우게 된다.
  maul(
    noun: 'MAUL',
    hue: 55,
    damage: 1.35,
    speed: 0.68,
    reach: 0.35,
    arcDegrees: 150,
    comboLength: 2,
    weight: 14,
    hitAt: 0.70,
    heavy: true,
  ),

  /// 이온 랜스. 앞으로 찔러 넣는다.
  ///
  /// 가장 멀리 닿고 가장 빠르지만 부채꼴이 55°뿐이라 **정확히 겨눈 하나만**
  /// 맞는다. 자동 사냥이 한 마리씩 떼어 잡는 방식과 잘 맞는다.
  lance(
    noun: 'LANCE',
    hue: 100,
    damage: 0.78,
    speed: 1.30,
    reach: 0.75,
    arcDegrees: 55,
    comboLength: 3,
    weight: 15,
  ),

  /// 리퍼. 몸을 축으로 한 바퀴 베어 넘긴다.
  ///
  /// 320°라 사실상 사방을 친다. 포위당한 채로도 반격할 수 있는 유일한
  /// 계통이라 한 대의 세기는 가장 낮게 잡았다.
  reaper(
    noun: 'REAPER',
    hue: 281,
    damage: 0.95,
    speed: 0.95,
    reach: 0.20,
    arcDegrees: 320,
    comboLength: 2,
    weight: 12,
  ),

  /// 파일 드라이버. 팔에 문 말뚝을 화약으로 한 번 쏘아 박는다.
  ///
  /// **콤보가 없는 유일한 계통이다.** 한 타에 다 걸린 대신 그 한 타가 언제나
  /// 마무리 취급(×1.6)이라, 다른 계통이 세 번에 나눠 하는 일을 한 번에 한다.
  /// 대신 45°에 속도 ×0.48 — 빗나가면 그 한 번을 통째로 잃는다. 자동 사냥이
  /// 아니라 손으로 겨눠 쏠 때 가장 세지는 계통이다.
  driver(
    noun: 'DRIVER',
    hue: 10,
    damage: 1.55,
    speed: 0.48,
    reach: 0.10,
    arcDegrees: 45,
    comboLength: 1,
    weight: 8,
    hitAt: 0.72,
    heavy: true,
  ),

  /// 트윈 탈론. 양팔의 갈고리로 짧게 네 번 긁는다.
  ///
  /// 가장 빠르고 콤보가 가장 길다(4타). 한 대는 가장 약하지만 마무리가 네 번에
  /// 한 번 돌아오므로 붙어 있는 시간이 곧 피해가 된다. 사거리가 블레이드보다도
  /// 짧아 **맞으면서 싸우는** 것을 전제한 계통이다.
  talon(
    noun: 'TALON',
    hue: 145,
    damage: 0.72,
    speed: 1.44,
    reach: 0.05,
    arcDegrees: 95,
    comboLength: 4,
    weight: 11,
    hitAt: 0.30,
  ),

  /// 볼텍스 디스크. 자기력으로 띄운 원반을 던졌다가 되받는다.
  ///
  /// 원반이 나갔다 돌아오는 동안 190°를 훑으므로 **넓이와 사거리를 함께 가진
  /// 유일한 계통**이다. 대신 그 대가로 세기·속도가 모두 어중간하다 — 어느 한
  /// 상황에서도 최고는 아니고, 어느 상황에서도 최악은 아니다.
  vortex(
    noun: 'VORTEX',
    hue: 236,
    damage: 0.92,
    speed: 1.08,
    reach: 0.55,
    arcDegrees: 190,
    comboLength: 3,
    weight: 10,
  );

  const WeaponClass({
    required this.noun,
    required this.hue,
    required this.damage,
    required this.speed,
    required this.reach,
    required this.arcDegrees,
    required this.comboLength,
    required this.weight,
    this.hitAt = 0.35,
    this.heavy = false,
  });

  /// 이름의 끝말. 비어 있으면 등급 이름을 그대로 쓴다([Weapon.label]).
  final String noun;

  /// 이 계통이 띠는 색상각(HSL 색상환, 0~360). null이면 등급 색을 그대로 쓴다.
  ///
  /// **계통을 색으로 먼저 구분한다.** 실루엣은 붙어야 보이지만 색은 화면
  /// 반대편에서도 보인다 — 바닥에 떨어진 상자를 주우러 갈지, 저쪽에서 오는
  /// 요원이 무엇을 들었는지가 색 하나로 정해진다.
  ///
  /// 블레이드만 null인 이유는 그것이 기본 무기이기 때문이다. 레벨을 따라
  /// 청록에서 금빛으로 흐르는 등급 색이 이미 그 자리에 있고, 그것을 한 색으로
  /// 묶으면 **레벨업이 무기 색을 바꾼다**는 성장의 신호가 사라진다.
  ///
  /// 마젠타 계열(300~350)은 쓰지 않는다. 이 게임의 색 언어에서 마젠타는
  /// "적"이라, 플레이어의 무기가 그 색을 띠면 순간 적으로 읽힌다.
  ///
  /// 값들은 **1레벨 블레이드(190°)에서 45°씩 벌린 격자** 위에 놓여 있다 —
  /// 10·55·100·145·190·236·281. 계통이 일곱이 되면서 자리가 정확히 다 찼다:
  /// 마젠타 대역(300~355)을 빼고 남는 305°에 일곱을 60°씩 벌려 놓을 수는 없다
  /// (그러려면 420°가 필요하다). 45°는 채도 높은 색끼리는 확실히 갈리는 폭이고,
  /// 여기서 계통을 더 늘리려면 색이 아니라 실루엣에 기대야 한다.
  final double? hue;

  /// 근접 피해에 곱해지는 배율. 원거리(플라즈마 볼트)에는 관여하지 않는다 —
  /// 볼트는 계통과 무관하게 같은 방출기에서 나가기 때문이다.
  final double damage;

  /// 휘두르는 속도의 배율. 1보다 크면 한 번의 스윙이 그만큼 짧아진다.
  final double speed;

  /// 근접 사거리에 더해지는 몫(타일).
  final double reach;

  /// 한 번의 스윙이 훑는 부채꼴의 각도.
  final double arcDegrees;

  /// 콤보가 몇 타에 한 번 마무리로 돌아오는지. 마무리는 피해가 ×1.6이다.
  final int comboLength;

  /// 드롭에서 이 계통이 뽑힐 상대 무게.
  final int weight;

  /// 타격 판정이 들어가는 스윙 진행도(0~1).
  ///
  /// **그림과 같은 값을 읽어야 한다.** 궤적을 그리는 쪽([WeaponArt])과 맞는지를
  /// 판정하는 쪽(`Player._updateMelee`)이 서로 다른 시점을 보면, 맞은 순간이
  /// 화면에 없는 공격이 된다 — "맞지도 않았는데 죽었다"로 읽힌다.
  ///
  /// 대부분은 스윙 중반보다 조금 이른 0.35다. 무게로 때리는 계통(해머·드라이버)
  /// 만 늦다 — 들어 올렸다 내리찍는 시간, 말뚝을 뒤로 물렸다 쏘는 시간이
  /// 그 계통의 성격 그 자체라 그림에서 지울 수 없기 때문이다.
  final double hitAt;

  /// 무게로 때리는 계통인지. 휘두르는 소리와 착탄 흔들림이 한 단 세진다.
  ///
  /// 콤보 마무리와 같은 대접을 받는다. 이 계통들은 **매 타가 마무리만큼
  /// 묵직해야** 느린 속도가 손해가 아니라 성격으로 읽히기 때문이다.
  final bool heavy;

  /// 부채꼴 판정에 쓰는 내적 문턱값. 정면과 이루는 각이 절반각보다 크면 빗나간다.
  double get arcDot => math.cos(arcDegrees / 2 * math.pi / 180);

  /// 콤보 한 바퀴의 평균 피해 배율. 마지막 타만 ×1.6이다.
  double get comboAverage => (comboLength - 1 + 1.6) / comboLength;

  /// 계통 하나의 초당 피해 몫. 계통끼리 균형을 재는 잣대다.
  double get dpsFactor => damage * speed * comboAverage;

  /// 무게의 총합. 굴림의 분모다.
  static final int totalWeight =
      values.fold(0, (sum, weaponClass) => sum + weaponClass.weight);

  /// 등급 색을 이 계통의 색상으로 돌린다.
  ///
  /// 색상만 갈아 끼우고 **밝기는 등급의 것을 그대로 둔다.** 그래서 계통은
  /// 색으로, 등급은 밝기로 읽힌다 — 두 정보가 한 색 안에 겹쳐 들어간다.
  ///
  /// 채도의 바닥([minSaturation])과 밝기의 천장([maxLightness])을 함께 두는
  /// 이유는 높은 등급의 색이 흰빛으로 수렴하기 때문이다. 흰색은 채도가 0이라
  /// 색상각을 돌려도 흰색이고, 밝기가 1이면 채도를 올려도 여전히 흰색이다 —
  /// 둘 중 하나만 막으면 만렙 무기가 계통과 무관하게 전부 하얘진다.
  ///
  /// 천장에 걸린 뒤로는 색이 더 밝아지지 않는다. 최상위 세 등급이 색으로는
  /// 구분되지 않는다는 뜻이지만, 그 자리는 날의 수와 크기가 이미 갈라 놓는다.
  Color tint(
    Color base, {
    double minSaturation = 0.6,
    double maxLightness = 0.82,
  }) {
    final h = hue;
    if (h == null) return base;
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withHue(h)
        .withSaturation(math.max(hsl.saturation, minSaturation))
        .withLightness(math.min(hsl.lightness, maxLightness))
        .toColor();
  }
}

/// 무기 등급 하나. 이름과 겉모습, 그리고 그 등급이 시작되는 레벨.
///
/// 등급은 무기가 **눈에 띄게 바뀌는 지점**이다. 레벨업 한 번의 위력 상승은
/// 몇 퍼센트라 화면에서 알아볼 수 없으므로, 그 누적을 이따금 실루엣과 색으로
/// 갈아 끼워 "무기가 자랐다"를 보이게 한다.
class WeaponGrade {
  const WeaponGrade({
    required this.name,
    required this.tier,
    required this.fromLevel,
    required this.glow,
    required this.core,
    required this.length,
    required this.coreWidth,
    required this.edges,
  });

  /// 블레이드 계통의 이름. 그대로 화면에 뜬다.
  final String name;

  /// 등급을 가리키는 앞말. 다른 계통은 여기에 자기 끝말을 붙인다
  /// (`PULSE` + `MAUL` → `PULSE MAUL`).
  final String tier;

  /// 이 등급이 시작되는 레벨.
  final int fromLevel;

  /// 칼날 주변의 발광색. 발사하는 플라즈마 볼트도 이 색을 쓴다.
  final Color glow;

  /// 칼날 심지의 색. 발광색보다 밝아 중심선이 살아 있다.
  final Color core;

  /// 칼날 길이(화면 픽셀). 사거리와 함께 자란다.
  final double length;

  /// 심지의 굵기(화면 픽셀).
  final double coreWidth;

  /// 나란히 뻗는 날의 수. 등급이 오르면 날이 갈라진다.
  ///
  /// 색만 바꾸면 밝은 데이터 공간에서 등급 차이가 잘 읽히지 않는다.
  /// 날의 수는 축소해도 남는 실루엣 정보다.
  final int edges;
}

/// 잔해에서 주운 무기의 벼림 상태.
///
/// 같은 등급, 같은 레벨의 무기라도 이 값 하나로 위력이 갈린다. **드롭이
/// 의미를 갖는 축이 여기다** — 레벨에서 유도되는 기본 무기는 캐릭터 레벨을
/// 정확히 따라오므로, 같은 레벨대의 로봇이 떨군 무기가 그냥 "레벨만큼"이면
/// 주울 이유가 없다. 벼림이 배율을 흔들어 주어야 바닥의 무기를 볼 때마다
/// 지금 든 것보다 나은지 따져 보게 된다.
///
/// 절반 가까이는 [field] 이하가 나오도록 무게를 잡았다. 주운 무기가 늘
/// 업그레이드면 기본 무기가 무의미해지고, 성장 축이 레벨에서 드롭 운으로
/// 통째로 넘어간다.
enum WeaponTemper {
  worn('WORN', 0.90, 34),
  field('', 1.00, 34),
  honed('HONED', 1.08, 20),
  prime('PRIME', 1.16, 9),
  apex('APEX', 1.25, 3);

  const WeaponTemper(this.prefix, this.power, this.weight);

  /// 이름 앞에 붙는 말. [field] 는 기본 무기와 구분할 것이 없어 비워 둔다.
  final String prefix;

  /// 무기 위력에 곱해지는 배율.
  final double power;

  /// 굴림에서 이 등급이 뽑힐 상대 무게.
  final int weight;

  /// 무게의 총합. 굴림의 분모다.
  static final int totalWeight =
      values.fold(0, (sum, temper) => sum + temper.weight);
}

/// 지금 손에 든 무기 한 자루.
///
/// 무기가 오는 길은 둘이다.
///
/// 1. **레벨에서 유도된 기본 무기**([WeaponSystem.forLevel]). 등급도 계통도
///    레벨이 정하므로 — 5레벨마다 계통이 갈린다([WeaponSystem.innateCycle]) —
///    서버가 주고받는 것은 여전히 누적 경험치(→ 레벨)뿐이고, 같은 월드의 모든
///    클라이언트가 남의 것까지 정확히 같은 모습으로 그린다.
/// 2. **로봇 잔해에서 주운 무기**([WeaponSystem.rollDrop]). 레벨과 벼림을
///    굴려서 만들며, 주운 사람만 아는 값이다.
///
/// 1이 바닥을 받쳐 주는 것이 이 설계의 핵심이다. 주운 무기는 [Player] 에서
/// 기본 무기보다 셀 때만 손에 들리므로, 드롭 운이 없어도 무기는 레벨을 따라
/// 자라고 드롭이 사라져도 캐릭터는 정확히 제 레벨의 무기로 되돌아간다.
class Weapon {
  Weapon._(this.level, this.gradeIndex, this.temper, this.weaponClass)
      : power = WeaponSystem.powerAt(level) * temper.power;

  /// 무기 레벨. 기본 무기라면 **캐릭터 레벨과 같다** — 레벨업 한 번이 곧 무기
  /// 강화 한 번이다. 주운 무기라면 떨군 로봇의 레벨 언저리에서 굴린 값이다.
  final int level;

  /// [WeaponSystem.grades] 안에서의 위치.
  final int gradeIndex;

  /// 벼림 상태. 기본 무기는 언제나 [WeaponTemper.field] 다.
  final WeaponTemper temper;

  /// 계통. 기본 무기라면 **레벨이 정한다**([WeaponSystem.classForLevel]) — 5레벨
  /// 마다 다음 계통이 팔에 물린다. 주운 무기라면 굴림에서 나온 값이다.
  final WeaponClass weaponClass;

  /// 근접·원거리 피해에 곱해지는 위력 배율.
  ///
  /// 계통의 몫은 여기 들어 있지 않다. 계통은 피해뿐 아니라 속도·사거리·부채꼴을
  /// 함께 흔들어 **한 숫자로 접히지 않기** 때문이다. 접었다면 "×1.32 짜리 망치"가
  /// 같은 배율의 칼과 같은 무기로 보였을 것이다.
  final double power;

  WeaponGrade get grade => WeaponSystem.grades[gradeIndex];

  /// 이 무기가 내는 발광색. **그리는 쪽은 등급 색이 아니라 이 값을 읽어야 한다.**
  ///
  /// 등급의 밝기에 계통의 색상을 씌운 값이다. 등급 색을 직접 쓰면 계통이 달라도
  /// 같은 색이 나와, 화면 반대편의 무기가 무엇인지 알 수 없다.
  Color get glow => weaponClass.tint(grade.glow);

  /// 날 한가운데의 심지색. 발광색보다 밝다.
  ///
  /// 채도의 바닥을 낮게 잡아 흰빛에 가깝게 둔다 — 심지까지 진하게 물들면
  /// 날의 중심선이 사라져 무기가 납작한 색 덩어리가 된다.
  Color get core =>
      weaponClass.tint(grade.core, minSaturation: 0.22, maxLightness: 0.92);

  /// 등급에 들어선 뒤 몇 번 더 벼렸는지. 이름 뒤에 `+n` 으로 붙는다.
  int get refinement => level - grade.fromLevel;

  /// 등급과 계통만으로 된 이름. `PULSE MAUL`, `ION SABER`.
  ///
  /// 벼림과 벼린 횟수를 뺀 이름이라 **무기가 바뀐 순간을 알리는 배너**에 쓴다
  /// (`ActionRpgGame.onLevelUp`). 거기서 `+7` 이나 `APEX` 까지 읽히면 정작
  /// 바뀐 것 — 등급이 올랐는지 계통이 갈렸는지 — 이 묻힌다.
  String get title => weaponClass.noun.isEmpty
      ? grade.name
      : '${grade.tier} ${weaponClass.noun}';

  /// 화면에 뜨는 이름. 등급 첫 레벨에서는 `+0` 을 붙이지 않는다.
  ///
  /// `APEX PULSE MAUL +4` 처럼 벼림·등급·계통이 한 줄에 다 들어온다. 세 값이
  /// 모두 전투에 영향을 주므로, 하나라도 이름에서 빠지면 바닥의 무기를 주울지
  /// 정하려고 캐릭터 화면을 열어야 한다.
  String get label {
    final base = refinement == 0 ? title : '$title +$refinement';
    return temper.prefix.isEmpty ? base : '${temper.prefix} $base';
  }

  /// 근접 사거리에 더해지는 몫(타일).
  ///
  /// 레벨마다가 아니라 **등급마다** 자란다. 사거리는 자동 사냥이 "얼마나
  /// 붙을지"를 정하는 값이라, 레벨마다 조금씩 흔들리면 접근 거리가 계속
  /// 미세하게 달라져 붙었다 떨어졌다 한다. 등급 단위로 계단을 만들면 한
  /// 등급 안에서는 거리가 고정된다.
  ///
  /// 계통의 몫은 등급과 달리 고정값이다 — 창은 언제나 칼보다 멀리 닿는다.
  double get reachBonus =>
      gradeIndex * WeaponSystem.reachPerGrade + weaponClass.reach;

  /// 이 무기의 초당 피해 몫. **주운 무기를 바꿔 들지 정하는 잣대다.**
  ///
  /// 위력만으로 견주면 느리고 한 대가 큰 망치가 늘 이겨, 계통이 맞바꿈이 아니라
  /// 서열이 된다. 속도와 콤보까지 곱해야 "실제로 더 셌는가"를 묻는 값이 된다.
  double get dps => power * weaponClass.dpsFactor;

  @override
  String toString() => 'Lv.$level $label ×${power.toStringAsFixed(2)}';
}

/// 레벨에서 무기를 만들어 내는 표.
///
/// 무기에 관한 모든 규칙이 여기 있다. 위력 곡선을 손보려면 [powerAt] 하나,
/// 겉모습과 등급 경계를 손보려면 [grades] 하나만 고치면 된다.
abstract final class WeaponSystem {
  /// 등급표. 낮은 등급부터 순서대로 늘어놓는다.
  ///
  /// 색은 청록 → 남색 → 보라 → 금빛 → 흰빛으로 흐른다. 적의 마젠타 계열은
  /// 쓰지 않는다 — 이 게임의 색 언어에서 마젠타는 "적"이라, 아무리 높은
  /// 등급이라도 플레이어의 무기가 그 색을 띠면 순간 적으로 읽힌다.
  ///
  /// 이 흐름을 그대로 쓰는 것은 **블레이드 계통뿐이다.** 나머지 계통은 여기서
  /// 밝기만 가져가고 색상은 자기 것으로 갈아 끼운다([WeaponClass.tint]).
  static const List<WeaponGrade> grades = [
    WeaponGrade(
      name: 'SCRAP EDGE',
      tier: 'SCRAP',
      fromLevel: 1,
      glow: Color(0xFF7FE9FF),
      core: Color(0xFFFFFFFF),
      length: 58,
      coreWidth: 3.0,
      edges: 1,
    ),
    WeaponGrade(
      name: 'ARC SHIV',
      tier: 'ARC',
      fromLevel: 5,
      glow: Color(0xFF35D8F5),
      core: Color(0xFFFFFFFF),
      length: 62,
      coreWidth: 3.4,
      edges: 1,
    ),
    WeaponGrade(
      name: 'PULSE BLADE',
      tier: 'PULSE',
      fromLevel: 10,
      glow: Color(0xFF00E5FF),
      core: Color(0xFFFFFFFF),
      length: 66,
      coreWidth: 3.8,
      edges: 1,
    ),
    WeaponGrade(
      name: 'ION SABER',
      tier: 'ION',
      fromLevel: 20,
      glow: Color(0xFF00D8E8),
      core: Color(0xFFE8FEFF),
      length: 70,
      coreWidth: 4.2,
      edges: 2,
    ),
    WeaponGrade(
      name: 'PLASMA EDGE',
      tier: 'PLASMA',
      fromLevel: 35,
      glow: Color(0xFF2E86FF),
      core: Color(0xFFDCEBFF),
      length: 74,
      coreWidth: 4.6,
      edges: 2,
    ),
    WeaponGrade(
      name: 'FUSION BRAND',
      tier: 'FUSION',
      fromLevel: 55,
      glow: Color(0xFF6E7BFF),
      core: Color(0xFFE4E8FF),
      length: 78,
      coreWidth: 5.0,
      edges: 2,
    ),
    WeaponGrade(
      name: 'VOID CUTTER',
      tier: 'VOID',
      fromLevel: 80,
      glow: Color(0xFF8A5CFF),
      core: Color(0xFFEDE4FF),
      length: 82,
      coreWidth: 5.4,
      edges: 3,
    ),
    WeaponGrade(
      name: 'QUANTUM FANG',
      tier: 'QUANTUM',
      fromLevel: 120,
      glow: Color(0xFFB25CFF),
      core: Color(0xFFF4E8FF),
      length: 86,
      coreWidth: 5.8,
      edges: 3,
    ),
    WeaponGrade(
      name: 'NOVA GLAIVE',
      tier: 'NOVA',
      fromLevel: 180,
      glow: Color(0xFFFFC46B),
      core: Color(0xFFFFF3DC),
      length: 90,
      coreWidth: 6.2,
      edges: 3,
    ),
    WeaponGrade(
      name: 'SINGULARITY EDGE',
      tier: 'SINGULARITY',
      fromLevel: 280,
      glow: Color(0xFFFFE9A8),
      core: Color(0xFFFFFBEF),
      length: 94,
      coreWidth: 6.6,
      edges: 4,
    ),
    WeaponGrade(
      name: 'AEON RENDER',
      tier: 'AEON',
      fromLevel: 450,
      glow: Color(0xFFB9FBFF),
      core: Color(0xFFFFFFFF),
      length: 98,
      coreWidth: 7.0,
      edges: 4,
    ),
    WeaponGrade(
      name: 'GENESIS BREAKER',
      tier: 'GENESIS',
      fromLevel: 700,
      glow: Color(0xFFFFFFFF),
      core: Color(0xFFFFFFFF),
      length: 104,
      coreWidth: 7.6,
      edges: 4,
    ),
  ];

  /// 등급 하나가 더해 주는 근접 사거리(타일).
  static const double reachPerGrade = 0.04;

  /// 만렙 무기가 도달하는 추가 위력. `1 + 이 값`이 배율의 상한이다.
  static const double maxPowerGain = 1.2;

  /// 위력이 상한에 다가가는 속도. 1에 가까울수록 늦게 찬다.
  static const double powerDecay = 0.99;

  /// [level] 무기의 위력 배율.
  ///
  /// 곡선을 포화형으로 잡은 이유는 축이 둘이기 때문이다. 근접·원거리 피해는
  /// 이미 `LevelSystem.gainsFor` 가 레벨마다 **더해서** 키우고 있고, 무기는
  /// 거기에 **곱한다.** 무기 쪽까지 선형으로 자라면 둘의 곱이 제곱으로 뻗어
  /// 만렙 부근에서 몬스터 체력(레벨 200에서 약 4,600)이 무의미해진다.
  ///
  /// 포화형이면 초반 한 레벨이 약 +1.2%로 또렷하게 느껴지면서도, 만렙에서
  /// 무기가 기여하는 몫은 ×2.2 에 머문다 — 무기는 성장을 **거드는** 축이지
  /// 성장 그 자체가 아니다.
  ///
  /// 레벨 1은 ×1.00, 10은 ×1.10, 50은 ×1.44, 100은 ×1.76, 200은 ×2.04,
  /// 999는 ×2.20이다.
  static double powerAt(int level) {
    final n = math.max(0, level - 1);
    return 1 + maxPowerGain * (1 - math.pow(powerDecay, n));
  }

  /// [level]에 해당하는 등급의 번호.
  static int gradeIndexFor(int level) {
    var index = 0;
    for (var i = 1; i < grades.length; i++) {
      if (level < grades[i].fromLevel) break;
      index = i;
    }
    return index;
  }

  /// [level]로 올라선 순간 등급까지 바뀌는지.
  ///
  /// 레벨업은 언제나 무기를 강화하지만, 배너로 따로 알리는 것은 등급이
  /// 바뀔 때뿐이다. 매 레벨 "무기 강화"를 띄우면 알림이 배경이 된다.
  static bool isGradeUp(int level) =>
      grades.any((grade) => grade.fromLevel == level);

  // ── 5레벨마다 손에 들어오는 새 무기 ─────────────────────────────────

  /// 기본 무기의 계통이 갈리는 주기(레벨).
  ///
  /// `LevelSystem.gainsFor` 의 강화 구간(`level % 5 == 0`)과 **같은 주기여야
  /// 한다.** 스탯이 가장 크게 뛰는 레벨에 계통도 함께 갈리므로, 계통끼리의
  /// 초당 피해 차이(최대 5%)가 그 도약에 묻힌다. 두 주기가 어긋나면 계통만
  /// 바뀌는 레벨이 생기고, 그 레벨에서는 새 무기가 약해진 것으로 읽힌다.
  static const int innateStep = 5;

  /// 기본 무기가 도는 계통의 차례. [innateStep] 레벨마다 한 칸씩 넘어간다.
  ///
  /// **끝나지 않고 돈다.** 목록이 소진되면 처음으로 돌아오되 그때는 등급이
  /// 올라 있어, 같은 계통이라도 이름·색·날의 수가 다른 무기로 돌아온다. 일곱
  /// 계통을 다 돌면 35레벨이므로 만렙까지 스물여덟 바퀴다.
  ///
  /// 차례는 **이웃끼리 최대한 다르게** 짰다. 느린 것 다음에 빠른 것, 좁은 것
  /// 다음에 넓은 것이 오도록 — 5레벨을 들여 받은 무기가 방금 쓰던 것과 비슷한
  /// 리듬이면 바뀐 줄도 모른다. 블레이드가 첫 칸인 이유는 그것이 사이보그의
  /// 팔에 처음부터 달려 있는 계통이라서다.
  static const List<WeaponClass> innateCycle = [
    WeaponClass.blade, //   1~4    기준이 되는 부채꼴 베기
    WeaponClass.maul, //    5~9    느리고 무겁다
    WeaponClass.lance, //  10~14   빠르고 멀고 좁다
    WeaponClass.driver, // 15~19   가장 느린 한 방
    WeaponClass.talon, //  20~24   가장 빠른 네 타
    WeaponClass.reaper, // 25~29   사방을 훑는다
    WeaponClass.vortex, // 30~34   나갔다 돌아온다
  ];

  /// [level] 캐릭터의 팔에 물려 있는 계통.
  ///
  /// 레벨 하나에서 유도되는 순수 함수인 것이 요점이다. 서버가 주고받는 것은
  /// 여전히 누적 경험치뿐이므로, 이 규칙 덕에 같은 월드의 모든 클라이언트가
  /// 남이 무엇을 들었는지까지 정확히 같은 그림으로 그린다 — PK 가 허용된
  /// 월드에서 붙기 전에 알아야 하는 정보가 공짜로 맞아떨어진다.
  static WeaponClass classForLevel(int level) =>
      innateCycle[(math.max(1, level) ~/ innateStep) % innateCycle.length];

  /// [level]로 올라선 순간 계통까지 갈리는지.
  static bool isClassSwap(int level) =>
      level > 1 && classForLevel(level) != classForLevel(level - 1);

  /// 레벨당 무기 하나. 매 프레임 만들지 않도록 한 번 만든 것을 재사용한다.
  static final Map<int, Weapon> _cache = {};

  /// [level] 캐릭터가 맨몸으로 드는 기본 무기.
  static Weapon forLevel(int level) {
    final lv = math.max(1, level);
    return _cache.putIfAbsent(
      lv,
      () => Weapon._(
        lv,
        gradeIndexFor(lv),
        WeaponTemper.field,
        classForLevel(lv),
      ),
    );
  }

  /// 주운 무기의 레벨이 떨군 로봇의 레벨에서 벗어날 수 있는 폭.
  ///
  /// 위아래로 열어 둔 이유는 사냥터의 성격 때문이다. 아래로 열려 있으면 강한
  /// 구역에서도 쓸모없는 무기가 섞여 나와 굴림에 긴장이 생기고, 위로 열려
  /// 있으면 제 레벨보다 조금 높은 구역을 노려 사냥할 이유가 된다.
  static const int dropLevelSpread = 3;

  /// 로봇 잔해에서 나오는 무기 한 자루를 굴린다.
  ///
  /// [monsterLevel] 은 떨군 로봇의 레벨이다. 플레이어 레벨이 아니라 로봇
  /// 레벨을 기준으로 삼는 것이 이 게임의 사냥터 설계와 맞는다 — 구역마다
  /// 레벨대가 묶여 있으므로, 높은 구역에서 사냥하면 그만큼 좋은 무기가
  /// 나온다는 규칙이 곧 "어디서 사냥할지"의 선택이 된다.
  static Weapon rollDrop(math.Random rng, {required int monsterLevel}) {
    final spread = rng.nextInt(dropLevelSpread * 2 + 1) - dropLevelSpread;
    final level = (monsterLevel + spread).clamp(1, LevelSystem.maxLevel);
    return Weapon._(
      level,
      gradeIndexFor(level),
      rollTemper(rng),
      rollClass(rng),
    );
  }

  /// 벼림 상태 하나를 무게에 따라 뽑는다.
  static WeaponTemper rollTemper(math.Random rng) {
    var roll = rng.nextInt(WeaponTemper.totalWeight);
    for (final temper in WeaponTemper.values) {
      roll -= temper.weight;
      if (roll < 0) return temper;
    }
    return WeaponTemper.field;
  }

  /// 계통 하나를 무게에 따라 뽑는다.
  ///
  /// 블레이드가 가장 흔하고, 극단으로 갈수록(드라이버·볼텍스) 드물다. 기본
  /// 무기가 5레벨마다 계통을 갈아 끼우게 된 지금은 이 무게가 하는 일이 하나 더
  /// 늘었다 — **드롭이 그 리듬을 뒤엎지 않게** 하는 것이다. 극단적인 계통이
  /// 바닥에서 쏟아지면 지금 팔에 물린 계통을 익힐 틈이 없어진다.
  static WeaponClass rollClass(math.Random rng) {
    var roll = rng.nextInt(WeaponClass.totalWeight);
    for (final weaponClass in WeaponClass.values) {
      roll -= weaponClass.weight;
      if (roll < 0) return weaponClass;
    }
    return WeaponClass.blade;
  }
}
