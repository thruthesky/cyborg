<!-- cowork:kimi | 2026-08-06 19:43:42 | exit=0 | 297s -->
# kimi 분석 — provis-visual-redesign

> 요청: provis git repo 의 https://github.com/thruthesky/provis 패키지를 통해서 현재 cyborg 게임의 비주얼적 디자인을 업데이트 해 주세요.

git repo 의 provis 패키지를 git submodule 로 ./packages/provis 폴더로 submodule add 하고 -> pubspec.yaml 에 dependencies 로 추가한 다음 -> 이 패키지를 활용하여 -> cybord 게임의 멋진 pc 디자인, 게임 맵 디자인을 해 주세요.

사람 개발자는 잠을 자러 갔습니다. 당신이 모든 작업을 진행해서 끝까지 완료해주세요.

[오케스트레이터 주석 — 분석 전에 이미 끝난 것]
- git submodule add https://github.com/thruthesky/provis packages/provis → 완료. 소스가 실제로 작업공간의 packages/provis 에 있으니 직접 열어서 읽어라. README 만 보고 API 를 상상하지 마라.
- pubspec.yaml dependencies 에 provis: {path: packages/provis} 추가 → 완료. flutter pub get 통과 확인.

그러므로 '어떻게 submodule 을 추가하는가' 는 분석 대상이 아니다. 분석할 것은 '이미 붙어 있는 provis 를 이 게임의 어디에, 어떤 순서로, 무엇을 대체하며 넣어서 멋진 PC 디자인과 게임 맵 디자인을 만들 것인가' 이며, 오케스트레이터가 사람이 자는 동안 곧바로 코드를 고칠 수 있을 만큼 구체적인 실행 순서(파일·함수·위험)가 나와야 한다.

[시간 배분 조언] 앞선 시도에서 900초 제한을 넘겨 실패했다. 모든 파일을 완독하려 하지 말고, 핵심 파일(packages/provis/lib/provis.dart, packages/provis/lib/src/iso/*, packages/provis/lib/src/actor/*, packages/provis/example/lib/screens/game_map.dart, lib/game/entities/cyborg_renderer.dart 의 drawBody 시그니처, lib/game/iso.dart, lib/game/level/ground_layer.dart, lib/game/palette.dart)만 표적 독해하고 결론을 내라.
> 생성: 2026-08-06 19:43:42 · 소요 297s · 읽기 전용 분석(작업공간 미수정)

---

• 

## 1. 결론 요약

  **"전면 대체가 아니라 두 단계 점진 결합"이 답이다.** PC 는 `CyborgRenderer`(1,202줄, 게임 내·선택 화면·원격 플레이어가 공유)를 버리지 말고, provis 의 `CharacterBuild`+`HumanoidRenderer`+`paletteOf` 로 **"시드 → 사이보그 스펙" 브리지 한 층**을 새로 만들어 원격 플레이어의 다양성과 셰이딩 품질을 먼저 올리는 것이 1순위다. 맵은 `GroundLayer` 의 청크 캐시 구조(`ui.Picture`, 96청크 상한, 프레임당 3청크 예산)를 그대로 두고, **청크 베이크 안에 provis 기물을 구워 넣는 방식**(매 프레임 절차 렌더가 아님)으로만 결합해야 프레임 예산이 터지지 않는다. 세계관 정합의 가장 중요한 판단: provis 판타지 기물을 그대로 얹으면 정합성 실패이나, `TreeProp.canopyColor/barkColor`(`packages/provis/lib/src/props/tree.dart:59-60`)처럼 **색 오버라이드가 열려 있는 기물만 골라 "데이터 공간에 재해로 남겨진 오염 구역(corrupted zone)"이라는 세계관 확장**으로 도입하면 정합성과 시각 풍요를 동시에 얻는다. 아이소 규격은 **게임의 128×64 에 provis 를 맞춘다**(`IsoView(tileWidth: 128, tileHeight: 64)`) — 게임 쪽을 바꾸면 히트박스·이동속도·AOI·카메라가 전부 흔들린다.

  

## 2. 근거

  - `packages/provis/lib/provis.dart:35-82` — 공개 API 전체 목록 확인: `HumanoidSpec`/`CharacterBuild`/`BuiltArtist`/`IsoView`/`paintIsoGround`/`IsoSceneComponent`/props 16종이 실제 export 됨.
  - `packages/provis/lib/src/actor/spec.dart:112` — `HumanoidSpec.generate(int seed, {Archetype? forceArchetype})` 시그니처 확인. 시드 하나로 결정론적 생성 → 서버 `kind` 문자열 대신 시드 정수를 외형 식별자로 쓸 수 있음.
  - `packages/provis/lib/src/actor/character_build.dart:99-115` — `CharacterBuild.toSpec(fallbackSeed)`: 선언 안 한 항목은 시드 생성기가 채움. "프레임만 고르고 나머지는 시드" 라는 현 게임 구조와 호환.
  - `packages/provis/lib/src/actor/character_build.dart:190-214` — `paletteOf(skin/hair/cloth/accent/…)`: 3~4색으로 11색 팔레트 생성. `GamePalette.playerArmor(0xFF17364F)`·`playerAccent(0xFF00E5FF)`(`lib/game/palette.dart:81-84`)를 그대로 밀어 넣을 수 있음.
  - `packages/provis/README.md:257-264` — 같은 캐릭터 200프레임 반복 렌더 실측: 8분할 418µs, 360분할 284µs(방향 수와 무관). 캐릭터당 프레임당 약 0.3~0.4 ms.
  - `packages/provis/lib/src/iso/iso_view.dart:16` — `IsoView({tileWidth = 128, tileHeight = 64})` **기본값이 이미 게임 규격과 동일**(`lib/game/iso.dart:6-9`). 프롬프트가 우려한 156×78 은 예시에서만 쓰임(`packages/provis/example/lib/screens/game_map.dart:168` 도 150×75). `heightScale = tileWidth·squash/√2`(`iso_view.dart:37`)라 게임의 `kHeightUnit 56`(`lib/game/iso.dart:15`)과는 산출식이 다름(128×64 기준 provis 는 ≈78.2) — 고도 단위를 매핑할 때 주의 지점.
  - `packages/provis/lib/src/iso/iso_stage.dart:395-500` — `RiggedIsoActor`+`paintRiggedActor`: `Animator` 클립(idle/walk/run/attack/hit/death, `iso_stage.dart:452`)과 연속 yaw(`Facing`)로 8방향 회전·보행이 나옴. 현 게임의 `swing`/`armSwing` 수동 위상(`lib/game/entities/player.dart:1213-1224`)을 대체 가능.
  - `lib/game/entities/cyborg_renderer.dart:91-100` — `CyborgRenderer.drawBody(canvas, {design, yaw, baseY, swing, showBlade, armSwing, time})` 시그니처. 상태 없는 정적 메서드.
  - `lib/game/entities/remote_player.dart:154-157` — 원격 외형은 서버 `kind` 문자열 2종(`female_cyborg` → infiltrator, 그 외 → assault)으로만 갈림. **수십 명이 전부 같은 두 몸**으로 보이는 것이 현재 군중 식별성의 실질적 한계.
  - `lib/game/level/ground_layer.dart:35-50` — `GroundLayer`: 32타일 청크를 `ui.Picture` 로 굽고 최대 96청크 캐시, 프레임당 3청크 베이크 예산. `render()` 는 `drawPicture` + 방화벽 발광만(`ground_layer.dart:356-378`) → 기물을 베이크에 합류시키면 프레임 비용 증가가 0에 가까움.
  - `packages/provis/lib/src/props/prop.dart:47,54-61,85-92` — `Prop.paint(c, t, light, {detail})`, `PropInstance(prop, tile, …)`, `paintProp` 시그니처. `IsoView` 와 `LightRig` 만 넘기면 되므로 게임 캔버스 어디에든 구워 넣을 수 있음.
  - `packages/provis/lib/src/props/tree.dart:55-60` — `TreeProp({seed, …, canopyColor, barkColor})` 색 오버라이드 존재. 사이버 톤 재색칠이 게임 쪽 코드만으로 가능.
  - `packages/provis/lib/src/core/shading.dart:17-27,92-114` — `LightRig` 는 생성자 인자 전부 오버라이드 가능(`key/fill/rim/bounce/ambient`). `spectral` 프리셋(차가운 청백 림)이 게임의 "빛으로 가득 찬 데이터 공간" 톤(`lib/game/palette.dart:9`)에 가장 근접.
  - `lib/auth/cyborg_portrait.dart:124-126` — 선택 화면 초상도 `CyborgRenderer.drawBody` 호출. 렌더러를 갈아끼우면 **게임 내·선택 화면·원격 3곳이 한꺼번에** 바뀌므로 일관성은 자동 유지되나 스냅샷 테스트가 동시에 깨짐.
  - `test/cyborg_render_snapshot_test.dart:57-71,145` — 스냅샷 테스트가 `CyborgDesign` 수치(오목 허리, 폭 관계)와 `drawBody` 렌더 결과를 직접 검증. 외형 변경 시 의도적 갱신 대상.

  

## 3. 상세 분석

  ### ① PC 디자인 — 브리지 병행이 정답, 전면 대체는 아님

  현 구조의 강점: `CyborgRenderer.drawBody` 하나를 게임 내 플레이어(`lib/game/entities/player.dart:1218`)·원격 플레이어(`remote_player.dart:435`)·선택 화면(`cyborg_portrait.dart:124`)이 공유하므로 **외형 일관성이 구조적으로 보장**된다. 이를 provis `BuiltArtist` 로 전면 대체하면 이 보장은 유지할 수 있으나(같은 `HumanoidRenderer` 를 3곳이 쓰면 되므로), 다음 세 가지가 동시에 깨진다: `kind` 문자열 기반 서버 동기화의 의미 체계, `CyborgImplant` 7종(`cyborg_design.dart:283-304`)이라는 세계관 고유의 외형 어휘, 스냅샷 테스트군.

  provis 가 실제로 주는 이득은 둘이다. 첫째, **체형·장비 다양성**: 현재 원격 플레이어는 `kind` 2종뿐이라 군중 속에서 "내 파티원" 을 실루엣으로 구분할 수 없다. `HumanoidSpec.generate(seed)` 는 시드 정수 하나로 6원형×체형×장비를 결정론적으로 만들므로(`spec.dart:112-149`), `kind` 문자열을 해시해 시드로 쓰면 서버 프로토콜을 바꾸지 않고도 원격마다 다른 몸이 나온다. 둘째, **골격 애니메이션**: `RiggedIsoActor` 는 다리 교차 보행과 연속 yaw 회전을 제공하고(`iso_stage.dart:440-450`), `Animator` 클립(`attack`/`hit`/`death`)은 현재 게임이 수동 `swing` 값으로 흉내 내는 것의 상위 호환이다.

  판정: **`CharacterBuild` + `paletteOf(GamePalette 색)` 로 "사이보그 빌드"를 선언하고, 렌더링은 provis `HumanoidRenderer`/`RiggedIsoActor` 로 이행**하되, (a) `assault`→`Archetype.knight`·`hasPauldrons:true`, `infiltrator`→`Archetype.assassin`·`heightScale:0.94` 식의 **프레임→원형 매핑표**를 게임 쪽에 두고, (b) 색은 반드시 `paletteOf(cloth: playerArmor, accent: playerAccent, …)` 로 고정해 진영색(청록=아군, `palette.dart:83`)을 지킨다. provis `HumanoidSpec.generate` 는 `Palette.hero(rng)` 로 무작위 색을 뽑으므로(`spec.dart:168`) palette 를 명시하지 않으면 아군 식별색이 붕괴한다 — 이것이 최대 함정이다.

  ### ② 맵 디자인 — 청크 베이크에 구워 넣기

  `GroundLayer` 의 렌더 경로는 "정적 타일은 `ui.Picture` 캐시, 동적 발광만 매 프레임"(`ground_layer.dart:193-201, 356-378`)으로 이미 최적화돼 있다. provis `paintIsoGround` 는 15×15 맵 전체를 한 번에 그리는 전제(`iso_stage.dart:125`)라 1006×1006 월드에는 그대로 못 쓴다 — 하지만 **청크당 32×32 에 대해 청크 시드로 호출하면 베이크 시점에 한 번만 실행**되므로 비용 문제가 없다. 얼룩 2층(`iso_stage.dart:227-261`)이 현재의 평탄한 `floorBase/floorAlt` 체커(`ground_layer.dart:193-194`)보다 "판이 아니라 지형" 으로 읽히게 하는 핵심 레이어다. 단 `paintIsoGround` 의 기본 흙색(`iso_stage.dart:142-143`, 갈색 계열)은 세계관 위반이므로 `base: floorBase, soil: floorAlt` 를 명시해야 한다.

  기물은 `Prop` 이 `paint(canvas, t, light, {detail})` 만 요구하므로(`prop.dart:47`) `IsoSceneComponent` 없이 게임의 `_bakeChunk` 안에서 `paintProp(…, IsoView(), cyberLight, 0)` 으로 구워 넣는 것이 가능하다. 깊이 정렬은 기물이 지면 위에 서는 구조물(타워)과 달리 지면에 붙는 것(GroundPatch·PathPatch·PebbleField, `grounded` 속성 `prop.dart:39`)부터 시작하면 정렬 충돌이 없다.

  ### ③ 세계관 정합 — "오염 구역" 확장이 가장 멋진 길

  세 가지 선택지 중 판단: (a) 세계관을 판타지로 회귀 → `GAME-DESIGN.md`·`palette.dart:5-9` 의 정체성 파괴, 부결. (b) provis 기물을 전부 사이버 톤으로 재색칠 → `TreeProp` 은 `canopyColor/barkColor` 오버라이드가 있어 가능하나(`tree.dart:59-60`), `BuildingProp` 의 목조 벽(WallStyle.timber/log, `game_map.dart:332-338`)은 색만으로 사이보그 세계관에 안 앉는다. (c) **세계관 확장**: "AI 가 점령한 전산망에 물리 세계의 잔해가 오염 데이터로 번져 자라난 구역" — 검은 수지에 청록 발광 수관을 가진 나무(`canopyColor: GamePalette.dataMote`, `barkColor: robotShellDark`), 결정화된 바위(`RockProp` + 차가운 톤), 데이터 늪(`WaterProp`). 이 방식은 게임 쪽 코드만으로 가능하고, 밝은 플레이트 대비 어두운 오염 구역은 미니맵·원근에서 **지역 구분**이라는 게임플레이 정보까지 준다. `LightRig` 도 `spectral`(청백 림, `shading.dart:106-114`)을 기본으로 하되 키라이트를 `skyHigh` 쪽으로 올린 커스텀 리그 하나를 `lib/game/` 에 정의해 모든 provis 호출이 공유하게 한다.

  ### ④ 비용과 위험

  - PC: provis 실측 캐릭터당 284~418µs(README:261-264). 화면에 자신+원격 20명+몬스터 15마리 = 36체 × 0.35ms ≈ **12.6ms** — 60fps 예산 16.6ms 의 76%. 전원 풀 절차 렌더는 불가. `detailFor`(`iso_view.dart:302-311`)와 `BakedPart`(`iso_view.dart:264-295`) 로 정지 파츠를 굽고, 원거리 개체는 `paintImposter`(`iso_view.dart:245-255`) 로 내려야 한다. 현재 자체 렌더러는 그라디언트 fill 위주(`cyborg_renderer.dart:44-46` "가장 값싼 수단")라 이보다 훨씬 쌀 것으로 **[추측]** — 교체가 순수 프레임 하락일 수 있으므로 캐시 전략 선행이 필수.
  - 맵: 베이크 합류 방식이면 프레임 비용 변화 없음(증가는 청크 베이크 시간뿐이고 프레임당 3청크 예산이 이미 있음, `ground_layer.dart:50`).
  - `kind` 문자열: 서버 스키마를 안 건드리려면 문자열 해시→시드 변환만 게임 쪽에 둔다. 다만 같은 `kind` 는 항상 같은 몸이 되어 결정론은 유지된다.
  - 고도 단위: provis `heightScale ≈ 78.2`(128×64 기준) vs 게임 `kHeightUnit = 56`. 기물을 지면(z=0)에만 놓으면 무관하지만, 언덕(`MoundProp.rise`)이나 점프 `airborne` 에 월드 단위를 섞으면 비율이 어긋난다.

  

## 4. 리스크 · 함정

  - **아군 색 붕괴**: `palette` 를 명시하지 않은 `HumanoidSpec.generate` 는 무작위 영웅 팔레트를 뽑는다(`spec.dart:168`). 청록=아군·마젠타=적·호박=타 플레이어(`palette.dart:134`) 식별 체계가 무너지면 MMORPG 전제상 치명적. 모든 빌드에 `paletteOf` 로 `GamePalette` 색을 강제해야 한다.
  - **프레임 예산 초과**: 원격 20명+몹 15마리 동시 절차 렌더 시 약 12.6ms(§3-④). `detailFor`·`BakedPart`·임포스터 없이 도입하면 프레임 드롭이 확정적이다.
  - **스냅샷 테스트 파괴**: `test/cyborg_render_snapshot_test.dart`·`monster_render_path_test.dart`·`mute_button_snapshot_test.dart` 가 렌더 결과와 `CyborgDesign` 수치를 검증(`cyborg_render_snapshot_test.dart:57-71`). 외형 변경 시 의도적으로 깨지며, `CyborgDesign` 을 건드리지 않는 "병행 추가" 로 가면 깨지지 않는다.
  - **조명 불일치**: 게임 셰이딩은 "화면 왼쪽 위의 빛"(`cyborg_renderer.dart:38-40`)으로 고정. provis `LightRig` 의 기본 `dir (-0.58, -0.81)` 은 같은 방향이나 **색온도가 다르므로**(provis 는 따뜻한 키 `0xFFFFF0D4`, 게임은 차가운 청백) 리그를 통일하지 않으면 같은 화면에 두 개의 태양이 뜬다.
  - **`IsoSceneComponent` 도입 유혹**: 이 컴포넌트는 자체 `props`/`grid`/`cameraOffset` 을 들고(`iso_scene.dart:104-110`) `A*` 경로탐색(`IsoController`)까지 제공하지만, 이는 provis 예시의 15×15 단일 화면 전제다. 1 km 스트리밍 월드·서버 권위 이동(24Hz tick) 구조와 정면충돌하므로 **쓰지 않는 것이 맞다** — 필요한 부품(`paintProp`/`RiggedIsoActor`/`Animator`)만 가져온다.
  - **깊이 정렬 이중 체계**: 게임은 `depthPriority(grid)`(x+y, `iso.dart:84-86`), provis 도 `wx+wy`(`iso_view.dart:58`)로 같은 규칙이라 충돌은 없으나, provis 기물을 게임의 `PositionComponent` 트리에 얹을 때 priority 스케일(×100)을 맞춰야 기물이 캐릭터 앞뒤로 올바르게 선다.
  - **provis 수정 금지**: submodule 이므로 부족한 기능(예: 사이버 벽 스타일)은 게임 쪽에서 `Prop` 을 상속한 자체 prop 을 만들어 해결한다(`Prop` 은 abstract class 로 공개, `prop.dart:29`).

  

## 5. 권고안

  | 순위 | 권고 | 범위 | 근거 | 리스크 |
  |---|---|---|---|---|
  | 1 | **사이버 `LightRig` 단일 정의** — `spectral` 기반, 키를 `skyHigh`·림을 `horizonGlow` 로 올린 `GameLightRig.cyber` 상수를 만들고 이후 모든 provis 호출이 이것만 쓰게 한다 | `lib/game/palette.dart` 또는 신규 `lib/game/light_rig.dart` | `shading.dart:106-114`, `palette.dart:15-21` | 없음(신규 파일) |
  | 2 | **맵: `GroundLayer._bakeChunk` 에 `GroundPatch`/`PathPatch`/`PebbleField` 를 청크 시드로 구워 넣기** — `paintProp(canvas, inst, IsoView(), cyberLight, 0)` 을 베이크 캔버스에 호출. 색은 `floorBase` 계열로 명시. 프레임 비용 증가 0 | `lib/game/level/ground_layer.dart:153-208`, `level_map.dart` | `prop.dart:47,85-92`, `iso.dart:16` | 스냅샷 테스트에 맵이 포함되면 갱신 필요; 청크 베이크 시간 소폭 증가 |
  | 3 | **PC 다양성: `kind` 문자열 해시 → 시드 → `CharacterBuild(archetype: 프레임 매핑, palette: paletteOf(GamePalette…))` → `BuiltArtist`/`RiggedIsoActor` 로 원격 플레이어부터 교체** — assault↔knight, infiltrator↔assassin 매핑표 신규 작성 | `lib/game/entities/remote_player.dart:154-157` + 신규 `lib/game/entities/cyborg_build.dart` | `spec.dart:112`, `character_build.dart:99-115,190-214` | `remote_player.dart` 렌더 경로 교체로 해당 테스트 깨짐; 외형 일관성은 palette 강제로 방어 |
  | 4 | **자신의 플레이어·선택 화면 이행** — 3번이 안정되면 `player.dart:_drawFrame`(1210행)과 `cyborg_portrait.dart:124` 를 같은 빌드로 전환. `Animator` 클립(walk/run/attack/hit)으로 수동 `swing`/`armSwing` 대체 | `lib/game/entities/player.dart:1210-1224`, `lib/auth/cyborg_portrait.dart:124` | `iso_stage.dart:440-469`, `player.dart:1213` | `cyborg_render_snapshot_test.dart` 전면 갱신; 보행 감각(보폭·반동) 재조정 필요 |
  | 5 | **"오염 구역" 기물** — `TreeProp(canopyColor: dataMote, barkColor: robotShellDark)`, `RockProp`, `WaterProp` 을 맵 특정 구역(방화벽 인접 등)에 시드 배치. `BuildingProp` 의 목조 스타일은 제외하고 `stone/brick` 만 사용 | `lib/game/level/level_map.dart` + `ground_layer.dart` | `tree.dart:55-60`, `game_map.dart:332-338` | 통행 판정(`level_map.dart`)과 기물 위치 동기화 필요; `Prop.footprint` 와 게임 충돌 격자 매핑 |
  | 6 | **성능 방어선** — 화면 내 액터 수에 따라 `detailFor`·`BakedPart`(정지 파츠 굽기)·`paintImposter`(원거리) 3단계 적용. 도입 후 DTD 스크린샷 + 프레임 계측으로 16.6ms 확인 | `lib/game/entities/*.dart` | `iso_view.dart:245-311`, README:261-264 | 캐시 무효화(조명 변경 시 전체 리베이크) 로직 필요 |

  실행 순서의 논리: 1→2 는 위험이 거의 없고 화면이 즉시 달라진다(지면 풍요). 3 은 서버 무수정으로 군중 식별성을 해결한다. 4 는 가장 큰 시각 개선이지만 스냅샷 테스트 갱신이 동반되므로 3 의 검증 후에. 5 는 세계관 판단이 포함되므로 사람의 눈 검수가 한 번 필요하다.

  

## 6. 불확실 · 미확인

  - **현재 자체 렌더러의 실측 프레임 비용** — provis 대비 얼마나 싼지 측정값이 작업공간에 없다. 교체 전후 비교 계측이 필요하다(§3-④ 의 12.6ms 는 provis 수치만으로 환산한 상한).
  - **`HumanoidRenderer.paint` 의 실제 API 면** — 시그니처(`iso_stage.dart:490-499` 에서 호출되는 형태)만 확인했고 내부 구현(성별 `Sex` 처리, `beast` 골격)은 미독. `infiltrator` 의 여성형 실루엣이 provis 에서 어떻게 나오는지는 `packages/provis/lib/src/actor/humanoid_renderer.dart` 와 `src/art/anatomy.dart` 확인이 필요하다.
  - **`BuiltArtist` 의 초상 품질** — 선택 화면(Flutter 위젯, `cyborg_portrait.dart`)에 쓸 초상이 현재 `_drawHead` 의 바이저 발광 연출 수준에 미치는지는 `packages/provis/example/lib/characters/recruits.dart`·`aldric.dart` 실행 화면을 봐야 판단 가능하다.
  - **몬스터(AI 로봇) 적용 범위** — 이번 분석 요청은 PC 와 맵이므로 `enemy.dart`(1,243줄 자체 렌더)는 범위 밖으로 두었다. PC 만 바꾸면 로봇과의 화풍 격차가 커질 수 있으며, 이 간극을 허용할지는 사람 판단이 필요하다.
  - **서버 `kind` 문자열 외 외형 파라미터 존재 여부** — `spacetimedb/src/lib.rs` 의 캐릭터 테이블에 색·시드 컬럼이 있는지 미확인. 있으면 3번 권고가 더 정확해진다(해시 대신 서버 시드).
  - **청크 경계에서 기물 잘림** — `PropInstance` 가 타일 중심 기준으로 그려지므로 청크 경계에 걸친 큰 기물(`radius 100+`)은 인접 청크 베이크에도 포함시켜야 한다. `bounds.inflate(4)`(`ground_layer.dart:156`)로는 부족하며 inflate 폭 산정이 필요하다.
