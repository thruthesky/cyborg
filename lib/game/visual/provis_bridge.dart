import 'dart:ui';

import 'package:provis/provis.dart';

import '../iso.dart';
import '../palette.dart';

/// provis 를 이 게임의 규격·세계관에 맞춰 쓰기 위한 단일 통로.
///
/// provis 는 범용 절차 렌더 툴킷이라 기본값이 **어두운 야외 판타지**에 맞춰져
/// 있다. 이 게임의 무대는 정반대인 "빛으로 가득 찬 데이터 공간"이므로, 조명과
/// 색을 여기서 한 번 번역해 두고 **모든 provis 호출이 이 파일만 거치게** 한다.
/// 호출부마다 리그를 따로 만들면 화면에 태양이 여러 개 뜬다.
///
/// provis 패키지 자체는 별도 저장소의 submodule 이므로 수정하지 않는다.
/// 부족한 것은 전부 이쪽에서 덮는다.
abstract final class ProvisBridge {
  /// provis 에 넘길 아이소 투영 규격.
  ///
  /// provis 의 기본값(`IsoView()`)이 128×64 로 이 게임의 [kTileWidth] ·
  /// [kTileHeight] 와 **정확히 같다**. README 의 156×78 이나 예제의 150×75 는
  /// 그 화면의 선택일 뿐이므로 따라가지 않는다 — 타일 절대 크기를 바꾸면
  /// 히트박스·이동속도·카메라 배율·AOI 반경이 전부 함께 흔들린다.
  ///
  /// ⚠️ 고도만은 어긋난다. provis 의 `heightScale` 은 약 78.4(=128×0.866/√2)
  /// 이고 이 게임의 [kHeightUnit] 은 56 이다. 그래서 **provis 에 z 를 넘기지
  /// 않는다** — 고도가 필요한 것은 계속 [gridToScreen] 이 맡는다.
  static const IsoView iso = IsoView(
    tileWidth: kTileWidth,
    tileHeight: kTileHeight,
  );

  /// 이 게임의 유일한 광원 규격.
  ///
  /// provis 프리셋(`daylight`·`dusk`·`spectral` …)은 전부 어두운 씬을 전제해
  /// 환경광이 짙은 남색이다(`daylight.ambient = 0xFF31415F`). 그 위에 밝은
  /// 데이터 플레이트를 칠하면 지면이 그 남색을 뒤집어써 회보라 장판이 되고,
  /// 그 위에 선 모든 것이 떠 보인다.
  ///
  /// 그래서 환경광을 **밝은 청록으로 끌어올린** 리그를 따로 만든다.
  /// 빛의 방향은 기존 [CyborgRenderer] 가 쓰는 "화면 왼쪽 위"를 그대로 따라야
  /// 같은 화면에서 지면과 몸의 명암이 어긋나지 않는다.
  static const LightRig light = LightRig(
    // 피사체가 광원을 바라보는 방향. y 가 음수라 빛이 위에서 내려온다.
    dir: Offset(-0.58, -0.81),
    // 역광은 반대편 아래쪽에서. 실루엣 외곽에 청록 띠를 남긴다.
    rimDir: Offset(0.74, -0.52),
    key: GamePalette.skyHigh,
    fill: GamePalette.skyLow,
    rim: GamePalette.horizonGlow,
    // 밝은 플레이트에서 되튀어 아랫면을 데우는 빛. 어두운 갈색이 아니다.
    bounce: GamePalette.floorCircuit,
    // 프리셋 대비 훨씬 밝다. 이 값이 이 리그의 핵심이다.
    ambient: GamePalette.wallLeft,
    intensity: 1.0,
  );

  /// 지면 장식용 결정론 난수.
  ///
  /// 시드를 **월드 타일 좌표**에서 뽑는다. 청크 인덱스로 뽑으면 32타일마다
  /// 같은 무늬가 반복되고 청크 경계가 눈에 띈다.
  static Rng groundRng(int worldSeed, int tileX, int tileY) =>
      Rng(worldSeed ^ (tileX * 0x1F1F1F1F) ^ (tileY * 0x2C9277B5));

  /// 데이터 플레이트의 명도 편차용 색.
  ///
  /// 흙 얼룩이 아니라 **연산 부하가 남긴 자국**이라는 해석이므로, 팔레트 안의
  /// 인접한 톤 사이에서만 흔든다. 색상환을 벗어나면 세계관이 깨진다.
  ///
  /// 반드시 바탕(`floorBase`, 거의 흰색)보다 **어두운** 쪽에서 고른다.
  /// 밝은 바탕에 더 밝은 얼룩을 얹으면 아무것도 보이지 않는다 — 얼룩이
  /// 있는지 없는지 모를 정도라면 그리는 값만 치르는 셈이다.
  static Color plateStain(Rng r) => switch (r.range(0, 3).floor()) {
        0 => GamePalette.floorGrid,
        1 => GamePalette.wallLeft,
        _ => GamePalette.horizonGlow,
      };
}
