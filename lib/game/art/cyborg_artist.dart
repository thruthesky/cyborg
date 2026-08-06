import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:provis/provis.dart';

import '../entities/cyborg_design.dart';
import '../palette.dart';
import '../visual/provis_bridge.dart';

/// 인간 저항군 사이보그 — 손으로 그린 최고 품질 액터.
///
/// ## 시각 논제
///
/// **기계가 사람을 입은 것이 아니라, 사람이 기계를 이식받았다.**
///
/// 사이보그를 그릴 때의 함정은 하나다 — **로봇과 구별되지 않는다.** 그런데 이
/// 게임의 적이 바로 AI 로봇이므로, 그 혼동은 단순한 미감의 문제가 아니라
/// **진영 판독의 실패**다. 난전 한복판에서 내 편과 적을 0.2초 안에 갈라내지
/// 못하면 화면이 아무리 예뻐도 게임이 망가진다.
///
/// 그래서 이 몸은 세 가지로 "사람"임을 증명한다.
///
/// 1. **맨살을 한 곳에 몰아준다.** 판금으로 다 덮되 목과 턱만 드러낸다.
///    `Finish.skin` 이 명암 경계에 붉은 산란을 남기고, 그 한 뼘이 나머지
///    금속 전체를 "사람이 입은 것"으로 뒤집는다. 면적이 작을수록 강하다.
/// 2. **바이저 안에 눈이 있다.** 로봇은 센서가 빛나고 사람은 눈이 보인다.
///    `drawEye` 6겹(안와·흰자·홍채 섬유·동공·각막 반사·눈꺼풀)을 그대로
///    쓴다. 적의 단일 발광 렌즈와 정면으로 대비된다.
/// 3. **판금 아래로 합성 근섬유가 비친다.** 판과 판 사이의 틈은 빈 것이
///    아니라 그 아래 무언가가 있다는 신호다.
///
/// ## 값 3층
///
/// 명도를 세 무리로 묶어야 축소했을 때 형태가 남는다.
/// **상부 판금**(밝은 청회) · **언더수트와 하체**(짙은 남색) · **회로**(청록 발광).
/// 이 셋이 섞이지 않게 유지하는 것이 이 캐릭터의 유일한 규율이다.
///
/// ## 왜 [Artist] 인가
///
/// `HumanoidSpec` 은 평균을 만든다. 평균은 안전하지만 기억에 남지 않는다.
/// 이 몸은 게임의 얼굴이므로 비율 자체가 정체성이고, 공통 골격에서 파생시키는
/// 순간 그 정체성이 사라진다. 특히 `CharacterBuild` 로는 강습형과 침투형의
/// 폭 계약(어깨 34 대 25, 골반이 가슴보다 넓은 모래시계)을 재현할 수 없다.
///
/// 초상과 게임 액터가 **같은 [paint] 를 쓰므로 어긋날 수 없다.** 게임은 매
/// 프레임 [yaw]·[swing]·[armSwing] 만 세팅한다.
class CyborgArtist extends Artist {
  CyborgArtist(this.design);

  /// 이 몸의 골격 치수와 색.
  final CyborgDesign design;

  // ── 게임이 매 프레임 세팅하는 포즈 ──────────────────────────────────
  //
  // [Artist.paint] 의 시그니처는 `(canvas, t, {detail})` 로 고정이라 포즈를
  // 인자로 받을 수 없다. 그렇다고 정지 초상으로만 쓰면 걸을 때 자세가 그대로
  // 미끄러진다. 필드로 두면 계약을 지키면서 게임이 몸을 움직일 수 있다.

  /// 바라보는 방향(라디안). 0 이 카메라 정면, π 가 뒷모습.
  double yaw = 0;

  /// 보행 위상 -1~1. 앞으로 뻗는 다리가 화면에서도 앞으로 나온다.
  double swing = 0;

  /// 팔 흔들림.
  double armSwing = 0;

  /// 상하 반동.
  double bob = 0;

  /// 등에 멘 블레이드를 그릴지.
  bool showBlade = true;

  @override
  String get id => design.frame == CyborgFrame.assault
      ? 'cyborg_assault'
      : 'cyborg_infiltrator';

  @override
  String get name => design.codename;

  @override
  String get title => design.frame == CyborgFrame.assault
      ? 'Assault Frame, Human Resistance'
      : 'Infiltration Frame, Human Resistance';

  @override
  String get blurb => design.tagline;

  @override
  Camp get camp => Camp.player;

  @override
  Sex? get sex =>
      design.frame == CyborgFrame.assault ? Sex.male : Sex.female;

  @override
  Color get accent => design.accent;

  /// 이 게임의 단일 광원. 지면·기물·몸이 전부 이것을 공유한다.
  @override
  LightRig get light => ProvisBridge.light;

  @override
  List<Color> get moodSky => const [
        GamePalette.skyHigh,
        GamePalette.skyLow,
        GamePalette.horizonGlow,
      ];

  /// 골격 액터로 넘어가는 다리. 비워 두면 명부와 게임의 인물이 갈린다.
  @override
  CharacterBuild get build => CharacterBuild(
        archetype: design.frame == CyborgFrame.assault
            ? Archetype.paladin
            : Archetype.assassin,
        sex: sex,
        palette: paletteOf(
          skin: GamePalette.playerSkin,
          hair: _hairColor,
          cloth: design.armorBase,
          accent: design.accent,
          metal: design.armorLight,
        ),
        // 게임의 스윙 연출이 따로 있다. 여기서 무기를 켜면 칼이 두 자루가 된다.
        weapon: WeaponKind.none,
        headGear: HeadGear.fullHelm,
        hasPauldrons: true,
        armorHeaviness:
            design.frame == CyborgFrame.assault ? 0.95 : 0.55,
        muscle: design.frame == CyborgFrame.assault ? 0.85 : 0.5,
        glowRunes: true,
        seed: design.frame.index + 1,
      );

  static const Color _hairColor = Color(0xFF1A222E);

  // ── 재질 ────────────────────────────────────────────────────────────
  //
  // 값 3층을 상수로 못박아 둔다. 부위마다 색을 고르기 시작하면 층이 섞이고,
  // 섞이는 순간 축소했을 때 몸이 한 덩어리로 뭉갠다.

  Surface get _plate =>
      Surface(design.armorLight, Finish.metal, contrast: 1.06);
  Surface get _plateDark =>
      Surface(design.armorBase, Finish.metal, contrast: 1.12);
  Surface get _underSuit =>
      Surface(GamePalette.textPrimary, Finish.cloth, contrast: 0.9);
  Surface get _skin => Surface(
        GamePalette.playerSkin,
        Finish.skin,
        sss: const Color(0xFFCF6B57),
      );
  Surface get _sinew => Surface(
        design.accent,
        Finish.energy,
        glow: 0.55,
        glowColor: design.accentSoft,
      );

  /// 골격을 푸는 기준 길이. 모든 비율이 이 값에 곱해진다.
  static const double stageHeight = 1180;

  /// 발바닥에서 정수리까지가 [stageHeight] 의 몇 배인가.
  ///
  /// 골격 비율은 골반·가슴·어깨까지만 정의하고 머리는 그 위에 얹히므로,
  /// 실제 실루엣은 [stageHeight] 와 다르다. 이 값을 빼먹으면 화면에 세울 때
  /// 캐릭터가 의도한 키보다 10% 작게 나온다.
  static const double bodySpan = 0.893;

  @override
  Rect get framing => const Rect.fromLTWH(150, 80, 700, 1290);

  @override
  void paint(Canvas c, double t, {double detail = 1.0}) {
    final v = _Facing(yaw);
    // 정지해 있어도 숨을 쉰다. 이것이 없으면 마네킹이다.
    final breath = breathe(t, amp: 5.0);
    final pulse = 0.72 + 0.28 * math.sin(t * 3.2);
    final baseY = kGround - bob * 6;

    final geo = _Geometry(design, stageHeight, baseY, breath);

    // 접지 그림자. 아이소에는 원근이 없어 이것이 없으면 떠 있는지 뒤에 있는지
    // 알 수 없다.
    groundShadow(c, Offset(0, kGround), geo.hipW * 3.4, geo.hipW * 1.1);

    _paintBackRig(c, geo, v, pulse, detail);

    // 뒤쪽 팔 → 다리 → 몸통 → 앞쪽 팔 순서. 깊이 부호가 순서를 정한다.
    final arms = _armAnchors(geo, v);
    for (final a in arms.where((a) => a.depth <= 0)) {
      _paintArm(c, geo, v, a, pulse, detail);
    }

    _paintLegs(c, geo, v, pulse, detail);
    _paintTorso(c, geo, v, pulse, detail);
    _paintHead(c, geo, v, t, pulse, detail);

    for (final a in arms.where((a) => a.depth > 0)) {
      _paintArm(c, geo, v, a, pulse, detail);
    }
  }

  // ── 몸통 ────────────────────────────────────────────────────────────

  void _paintTorso(
    Canvas c,
    _Geometry g,
    _Facing v,
    double pulse,
    double detail,
  ) {
    // 언더수트가 먼저다. 판금은 그 위에 얹히는 조각들이고, 사이로 이 어두운
    // 층이 비쳐야 갑옷이 몸에 "입혀진" 것으로 보인다.
    final suit = torsoShape(
      chest: Offset(0, g.chestTop),
      pelvis: Offset(0, g.hip),
      shoulderW: g.shoulderW * 0.82,
      chestW: g.chestW * 0.88,
      waistW: g.waistW * 0.9,
      hipW: g.hipW * 0.92,
      neckW: g.neckW,
      bust: g.bust,
    );
    paintSurface(c, suit, _underSuit, light, detail: detail, seed: 5);

    // ── 흉갑 — 이 몸에서 가장 넓은 판 ────────────────────────────────
    //
    // Aldric 의 교훈: 판금의 매력은 형태가 아니라 반사에서 나온다. 한 장으로
    // 덮으면 회색 덩어리가 되므로 흉갑·복갑을 따로 두어 각기 다른 각도의
    // 밴딩이 생기게 한다.
    final chestPlate = torsoShape(
      chest: Offset(0, g.chestTop + g.unit * 0.02),
      pelvis: Offset(0, g.waist),
      shoulderW: g.shoulderW * 0.74,
      chestW: g.chestW,
      waistW: g.waistW * 0.86,
      hipW: g.waistW * 0.8,
      neckW: g.neckW * 0.7,
      bust: g.bust,
    );
    paintSurface(c, chestPlate, _plate, detail: detail, seed: 17, light);
    // 위를 향한 면에 하늘빛이 얹힌다. 아이소에서 어깨·가슴 윗면은 실제로
    // 카메라를 향하므로 이 한 겹이 2.5D 를 만든다.
    topPlane(c, chestPlate, light,
        strength: 0.42, elevationSin: ProvisBridge.iso.elevationSin);
    occlude(c, chestPlate, light.dir, depth: 0.26, alpha: 0.34);

    // 복갑 — 흉갑보다 어둡고 좁다. 허리가 잘록해 보이는 것은 이 대비다.
    final abPlate = torsoShape(
      chest: Offset(0, g.waist - g.unit * 0.04),
      pelvis: Offset(0, g.hip + g.unit * 0.02),
      shoulderW: g.waistW * 0.84,
      chestW: g.waistW * 0.8,
      waistW: g.waistW * 0.76,
      hipW: g.hipW * 0.9,
    );
    paintSurface(c, abPlate, _plateDark, detail: detail, seed: 23, light);
    occlude(c, abPlate, light.dir, depth: 0.3, alpha: 0.4);

    // ── 판 분할 ──────────────────────────────────────────────────────
    //
    // 면 안에 반복 단위가 보여야 관객이 크기를 읽는다. 단색 면에는 스케일이
    // 없어서, 아무리 잘 칠해도 장난감으로 보인다.
    c.save();
    c.clipPath(chestPlate);
    final ramp = Ramp.of(design.armorLight, contrast: 1.2);
    for (var i = 0; i < 3; i++) {
      final y = g.chestTop + (g.waist - g.chestTop) * (0.34 + i * 0.21);
      panelLine(
        c,
        Path()
          ..moveTo(-g.chestW * 0.92, y)
          ..lineTo(g.chestW * 0.92, y + g.unit * 0.01),
        ramp,
        light,
        width: g.unit * 0.022,
        alpha: 0.85 * detail,
      );
    }
    c.restore();

    // ── 노출된 합성 근섬유 ──────────────────────────────────────────
    //
    // 판과 판 사이가 그냥 어두우면 빈 틈이다. 그 아래에서 무언가 움직여야
    // 이 몸이 살아 있는 기계가 된다.
    final gap = v.project(0.0, g.chestW * 0.9, g.depth);
    if (gap.depth > 0) {
      final sinew = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(gap.x, g.waist + g.unit * 0.01),
              width: g.chestW * 0.9,
              height: g.unit * 0.055,
            ),
            Radius.circular(g.unit * 0.02),
          ),
        );
      paintSurface(
        c,
        sinew,
        _sinew,
        light,
        detail: detail,
        seed: 29,
        rim: false,
      );
    }

    // ── 흉부 코어 ────────────────────────────────────────────────────
    //
    // 시선을 한 곳에 몰아준다. 이 몸에서 가장 밝은 점이며, 진영색이 가장
    // 진하게 나오는 자리다.
    final core = v.project(0.0, g.chestW * 0.72, g.depth);
    if (core.depth > 0) {
      final at = Offset(core.x, g.chest);
      final r = g.unit * 0.040 * core.depth;
      // ⚠️ 헤일로 반경은 축소 내성을 정한다. 게임 안에서 이 몸은 59px 까지
      // 줄어드는데, 그때 헤일로가 몸보다 크면 실루엣이 통째로 하얗게 날아가
      // 아군인지 적인지조차 읽히지 않는다. 몸을 덮지 않는 크기로 묶는다.
      glowAt(c, at, r * 2.0, design.accent.withValues(alpha: 0.34 * pulse * detail));
      paintSurface(
        c,
        Path()..addOval(Rect.fromCircle(center: at, radius: r)),
        Surface(
          design.accentSoft,
          Finish.gem,
          glow: 0.9,
          glowColor: design.accent,
        ),
        light,
        detail: detail,
        seed: 31,
      );
    }

    // 실루엣 최상단 — 어깨 윤곽에만 역광을 둔다.
    rimBand(c, chestPlate, light,
        width: g.unit * 0.028, color: design.accentSoft, alpha: 0.5, blur: 3);

    _paintShoulders(c, g, v, pulse, detail);
  }

  void _paintShoulders(
    Canvas c,
    _Geometry g,
    _Facing v,
    double pulse,
    double detail,
  ) {
    final pads = <_Anchor>[];
    for (var i = 0; i < 2; i++) {
      final p = v.project(
        i == 0 ? -math.pi / 2 : math.pi / 2,
        g.shoulderW * 0.92,
        g.depth,
      );
      pads.add(p);
    }
    pads.sort((a, b) => a.depth.compareTo(b.depth));

    for (final s in pads) {
      final w = g.padW * (0.72 + 0.28 * s.depth.abs());
      final pad = Path()
        ..addRRect(
          RRect.fromRectAndCorners(
            Rect.fromCenter(
              center: Offset(s.x, g.shoulder),
              width: w,
              height: w * 0.92,
            ),
            topLeft: Radius.circular(w * 0.44),
            topRight: Radius.circular(w * 0.44),
            bottomLeft: Radius.circular(w * 0.2),
            bottomRight: Radius.circular(w * 0.2),
          ),
        );
      // 뒤쪽 어깨는 몸통에 가려지므로 접촉 그림자를 깊게 준다.
      paintSurface(
        c,
        pad,
        _plate,
        light,
        detail: detail,
        seed: 37,
        occlusion: s.depth <= 0 ? 0.45 : 0.0,
      );
      if (s.depth > 0) {
        topPlane(c, pad, light,
            strength: 0.55, elevationSin: ProvisBridge.iso.elevationSin);
        // 어깨는 실루엣의 가장 바깥이다. 금속 트림이 판의 두께를 만든다.
        trimBand(c, pad, design.accent, light,
            width: g.unit * 0.012, alpha: 0.7 * pulse);
      }
    }
  }

  // ── 사지 ────────────────────────────────────────────────────────────

  List<_Anchor> _armAnchors(_Geometry g, _Facing v) {
    final out = <_Anchor>[];
    for (var i = 0; i < 2; i++) {
      out.add(v.project(
        i == 0 ? -math.pi / 2 : math.pi / 2,
        g.shoulderW * 0.86,
        g.depth,
        phase: i == 0 ? armSwing : -armSwing,
      ));
    }
    return out..sort((a, b) => a.depth.compareTo(b.depth));
  }

  void _paintArm(
    Canvas c,
    _Geometry g,
    _Facing v,
    _Anchor a,
    double pulse,
    double detail,
  ) {
    final back = a.depth <= 0;
    final swingX = a.phase * g.unit * 0.05 * v.strideProjection;
    final swingY = a.phase * g.unit * 0.02 * v.strideDepth;

    final shoulder = Offset(a.x, g.shoulder + g.unit * 0.01);
    final elbow = Offset(
      a.x + swingX * 0.6,
      g.shoulder + (g.hip - g.shoulder) * 0.52 + swingY * 0.5,
    );
    final wrist = Offset(a.x + swingX, g.hip + g.unit * 0.03 + swingY);

    final r = g.armR;
    final arm = limb(shoulder, elbow, wrist,
        r0: r * 1.12, r1: r * 0.88, r2: r * 0.72);

    if (back) {
      // 뒤쪽 팔은 실루엣만 보인다. 어두운 층으로 남겨 앞뒤 관계만 만든다.
      c.drawPath(arm, Paint()..color = GamePalette.textPrimary);
      occlude(c, arm, light.dir, depth: 0.5, alpha: 0.6);
      return;
    }

    // 몸통 위에 얹히는 팔에는 드리우는 그림자가 필요하다. 이것이 없으면
    // 팔과 몸통이 같은 판금이라 서로 묻혀 사라진다.
    castShadow(c, arm,
        offset: Offset(g.unit * 0.02, g.unit * 0.03),
        blur: g.unit * 0.05,
        alpha: 0.38);
    paintSurface(c, arm, _plateDark, light, detail: detail, seed: 41);

    // 상완 장갑(뱀브레이스) — 팔을 한 마디로 두면 흰 파이프가 된다.
    final brace = tube(
      [lerpO(shoulder, elbow, 0.12), lerpO(shoulder, elbow, 0.72)],
      [r * 1.2, r * 0.96],
      samples: 10,
    );
    paintSurface(c, brace, _plate, light, detail: detail, seed: 43);
    topPlane(c, brace, light,
        strength: 0.4, elevationSin: ProvisBridge.iso.elevationSin);

    // 팔꿈치 관절의 동력 링.
    _joint(c, elbow, r * 0.42, pulse * 0.8);

    // 손.
    // 손은 아래를 향한다. 각도는 라디안이고 +y 가 화면 아래다.
    final hand = handShape(wrist, math.pi / 2, r * 1.05, grip: 0.85);
    paintSurface(c, hand, _plateDark, light, detail: detail, seed: 47);
  }

  void _paintLegs(
    Canvas c,
    _Geometry g,
    _Facing v,
    double pulse,
    double detail,
  ) {
    final legs = <_Anchor>[];
    for (var i = 0; i < 2; i++) {
      legs.add(v.project(
        i == 0 ? -math.pi / 2 : math.pi / 2,
        g.hipW * 0.42,
        g.depth * 0.7,
        phase: (i == 0 ? swing : -swing) * design.strideScale,
      ));
    }
    legs.sort((a, b) => a.depth.compareTo(b.depth));

    for (final leg in legs) {
      final back = leg.depth <= 0;
      final strideX = leg.phase * g.unit * 0.055 * v.strideProjection;
      final strideY = leg.phase * g.unit * 0.028 * v.strideDepth;

      final hip = Offset(leg.x, g.hip);
      final knee = Offset(
        leg.x + strideX * 0.45,
        g.knee + strideY * 0.4,
      );
      final ankle = Offset(leg.x + strideX, g.ankle + strideY);

      final r = g.legR;
      final leg3 = limb(hip, knee, ankle,
          r0: r * 1.16, r1: r * 0.82, r2: r * 0.62);

      if (back) {
        c.drawPath(leg3, Paint()..color = GamePalette.textPrimary);
        occlude(c, leg3, light.dir, depth: 0.5, alpha: 0.62);
        continue;
      }

      paintSurface(c, leg3, _underSuit, light, detail: detail, seed: 53);

      // 쿠이스(허벅지 판)와 그리브(정강이 판)를 나눈다. 다리 전체를 판금 관
      // 하나로 두면 거대한 흰 캡슐이 된다.
      final cuisse = tube(
        [lerpO(hip, knee, 0.08), lerpO(hip, knee, 0.68)],
        [r * 1.22, r * 0.94],
        samples: 12,
      );
      paintSurface(c, cuisse, _plateDark, light, detail: detail, seed: 59);

      final greave = tube(
        [lerpO(knee, ankle, 0.14), lerpO(knee, ankle, 0.86)],
        [r * 0.94, r * 0.6],
        samples: 12,
      );
      paintSurface(c, greave, _plate, light, detail: detail, seed: 61);
      topPlane(c, greave, light,
          strength: 0.35, elevationSin: ProvisBridge.iso.elevationSin);

      // 무릎 관절 — 걸을 때 이 점이 함께 움직여 다리가 기계임이 확인된다.
      _joint(c, knee, r * 0.5, pulse);

      // 정강이 회로.
      _circuit(
        c,
        Path()
          ..moveTo(knee.dx + r * 0.5, knee.dy + (ankle.dy - knee.dy) * 0.2)
          ..lineTo(ankle.dx + r * 0.32, ankle.dy - g.unit * 0.01),
        g.unit * 0.012,
        0.6 * pulse,
      );

      // 부츠. 접지선을 밝혀 캐릭터가 떠 보이지 않게 한다.
      final boot = bootShape(ankle, math.pi / 2, r * 1.5);
      paintSurface(c, boot, _underSuit, light, detail: detail, seed: 67);
      // 접지선은 발바닥 **위**에 얹는다. 번짐이 지면 아래로 넘어가면 몸이
      // 바닥을 뚫은 것처럼 보이고, 접지 그림자와도 어긋난다.
      c.drawLine(
        Offset(ankle.dx - r * 1.0, kGround - g.unit * 0.012),
        Offset(ankle.dx + r * 1.0, kGround - g.unit * 0.012),
        Paint()
          ..color = design.accent.withValues(alpha: 0.7 * pulse)
          ..strokeWidth = g.unit * 0.010
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, g.unit * 0.007),
      );
    }
  }

  // ── 머리 — 사람임을 증명하는 자리 ──────────────────────────────────

  void _paintHead(
    Canvas c,
    _Geometry g,
    _Facing v,
    double t,
    double pulse,
    double detail,
  ) {
    final center = Offset(0, g.headCenter);
    final hw = g.headW;
    final hh = g.headH;
    final turn = v.turn;

    // 목 — 맨살 첫 번째 자리. 턱 아래 접촉 그림자가 머리를 몸에 앉힌다.
    final neck = tube(
      [Offset(0, g.shoulder - g.unit * 0.01), Offset(0, g.headCenter + hh * 0.55)],
      [g.neckW * 1.05, g.neckW * 0.88],
      samples: 8,
    );
    paintSurface(c, neck, _skin, light, detail: detail, seed: 71);
    occlude(c, neck, const Offset(0, -1), depth: 0.55, alpha: 0.7);

    // 두개골 — 사람 머리 형상 위에 헬멧이 씌워진다. 이 순서라야 헬멧이
    // "쓴 것"으로 보인다.
    final skull = headShape(center, hw, hh, jaw: 0.72, chin: 0.30, turn: turn);
    paintSurface(c, skull, _skin, light, detail: detail, seed: 73);

    // ── 헬멧 ─────────────────────────────────────────────────────────
    //
    // 턱과 목을 남기고 덮는다. 밀폐복의 함정은 "사람이 안 느껴진다" 인데,
    // 그 탈출구가 이 한 뼘의 맨살이다.
    final helm = Path()
      ..addPath(
        headShape(
          center.translate(0, -hh * 0.12),
          hw * 1.06,
          hh * 0.82,
          jaw: 0.86,
          chin: 0.66,
          turn: turn,
        ),
        Offset.zero,
      );
    castShadow(c, helm,
        offset: Offset(0, hh * 0.06), blur: hh * 0.12, alpha: 0.3);
    paintSurface(c, helm, _plate, light, detail: detail, seed: 79);
    topPlane(c, helm, light,
        strength: 0.6, elevationSin: ProvisBridge.iso.elevationSin);
    // 시선이 가장 오래 머무는 곳. 역광 한 겹이 머리를 배경에서 떼어낸다.
    rimBand(c, helm, light,
        width: hw * 0.06, color: design.accentSoft, alpha: 0.62, blur: 2);
    // 정수리 이음선 — 헬멧이 두 짝이라는 신호.
    panelLine(
      c,
      Path()
        ..moveTo(center.dx + turn * hw * 0.2, center.dy - hh * 0.9)
        ..lineTo(center.dx + turn * hw * 0.5, center.dy - hh * 0.1),
      Ramp.of(design.armorLight, contrast: 1.2),
      light,
      width: hw * 0.035,
      alpha: 0.8 * detail,
    );

    // ── 바이저와 눈 ──────────────────────────────────────────────────
    //
    // **로봇은 센서가 빛나고, 사람은 눈이 보인다.** 적의 단일 발광 렌즈와
    // 정면으로 갈리는 지점이며, 이 게임에서 진영을 가르는 시각 신호다.
    final face = v.project(0.0, hw * 0.5, hw * 0.9);
    if (face.depth > 0.12) {
      final vw = hw * 1.15 * face.depth;
      final visor = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(face.x, center.dy - hh * 0.06),
          width: vw,
          height: hh * 0.44,
        ),
        Radius.circular(hh * 0.2),
      );
      // 바이저는 유리다. 안쪽이 비쳐야 하므로 반투명 보석으로 친다.
      paintSurface(
        c,
        Path()..addRRect(visor),
        Surface(
          design.visorColor,
          Finish.gem,
          glow: 0.35,
          glowColor: design.accent,
          alpha: 0.62,
        ),
        light,
        detail: detail,
        seed: 83,
        rim: false,
      );

      // 유리 **안쪽**의 눈. 6겹을 그대로 쓴다.
      c.save();
      c.clipRRect(visor);
      final eyeW = vw * 0.15;
      final eyeH = hh * 0.1;
      final gap = vw * 0.22;
      for (var i = 0; i < 2; i++) {
        final side = i == 0 ? -1.0 : 1.0;
        drawEye(
          c,
          Offset(face.x + side * gap, center.dy - hh * 0.05),
          eyeW,
          eyeH,
          iris: design.accentSoft,
          light: light,
          look: turn * 0.4,
          mirrored: i == 1,
          glow: design.accent,
          scleraTint: const Color(0xFFD9E8F0),
          lash: 0.6,
        );
      }
      c.restore();

      // 바이저를 가로지르는 주사선 — 렌즈라는 마디.
      c.save();
      c.clipRRect(visor);
      c.drawLine(
        Offset(visor.left, center.dy - hh * 0.06),
        Offset(visor.right, center.dy - hh * 0.06),
        Paint()
          ..color = design.accent.withValues(alpha: 0.45 * pulse)
          ..strokeWidth = hh * 0.018,
      );
      c.restore();
    }

    // 관자놀이 임플란트 — 비대칭 하나가 얼굴에 사연을 준다.
    final temple = v.project(-1.15, hw * 0.86, hw * 0.9);
    if (temple.depth > 0.2) {
      final at = Offset(temple.x, center.dy - hh * 0.22);
      paintSurface(
        c,
        Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: at,
                width: hw * 0.3,
                height: hh * 0.34,
              ),
              Radius.circular(hw * 0.08),
            ),
          ),
        _plateDark,
        light,
        detail: detail,
        seed: 89,
      );
      _joint(c, at, hw * 0.08, pulse);
    }
  }

  // ── 등짐 ────────────────────────────────────────────────────────────

  void _paintBackRig(
    Canvas c,
    _Geometry g,
    _Facing v,
    double pulse,
    double detail,
  ) {
    // 정면일 때는 몸에 가려 보이지 않는다. 뒤를 보일 때만 드러난다.
    final rear = v.project(math.pi, g.chestW * 0.9, g.depth);
    if (rear.depth <= 0) return;

    final pack = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(rear.x, g.chest + g.unit * 0.02),
            width: g.chestW * 1.5,
            height: (g.hip - g.chestTop) * 0.62,
          ),
          Radius.circular(g.unit * 0.03),
        ),
      );
    paintSurface(c, pack, _plateDark, light, detail: detail, seed: 97);
    topPlane(c, pack, light,
        strength: 0.4, elevationSin: ProvisBridge.iso.elevationSin);

    // 동력팩 배기 — 뒷모습에도 진영색이 있어야 한다.
    for (var i = 0; i < 2; i++) {
      final side = i == 0 ? -1.0 : 1.0;
      _joint(
        c,
        Offset(rear.x + side * g.chestW * 0.5, g.chest - g.unit * 0.02),
        g.unit * 0.028,
        pulse,
      );
    }

    if (showBlade) {
      final blade = Path()
        ..moveTo(rear.x - g.unit * 0.02, g.shoulder - g.unit * 0.06)
        ..lineTo(rear.x + g.unit * 0.02, g.shoulder - g.unit * 0.05)
        ..lineTo(rear.x + g.unit * 0.05, g.hip - g.unit * 0.02)
        ..lineTo(rear.x + g.unit * 0.01, g.hip)
        ..close();
      paintSurface(
        c,
        blade,
        Surface(GamePalette.bladeCore, Finish.metal, contrast: 1.3),
        light,
        detail: detail,
        seed: 101,
      );
      trimBand(c, blade, GamePalette.bladeGlow, light,
          width: g.unit * 0.008, alpha: 0.8);
    }
  }

  // ── 공용 소품 ───────────────────────────────────────────────────────

  /// 관절 발광 링. 판과 판이 만나는 곳에 동력이 지난다.
  void _joint(Canvas c, Offset at, double r, double pulse) {
    glowAt(c, at, r * 1.7, design.accent.withValues(alpha: 0.26 * pulse));
    c.drawCircle(
      at,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.32
        ..color = design.accentSoft.withValues(alpha: 0.9 * pulse),
    );
  }

  /// 판 틈으로 새어 나오는 회로.
  void _circuit(Canvas c, Path line, double width, double alpha) {
    c.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 2.4
        ..strokeCap = StrokeCap.round
        ..color = design.accent.withValues(alpha: 0.3 * alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 1.6),
    );
    c.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = design.accentSoft.withValues(alpha: 0.92 * alpha),
    );
  }
}

/// 손그림 액터를 **게임 좌표계**에 세운다.
///
/// [Artist] 는 1000×1400 무대에 발바닥을 [kGround] 에 두고 그린다. 게임의
/// [IsoEntity] 는 발밑이 원점이고 몸이 100px 남짓이다. 그 사이를 잇는 것이
/// 이 함수 하나뿐이라, 초상과 게임이 **같은 그림**을 쓰면서도 좌표만 다르게
/// 놓일 수 있다.
///
/// [height] 는 화면에서의 키(px)다.
void paintCyborgAtFeet(
  Canvas canvas,
  CyborgArtist artist, {
  required double height,
  required double time,
  double detail = 0.55,
}) {
  // 실제 실루엣 높이로 나눈다. 골격 기준 길이로 나누면 머리가 얹힌 만큼
  // 캐릭터가 작아진다.
  final s = height / (CyborgArtist.stageHeight * CyborgArtist.bodySpan);
  canvas.save();
  canvas.scale(s);
  // 무대의 발바닥선을 원점으로 끌어온다.
  canvas.translate(0, -kGround);
  artist.paint(canvas, time, detail: detail);
  canvas.restore();
}

/// [kStage] 좌표계에서의 골격 높이.
///
/// [CyborgDesign] 은 게임 화면 픽셀(키 102~108)로 적혀 있고 이 무대는
/// 1000×1400 이다. 비율만 가져와 무대 크기로 다시 푼다 — 수치를 양쪽에
/// 두 벌로 적으면 반드시 어긋난다.
class _Geometry {
  _Geometry(this.design, double height, this.baseY, double breath)
      : unit = height,
        _h = height,
        _breath = breath;

  final CyborgDesign design;
  final double unit;
  final double _h;
  final double baseY;
  final double _breath;

  double _at(double ratio) => baseY - _h * ratio;

  double get ankle => _at(design.ankleRatio);
  double get knee => _at(design.kneeRatio);
  double get hip => _at(design.hipRatio);
  double get waist => _at(design.waistRatio) + _breath * 0.2;
  double get chest => _at(design.chestRatio) + _breath * 0.5;
  double get chestTop => _at(design.chestRatio + 0.055) + _breath * 0.6;
  double get shoulder => _at(design.shoulderRatio) + _breath * 0.7;

  /// 화면 폭은 디자인 수치를 총 키로 나눈 비율로 환산한다.
  double _w(double designWidth) =>
      _h * (designWidth / design.totalHeight) * 0.5;

  double get shoulderW => _w(design.shoulderWidth);
  double get chestW => _w(design.chestWidth);
  double get waistW => _w(design.waistWidth);
  double get hipW => _w(design.hipWidth);
  double get neckW => _w(design.headWidth) * 0.34;
  double get headW => _w(design.headWidth);
  double get headH => _h * (design.headHeight / design.totalHeight) * 0.5;
  double get padW => _w(design.shoulderPadSize) * 2.1;
  // 사지는 디자인 수치보다 굵게 잡는다. 판금을 덧대면 실루엣이 그만큼
  // 두꺼워지는데, 뼈대 두께를 그대로 쓰면 갑옷 입은 상체에 맨몸 하체가
  // 붙은 것처럼 보인다.
  double get armR => _w(design.armThickness) * 1.15;
  double get legR => _w(design.legThickness) * 1.2;
  double get depth => chestW * 0.62;

  /// 침투 프레임의 가슴. 모래시계 실루엣을 만드는 값이다.
  double get bust =>
      design.frame == CyborgFrame.infiltrator ? chestW * 0.12 : 0;

  double get headCenter => _at(design.shoulderRatio + 0.10) + _breath * 0.8;
}

/// 몸통 둘레의 한 점을 시선각으로 투영한 결과.
class _Anchor {
  const _Anchor(this.x, this.depth, this.phase);

  /// 화면 x.
  final double x;

  /// 앞이면 양수, 뒤면 음수. 그리는 순서와 가림을 정한다.
  final double depth;

  final double phase;
}

/// 연속 회전.
///
/// 스프라이트를 굽지 않으므로 방향을 N장으로 쪼갤 이유가 없다. 몸통을
/// 타원기둥으로 근사하고 둘레각을 시선각만큼 돌려 투영하면, `yaw` 가 임의의
/// 실수여도 같은 비용으로 그려진다.
class _Facing {
  _Facing(this.yaw)
      : _sin = math.sin(yaw),
        _cos = math.cos(yaw);

  final double yaw;
  final double _sin;
  final double _cos;

  /// 3/4 시점 회전량(-1..1). 얼굴 부위가 이 값으로 함께 돌아간다.
  double get turn => _sin;

  double get strideProjection => _sin;
  double get strideDepth => _cos;

  _Anchor project(double anchor, double radius, double depth,
      {double phase = 0}) {
    final a = anchor + yaw;
    return _Anchor(math.sin(a) * radius, math.cos(a), phase);
  }
}
