<!-- cowork:grok | 2026-08-06 19:31:30 | exit=0 | 498s -->
# grok 분석 — provis-visual-redesign

> 요청: provis git repo 의 https://github.com/thruthesky/provis 패키지를 통해서 현재 cyborg 게임의 비주얼적 디자인을 업데이트 해 주세요.

git repo 의 provis 패키지를 git submodule 로 ./packages/provis 폴더로 submodule add 하고 -> pubspec.yaml 에 dependencies 로 추가한 다음 -> 이 패키지를 활용하여 -> cybord 게임의 멋진 pc 디자인, 게임 맵 디자인을 해 주세요.

사람 개발자는 잠을 자러 갔습니다. 당신이 모든 작업을 진행해서 끝까지 완료해주세요.

[오케스트레이터 주석 — 분석 전에 이미 끝난 것]
- git submodule add https://github.com/thruthesky/provis packages/provis → 완료. 소스가 실제로 작업공간의 packages/provis 에 있으니 직접 열어서 읽어라. README 만 보고 API 를 상상하지 마라.
- pubspec.yaml dependencies 에 provis: {path: packages/provis} 추가 → 완료. flutter pub get 통과 확인.

그러므로 '어떻게 submodule 을 추가하는가' 는 분석 대상이 아니다. 분석할 것은 '이미 붙어 있는 provis 를 이 게임의 어디에, 어떤 순서로, 무엇을 대체하며 넣어서 멋진 PC 디자인과 게임 맵 디자인을 만들 것인가' 이며, 오케스트레이터가 사람이 자는 동안 곧바로 코드를 고칠 수 있을 만큼 구체적인 실행 순서(파일·함수·위험)가 나와야 한다.
> 생성: 2026-08-06 19:31:30 · 소요 498s · 읽기 전용 분석(작업공간 미수정)

---



## 1. 결론 요약

**provis 는 이미 `packages/provis` submodule + `pubspec.yaml` path 의존성으로 붙어 있고, 게임 `lib/**` 에서는 아직 import 되지 않는다.** 남은 일은 엔진 교체가 아니라 **사이버 톤으로 재색한 재질·기물·(이후) 휴머노이드를 게임의 청크/깊이/kind 체계 위에 점진 이식**하는 것이다.

**한 줄 권고:** `IsoSceneComponent` / `IsoController` / `paintIsoGround` 로 1 km 월드를 갈아끼우지 말고, `GroundLayer` + `IsoEntity` + `kind` 문자열을 권위로 둔 채 provis 의 `paintSurface`·`Prop`·(후순위) `HumanoidRenderer` 만 쓴다. 세계관은 버리고 숲을 얹지 말고, `WorldTree` 선례대로 **“전산망 안 데이터 응결 지형”으로 확장**한다.

**우선 실행 순서:** ① 지면 **grounded** 장식 bake → ② PC **셰이딩** (`paintSurface`) → ③ **수직** prop 을 `IsoEntity` 로 스트리밍 → ④ Humanoid 어댑터 → ⑤ 블록/월드트리/적 톤 정렬. (1차의 “Prop 전부 청크 bake”는 깊이 정렬을 깨므로 **철회**.)

---

## 2. 근거

- `pubspec.yaml:42–45` — `provis: path: packages/provis` 등록 완료.
- `lib/**` 전역 검색 — `provis` / `paintSurface` / `BuiltArtist` 등 **게임 코드 import 0건**.
- `lib/game/iso.dart:6–15, 40–47` — 타일 128×64, `kHeightUnit=56`, 월드 1000 m, 청크 32.
- `packages/provis/lib/src/iso/iso_view.dart:16, 37` — 기본 `IsoView(128,64)`; `heightScale ≈ tileWidth·squash/√2` (128 기준 ≈ 78.4, 게임 56과 불일치).
- `lib/game/palette.dart:5–9, 79–87, 130–134` — “빛으로 가득 찬 사이버 스페이스”; 본체 짙은 청록 계열; 원격 이름색 호박.
- `GAME-DESIGN.md:52–66` — 동일 톤·진영색 표; 본체 짙게/발광 강하게.
- `lib/game/level/ground_layer.dart:30–50, 163–197` — 청크 `ui.Picture` bake, 프레임당 3청크 예산·캐시 96; 타입별 Path 합쳐 **단색 fill**.
- `lib/game/level/world_tree.dart:9–20, 21–23` — “데이터가 자라 굳은 나무”; **충돌 없음**; `IsoEntity` 깊이 정렬.
- `lib/game/entities/iso_entity.dart:39–44` — `priority = depthPriority(grid)` 로 플레이어·블록·나무가 같은 깊이 축.
- `packages/provis/lib/src/props/prop.dart:39–47, 85–105` — `grounded`/`walkable`; `paintProp` 이 세워진 기물에 `iso.squash`(≈0.866) 적용.
- `packages/provis/lib/src/props/ground.dart:29–66` — `GroundPatch`: `grounded`·`walkable` true, `blades`/`color` 재색 가능.
- `packages/provis/lib/src/props/tree.dart:54–61` — `TreeProp(canopyColor, barkColor, kind)`.
- `packages/provis/lib/src/props/water.dart:27–35` — `WaterProp` grounded; 기본 `reeds: true`.
- `packages/provis/lib/src/props/building.dart:14–16, 92–99` — 기본 `WallStyle.timber`; **`tileWidth` 기본 156** (게임 128과 다름).
- `packages/provis/lib/src/flame/iso_scene.dart:84–133, 47–65` — 예제용 단일 씬; `addProp` 이 `grid.blockFootprint` 호출.
- `packages/provis/example/lib/screens/game_map.dart:166–179` — **15×15**, `IsoView(150,75)` (README/공개 예시의 156과 별개).
- `lib/game/entities/cyborg_renderer.dart:12–21, 49–81, 91–100` — 연속 `yaw`; `_cylinderShade`/`_plateShade` 는 `LinearGradient` 3–4단; `drawBody` 공유 API.
- 공유 호출: `player.dart:1218`, `remote_player.dart:435`, `cyborg_portrait.dart:124`, `cyborg_preview.dart:53`.
- `spacetimedb/src/character.rs:23` — `CHARACTER_KINDS = ["male_cyborg","female_cyborg"]` 만.
- `lib/auth/cyborg_kind.dart:12–22` — 서버 id ↔ `assault`/`infiltrator`.
- `lib/game/entities/cyborg_design.dart:178–268` — 키 108 / 102, 동일 진영색, 임플란트·실루엣으로 구분.
- `packages/provis/lib/src/core/shading.dart:91–113, 181–209, 629–649` — 프리셋 ambient 어두움; `Finish` 19종; `Finish.energy` 는 `BlendMode.plus`.
- `packages/provis/lib/src/actor/humanoid_renderer.dart:73–76, 127–168` — 표준 키 180 기준; **`canvas.scale(1, iso.squash)`** 로 몸통 세로 단축.
- `packages/provis/lib/src/actor/spec.dart:151, 169` — `const h = 180.0`.
- `packages/provis/example/lib/characters/recruits.dart:358–453` — 사이보그 톤 `BuiltArtist` 예(kestrel/oreb/vant).
- `packages/provis/README.md:257–264` — 캐릭터 1인 200프레임 실측 8방향 **418 µs** / 360 **284 µs**.
- `test/cyborg_render_snapshot_test.dart:17–45` — 16방향·줌 0.55/0.275 스냅샷; 픽셀 변경 시 재생성.
- `GAME-DESIGN.md:177–178` vs `cyborg_renderer.dart:12–21` — 문서는 `facesRight`/`facesDown`, 코드는 연속 `yaw` (**코드 우선**).

---

## 3. 상세 분석

### 3.1 권위 계층 (어디를 대체하는가)

| 계층 | 권위 | provis 역할 |
|---|---|---|
| 이동·전투·HP·파티·PK | SpacetimeDB + 게임 시스템 | 없음 |
| 격자·통행·청크 스트리밍 | `LevelMap` / `GroundLayer` / `action_rpg_game` 블록 스트림 | bake·장식 **입력만** |
| 깊이 | Flame `IsoEntity.priority` (`iso_entity.dart:39–44`) | **수직 기물은 이 축에 올라야 함** |
| 외형 id | 서버 `kind` 두 문자열 | 클라이언트 해석만; CharacterBuild 서버 저장 비권고 |
| 픽셀 | Canvas | **이식 지점** |

provis 예제 `FieldGame` 은 15×15 + `IsoSceneComponent` + `IsoController` 미니 게임이다 (`game_map.dart:166–179`). Cyborg 는 1006×1006 격자·AOI·24 Hz 서버 tick MMORPG다. **예제 아키텍처로의 전면 대체는 비주얼 개선이 아니라 네트워크/이동 재작성**이다 → 폐기.

### 3.2 세계관 정합 (이번 분석의 핵심 판단)

- **버리지 말 것:** 밝은 데이터 플레이트 + 청록/마젠타 (`palette.dart`, `GAME-DESIGN.md`).
- **그대로 얹지 말 것:** 기본 초록 숲·`WallStyle.timber` 중세 마을·`GroundPatch` 기본 잔디 대역·`reeds: true` 갈대 물가.
- **화해 공식 (채택):** 기물의 **형상 알고리즘**은 빌리고 **색·Finish·서사 이름·배치 밀도**를 사이버로 덮는다. 이미 `WorldTree` 가 “자연 나무가 아니라 데이터 응결”을 증명했다 (`world_tree.dart:14–16`).
  - `TreeProp(kind: dead|pine, canopyColor: 민트/청록, barkColor: 슬레이트)` → 데이터 수관·안테나 고사목.
  - `RockProp(mossy: false, color: 회청/은)` → 결정·파편.
  - `GroundPatch(color: 옅은 청록 얼룩, blades: 0)` → 회로 오염 패치 (초록 잔디 금지).
  - `WaterProp(color: 청록 반투명, reeds: false)` → 콜로이드 풀 (hazard 근처 소량).
  - `MoundProp(grassColor/soilColor 사이버, walkOver: true 낮은 것만)` → 플레이트 융기.
  - `BuildingProp`: timber/thatch **금지**. 필요 시 `stone`+`flat` + **`tileWidth: 128` 명시** + 소량 랜드마크만. 파괴·통행 타워는 `BlockComponent` 유지.

### 3.3 맵: bake vs 깊이 (1차 권고의 구멍)

`GroundLayer` priority 는 `-100000` (`ground_layer.dart:37`) 이라 **항상 모든 액터 아래**다.  
세워진 prop(`TreeProp`/`RockProp`/`MoundProp`/`BuildingProp`, `grounded == false`)을 이 Picture 에 구우면:

- 플레이어가 나무 **뒤로** 들어갈 수 없고,
- `WorldTree`·`BlockComponent` 와 깊이 언어가 갈라진다.

반면 `GroundPatch`·`WaterProp` 은 `grounded: true` 라 **바닥 장식 bake 가 맞다**.

**올바른 이층 구조:**

```text
[유지] LevelMap 통행·타일·블록 데이터
[유지·확장] GroundLayer bake
           + grounded props (GroundPatch, 선택 WaterProp)
[신규] PropEntity(IsoEntity) 스트리밍
           Tree / Rock / Mound (walkable 장식 또는 LevelMap 과 단일 권위)
[유지] BlockComponent · WorldTree · SafeZoneField · Player/Remote/Enemy
```

`IsoSceneComponent.addProp` 의 `blockFootprint` (`iso_scene.dart:128–132`) 를 게임 `LevelMap` 과 병행하면 반드시 어긋난다. 장식은 `walkable: true` 이거나 충돌은 **LevelMap 만** 권위.

`paintIsoGround` (`iso_stage.dart:125+`) 은 작은 맵 전체 재도색용 — **1 km 매 프레임 금지**. 게임은 이미 청크 bake 로 같은 문제를 풀었다.

`paintProp` 의 `squash`≈0.866 (`prop.dart:101–102`) 과 게임 `WorldTree`/블록(squash 없음)은 세로 스케일이 다르다. 수직 prop 이식 시 **(a)** 게임에 맞춘 래퍼로 `prop.paint` 직호출 후 스케일 보정, 또는 **(b)** squash 를 의식한 높이 튜닝이 필요하다. Building 은 내부에서 squash 를 상쇄하므로 (`building.dart:85–91`) 반드시 `tileWidth: 128` 로 맞출 것.

### 3.4 PC: 셰이딩 → 어댑터

**단일 진실 경로 (유지 필수):**

```text
CyborgKind(id) → CyborgDesign → CyborgRenderer.drawBody
  Player · RemotePlayerEntity · CyborgPortrait · CyborgPreviewPainter
```

서버 kind 확장 없이 클라이언트만 다종류 외형을 내면 선택/인게임/원격이 갈라진다.

| 단계 | 내용 | 이유 |
|---|---|---|
| A | `_cylinderShade`/`_plateShade` 를 `paintSurface(…, Finish.metal|energy)` + `rimBand`/`occlude` 로 치환·병행. 색은 `design.armor*`/`accent` 유지 | API·애니·임플란트 유지, 4곳 동시 개선, 위험 최저 |
| B | `CharacterBuild` 두 종 + `HumanoidRenderer` 를 `drawBody` **시그니처 뒤**에 연결 | provis 체형 품질; 고위험 |

**Humanoid 스케일 (1차 보완):**  
표준 `height=180` (`spec.dart:151`) + `canvas.scale(1, iso.squash)` (`humanoid_renderer.dart:168`) → 화면 실효 키 ≈ `180 × heightScale × 0.866`. 게임 102–108 에 맞추려면 **heightScale 만 108/180 이 아니라 squash 까지 나눈 보정**이 필요하다 (예: 목표 108 이면 논리 높이 ≈ 108/0.866 ≈ 125 → heightScale ≈ 125/180). [판단: 구현 시 스냅샷으로 미세 조정]

**무기 이중 렌더:** 게임은 등 홀스터 `showBlade` + 별도 `_renderBladeSwing` (`player.dart:1229+`, `remote_player.dart:447`). provis `WeaponKind` 를 켜면 칼이 두 자루. **1차 어댑터는 `WeaponKind.none`(또는 미장착) + 게임 스윙 유지.**

**조명:** `LightRig.heroic`/`spectral`/`daylight` ambient 는 어두운 씬용 (`shading.dart:25, 106–113, 124–131`). 밝은 월드에는 게임 래퍼 `cyberDaylight`(높은 ambient, 청록 rim, key 차갑고 밝게) 필수. 프리셋 직수입 금지.

**CharacterBuild 초안 [판단]:**  
- assault → `Archetype.paladin`/`berserker`, 무거운 갑옷, `hasPauldrons: true`, metal/accent = `playerArmor`/`playerAccent` (oreb/vant 패턴, `recruits.dart:385–453`).  
- infiltrator → `Archetype.assassin`, 가벼운 갑옷, 긴 머리, kestrel 패턴 (`recruits.dart:362–383`).  
임플란트(흉골 프레임 등)는 Humanoid 에 없음 → 1차는 셰이딩 유지, Humanoid 단계에서는 오버레이 또는 후순위.

### 3.5 성능 (숫자)

| 부하 | 환산 | 16.6 ms 대비 |
|---|---|---|
| PC 1 (README 0.28–0.42 ms) | — | 1.7–2.5% |
| PC 20 | **5.6–8.4 ms** | **34–51%** |
| + 기존 enemy 절차 렌더 다수 | 미실측, 이미 무거움 | 여유 부족 가능 |
| 수직 prop N개를 매 프레임 | 미실측 | **청크/거리 bake·detail 필수** |

완화: grounded bake(기존 GroundLayer 패턴), 수직 prop 도 **청크 단위 Picture 캐시 + IsoEntity 는 위치·priority 만**, 원격 `detail` 감쇠, 멀리 임플란트/prop 생략. 연속 yaw 캐시는 이득 vs 부드러움 트레이드오프 — 게임은 연속 yaw 를 의도적으로 채택 (`cyborg_renderer.dart:12–17`).

### 3.6 아이소 규격

타일 절대 크기는 **게임에 고정(128×64)**. 156/150 으로 올리지 말 것 — 히트·속도·줌·AOI·청크 픽셀이 전 밸런스로 번진다. provis 기본 IsoView 가 이미 128이라 props 접지 투영식 `(x-y)*halfW, (x+y)*halfH` 는 게임 `gridToScreen` 과 동일 계열이다. 고도 스케일(56 vs ~78)은 **z 를 거의 안 쓰는 지면 장식에서는 영향 적고**, Building 층고·Humanoid squash 에서만 의식.

---

## 4. 리스크 · 함정

- **깊이 정렬 붕괴:** 수직 prop 을 `GroundLayer` 에 bake 하면 가림이 영원히 틀림. (1차 최대 함정)
- **이중 충돌:** provis `grid.block` vs `LevelMap` 병행.
- **squash/키 불일치:** `paintProp`·`HumanoidRenderer` 세로 단축 vs 게임 엔티티 무단축.
- **BuildingProp `tileWidth: 156` 기본값** — 미지정 시 타일 접지와 어긋남.
- **판타지 직수입:** timber·초록 잔디·갈대 → 세계관 정합성 실패.
- **스냅샷 파괴:** `test/cyborg_render_snapshot_test.dart` 는 의도적 픽셀 변경 — PNG 재생성·실루엣 테스트(오목 허리 등) 유지.
- **kind 간극:** 서버 2종 고정; 클라이언트만 다종류 외형 금지.
- **이중 무기 / 스윙·클립 불일치** (Humanoid 단계).
- **`Finish.energy` + 밝은 배경** 가산 블렌드 과다 (`shading.dart:637`).
- **프레임 스파이크:** prop bake 예산 없이 가시 청크 일괄 생성 시; GroundLayer 의 `_chunkBudgetPerFrame = 3` 패턴 복제 필수.
- **provis submodule 수정 금지** — 사이버 Finish 는 게임 래퍼 `LightRig`/`Surface` 색으로 우회.
- **문서 함정:** `GAME-DESIGN.md` 방향 불리언은 폐기된 서술; 이행은 코드 `yaw` 계약.

---

## 5. 권고안

> 오케스트레이터는 `lib/**` 만 수정. `packages/provis/**`·서버 kind/reducer 1차 불변.

| 순위 | 권고 | 범위 | 근거 | 리스크 |
|---|---|---|---|---|
| **0** | 신규 `lib/game/visual/provis_bridge.dart`: `kGameIso = IsoView(128,64)`, `LightRig cyberDaylight`, `GamePalette`→`Surface`/`paletteOf` 헬퍼 | 공용 브리지 | `iso_view.dart:16`, `palette.dart`, `shading.dart` 프리셋 ambient | 극저 |
| **1** | **GroundLayer bake 확장:** 청크 시드 결정론으로 `GroundPatch`(청록, blades=0) 소량; hazard 인근만 `WaterProp`(reeds=false). 통행 불변 | 맵 밀도(지면) | `ground_layer.dart:153–208`, `ground.dart:29–66`, `water.dart:27–35` | 중저. bake 시간·메모리. **초록/풀 금지** |
| **2** | **`CyborgRenderer` 셰이딩 이식:** `_cylinderShade`/`_plateShade` → `paintSurface` metal/energy + rim; 시그니처·임플란트·연속 yaw 유지 | PC 가독성 | `cyborg_renderer.dart:49–81`, 공유 4경로 | 중저. 스냅샷 재생성. 패스 비용↑ → detail/부위 제한 |
| **3** | **수직 prop `IsoEntity` 스트리밍:** 가시 청크에 `TreeProp`/`RockProp`/`MoundProp` (사이버 재색, 대부분 walkable 장식). 청크 Picture 캐시 + priority=depth. 안전지대는 기존 WorldTree 와 밀도 조율 | 맵 실루엣 | `iso_entity.dart:39–44`, `world_tree.dart:18–20`, `prop.dart:85–105` | **중고.** 깊이·squash·예산. timber 건물 대량 금지 |
| **4** | **`drawBody` 뒤 Humanoid 어댑터:** assault/infiltrator → `CharacterBuild`; `WeaponKind.none`; heightScale **× squash 보정**; 선택 화면=인게임=원격 동일 경로 | PC 디자인 2단계 | `character_build.dart`, `humanoid_renderer.dart:127–168`, `recruits.dart:358–453` | **고.** 애니 이질감, 임플란트 소실, 스윙 불일치 |
| **5** | `block.dart` / `world_tree.dart` 면을 `paintSurface` 톤으로 정렬; (선택) `enemy.dart` 마젠타 energy 윤곽 | 톤 통일·식별 | `block.dart:12–66`, `palette.dart:89–96` | 저중 / 몹 다수 시 detail 필수 |

### 명시적 비권고

1. `IsoSceneComponent` 로 `ActionRpgGame.world` 교체  
2. `IsoController` 로 이동 대체  
3. `paintIsoGround` 로 1 km 매 프레임  
4. 수직 prop 을 `GroundLayer` Picture 에 통째 bake  
5. 서버 `CHARACTER_KINDS` 확장 없이 클라이언트 다종류 외형  
6. provis 내부 수정으로 사이버 Finish 추가 (게임 래퍼 우선)  
7. timber 마을·녹색 잔디 대량 배치  
8. 타일 규격을 150/156 으로 상향  

### 완료 정의 (사람이 아침에 볼 것)

- [ ] 맵: 안전지대 밖 시야에 기복·파편·데이터 수관이 보이고 **초록 판타지 숲이 아님**  
- [ ] 수직 장식 뒤로 플레이어가 들어가면 **가림이 맞음** (깊이)  
- [ ] PC: 금속/발광 가독성 향상; 선택=인게임=원격 동일  
- [ ] `flutter analyze` clean, 관련 테스트·스냅샷 갱신  
- [ ] 로컬+원격 다수+몹에서 체감 60 fps 근처 (N=1/10/30 프로파일 권장)  
- [ ] 서버 kind·통행·파티/PK 불변  

---

## 6. 불확실 · 미확인

- README **418 µs** 는 이 머신·release/debug·오버레이 미포함 — 통합 후 DevTools 재실측 필요.  
- Prop 종류별 bake µs **미실측** — 1순위 직후 청크 bake 시간 로그 필수.  
- AOI 내 원격 동시 렌더 상한 **미확인**; N=20 은 설계 가정.  
- provis walk/run 클립 vs 게임 대시·밀리 스윙 **시각 대조 미실시**.  
- BuildingProp 사이버 재색만으로 “데이터 센터”로 읽히는지 — 단위 텍스처가 돌/벽돌이라 한계 가능; 소량 A/B.  
- `Finish.energy` 과다 노출 — 스크린샷 튜닝.  
- 라리엔 비주얼 관례는 이번 범위에서 미열람.  

---

## 7. 자기 비판으로 바로잡은 것

- ❌ **철회:** “PropDecorLayer 를 GroundLayer 와 같이 청크 Picture 에 통째 bake” — 수직 prop 은 `GroundLayer` priority `-100000` 아래 고정되어 깊이 가림이 깨짐 (`ground_layer.dart:37`, `iso_entity.dart:39–44`, `prop.dart:39–42`). **grounded bake / 수직 IsoEntity 로 분리.**  
- ❌ **철회:** Humanoid 를 “height 를 totalHeight 에 맞게 스케일”만 하면 된다 — `HumanoidRenderer.paint` 가 `canvas.scale(1, iso.squash)` 를 적용 (`humanoid_renderer.dart:168`). squash(≈0.866) 미보정 시 키가 ~13% 낮음.  
- 🔁 **수정:** 예제 맵 타일 “156×78” 일반화 → 실제 `game_map.dart` 는 **`IsoView(150, 75)`, 15×15** (`game_map.dart:166–168`). 공개 문서 예시 156과 혼동하지 말 것.  
- 🔁 **수정:** 실행 순서 “맵 장식 전체 → PC 셰이딩” → **① grounded bake → ② PC 셰이딩 → ③ 수직 IsoEntity**. 맵 시각 이득은 유지하되 1차의 깊이 위험을 반영.  
- 🔁 **수정:** pubspec 인용 `42–45` 은 주석 포함 구간; 의존성 본체는 **`44–45`**.  
- ➕ **추가:** `BuildingProp` **기본 `tileWidth: 156`** (`building.dart:96`) — 게임 128 월드에 넣을 때 필수 인자.  
- ➕ **추가:** `paintProp` squash 와 게임 `WorldTree`/블록 무단축 불일치 — 수직 prop 래퍼에서 스케일 정책 명시 필요.  
- ➕ **추가:** 1차 성능표의 “Prop 100개 매 프레임” 비용은 여전히 `[추측]`; bake 전략의 근거는 구조(깊이·예산)이지 실측 µs 가 아님을 명시.  
- 살아남은 핵심: 전면 `IsoScene` 교체 폐기, 세계관 유지+재색 확장, kind 2종 유지, 셰이딩→Humanoid 2단 PC 이행, README 418 µs 인용 및 N명 환산 경계.
