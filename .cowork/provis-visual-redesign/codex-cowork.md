<!-- cowork:codex | 2026-08-06 19:32:24 | exit=0 | 552s -->
# codex 분석 — provis-visual-redesign

> 요청: provis git repo 의 https://github.com/thruthesky/provis 패키지를 통해서 현재 cyborg 게임의 비주얼적 디자인을 업데이트 해 주세요.

git repo 의 provis 패키지를 git submodule 로 ./packages/provis 폴더로 submodule add 하고 -> pubspec.yaml 에 dependencies 로 추가한 다음 -> 이 패키지를 활용하여 -> cybord 게임의 멋진 pc 디자인, 게임 맵 디자인을 해 주세요.

사람 개발자는 잠을 자러 갔습니다. 당신이 모든 작업을 진행해서 끝까지 완료해주세요.

[오케스트레이터 주석 — 분석 전에 이미 끝난 것]
- git submodule add https://github.com/thruthesky/provis packages/provis → 완료. 소스가 실제로 작업공간의 packages/provis 에 있으니 직접 열어서 읽어라. README 만 보고 API 를 상상하지 마라.
- pubspec.yaml dependencies 에 provis: {path: packages/provis} 추가 → 완료. flutter pub get 통과 확인.

그러므로 '어떻게 submodule 을 추가하는가' 는 분석 대상이 아니다. 분석할 것은 '이미 붙어 있는 provis 를 이 게임의 어디에, 어떤 순서로, 무엇을 대체하며 넣어서 멋진 PC 디자인과 게임 맵 디자인을 만들 것인가' 이며, 오케스트레이터가 사람이 자는 동안 곧바로 코드를 고칠 수 있을 만큼 구체적인 실행 순서(파일·함수·위험)가 나와야 한다.
> 생성: 2026-08-06 19:32:24 · 소요 552s · 읽기 전용 분석(작업공간 미수정)

---



## 1. 결론 요약

현재 `CyborgRenderer`를 `BuiltArtist`/`HumanoidSpec`으로 전면 교체해서는 안 된다. 기존의 VULCAN/WRAITH 실루엣·임플란트·서버 `kind` 호환성을 유지하면서, provis의 `LightRig`·`Surface`·`paintSurface`·`rimBand`·`occlude`를 선택적으로 이식하는 하이브리드가 가장 안전하다. `lib/game/entities/cyborg_design.dart:5-16`, `packages/provis/lib/src/actor/character_build.dart:95-115`

맵은 `GroundLayer`·`LevelMap`을 그대로 지형·충돌의 단일 진실로 유지하고, provis 기물을 “판타지 숲”이 아니라 청록 데이터 생태계·마젠타 오염 지대로 재색칠하여 청크 캐시와 기존 깊이 정렬에 삽입해야 한다. `lib/game/level/ground_layer.dart:35-50`, `lib/game/level/level_map.dart:143-175`, `lib/game/palette.dart:3-9`

아이소 규격은 게임의 128×64를 유지해야 한다. `IsoSceneComponent`나 `paintScene`으로 월드 전체를 대체하지 말고, 저수준 `Prop`·셰이딩 API만 사용해야 한다. `lib/game/iso.dart:5-15`, `packages/provis/lib/src/flame/iso_scene.dart:137-177`

최대 51명의 플레이어를 모두 매 프레임 provis로 직접 그리면 캐릭터만 14.48–21.32 ms가 걸릴 수 있으므로, 원격 캐릭터용 방향·동작·프레임 캐시를 먼저 갖추는 것이 필수다. `lib/game/action_rpg_game.dart:243-248`, `packages/provis/README.md:251-267`

## 2. 근거

- `pubspec.yaml:42-45`, `.gitmodules:1-3` — provis는 이미 `packages/provis` 경로 의존성과 git submodule로 등록되어 있다.
- `lib/game/entities/cyborg_renderer.dart:8-24`, `lib/game/entities/player.dart:1184-1227`, `lib/game/entities/remote_player.dart:418-453` — 로컬·원격 플레이어가 동일한 절차적 `CyborgRenderer`를 사용한다.
- `lib/auth/cyborg_portrait.dart:93-132`, `lib/game/ui/cyborg_preview.dart:37-63` — Flutter 캐릭터 선택 화면과 게임 프리뷰도 같은 렌더러를 공유한다.
- `lib/game/entities/cyborg_design.dart:173-268` — VULCAN과 WRAITH는 몸통 폭, 허리, 다리, 목 등 서로 다른 고유 실루엣을 갖는다.
- `lib/auth/cyborg_kind.dart:3-22`, `spacetimedb/src/character.rs:17-33` — 클라이언트와 서버가 `male_cyborg`·`female_cyborg` 두 식별자를 계약으로 공유한다.
- `packages/provis/lib/provis.dart:34-82` — 공개 API에는 셰이딩, `Artist`, `BuiltArtist`, `CharacterBuild`, 아이소 도구와 각종 `Prop`이 실제로 export되어 있다.
- `packages/provis/lib/src/actor/character_build.dart:95-115` — `CharacterBuild.sex`는 저장되지만 `toSpec()`에서 체형 생성에 사용되지 않는다.
- `packages/provis/lib/src/actor/humanoid_renderer.dart:73-122` — `Body`를 넘길 수 있어도 다수의 부위 폭과 장비 표현은 계속 `HumanoidSpec` 및 판타지 재질 규칙에서 파생된다.
- `packages/provis/lib/src/core/shading.dart:180-233`, `packages/provis/lib/src/core/shading.dart:270-335` — 19종 `Finish`를 가진 `Surface`와 `paintSurface`를 독립적으로 사용할 수 있다.
- `lib/game/level/ground_layer.dart:153-208`, `lib/game/level/ground_layer.dart:355-377` — 지면은 32타일 단위 `ui.Picture`로 구워지며 동적 방화벽 효과만 매 프레임 그린다.
- `packages/provis/lib/src/flame/iso_scene.dart:137-177` — `IsoSceneComponent`는 사각 지면 전체와 보유한 모든 기물을 매 프레임 순회하며 그린다.
- `packages/provis/lib/src/iso/iso_view.dart:15-46`, `lib/game/iso.dart:5-15` — provis의 기본 타일도 128×64지만, provis의 고도 스케일은 약 78.38이고 게임의 `kHeightUnit`은 56이다.
- `packages/provis/README.md:251-267`, `packages/provis/example/test/facing_sweep_test.dart:43-68` — 문서 실측은 캐릭터 1인당 8방향 418 µs, 360방향 284 µs이나, 측정 루프는 `PictureRecorder` 기록까지만 포함한다.
- `lib/game/level/world_tree.dart:9-20`, `lib/game/level/world_tree.dart:156-205` — 프로젝트에는 이미 “데이터에서 자라난 나무”라는 세계관 정합적 자연물 해석과 회로형 줄기 표현이 있다.
- `lib/game/palette.dart:79-114` — 어두운 청록 플레이어, 마젠타 적, 청색 그림자·효과라는 전투 식별 색 체계가 이미 정의되어 있다.

## 3. 상세 분석

### PC 디자인

`BuiltArtist` 전면 전환은 현재 외형 계약보다 표현력이 낮다. `CharacterBuild`에는 `sex`가 있지만 실제 `HumanoidSpec` 생성에 반영되지 않고, 사이보그 임플란트·오목한 WRAITH 허리·VULCAN의 두꺼운 흉곽 같은 직접 제어점도 없다. `lib/game/entities/cyborg_design.dart:167-217`, `packages/provis/lib/src/actor/character_build.dart:95-115`

따라서 `CyborgDesign`을 골격과 실루엣의 단일 진실로 남기고 다음 재질만 provis로 옮기는 것이 적합하다.

- 장갑 플레이트: `Finish.metal`
- 관절 아래 유연 소재: `Finish.cloth`
- 노출 피부: `Finish.skin`
- 눈·흉부 코어·임플란트·블레이드: `Finish.energy`
- 겹치는 관절과 장갑 아래: `occlude`
- 밝은 바닥에서 죽는 외곽선: 제한적인 `rimBand`

이 조합은 현재 그리기 순서를 유지하면서도 재질별 명암을 개선할 수 있다. `CyborgRenderer.drawBody()`는 이미 몸체 부위를 순서대로 합성하고 있으므로, 기존 경로와 치수를 버리지 않고 내부의 그라디언트·면 채색만 단계적으로 치환할 수 있다. `lib/game/entities/cyborg_renderer.dart:83-135`, `lib/game/entities/cyborg_renderer.dart:42-80`

색은 provis 기본 팔레트를 사용하지 않고 `GamePalette`에서 공급해야 한다. 로컬 플레이어는 어두운 남청 장갑과 청록 코어, 적은 마젠타, 원격 플레이어 상태 표시는 앰버 링으로 유지해야 군중 속 진영 판독이 보존된다. `lib/game/palette.dart:79-96`, `lib/game/palette.dart:130-134`

게임 쪽에 `CyborgArtist implements Artist` 어댑터를 두는 것은 가능하지만, `riggedFromArtist()`나 `HumanoidRenderer`로 본체를 넘기기 위한 용도로 사용해서는 안 된다. 어댑터의 `paint()`가 하이브리드 `CyborgRenderer`를 호출하도록 하여 Flutter 초상·Flame 게임 화면의 동일성만 보장하는 편이 안전하다. `packages/provis/lib/src/art/creature.dart:33-66`

또한 `BuiltArtist`의 초상은 기본 seed로 `id.hashCode`를 쓰지만, rigged actor 생성 경로는 `Rng.fromString(id)`를 fallback으로 사용한다. seed가 생략된 `CharacterBuild`는 초상과 게임 배우의 체형이 달라질 가능성이 있다. `packages/provis/lib/src/actor/built_artist.dart:121-128`, `packages/provis/lib/src/art/artist_rig.dart:29-49` 이 불일치도 직접 전환을 피해야 하는 이유다.

### 캐릭터 성능

문서 수치를 그대로 환산하면 최대 51명은 다음과 같다.

| 조건 | 20명 | 51명 | 60 fps 예산 대비 |
|---|---:|---:|---|
| 8방향 418 µs | 8.36 ms | 21.32 ms | 51명에서 이미 16.6 ms 초과 |
| 360방향 284 µs | 5.68 ms | 14.48 ms | 맵·최대 360 몬스터·UI에 2.12 ms만 남음 |

플레이어 상한은 로컬 1명과 원격 50명이며, 몬스터 활성 상한도 360개다. `lib/game/action_rpg_game.dart:230-248` 측정치에 rasterization과 GPU 합성이 포함되지 않았으므로 실제 모바일 비용은 이 표보다 낮다고 단정할 수 없다. `packages/provis/example/test/facing_sweep_test.dart:43-68`

[판단] 로컬 플레이어와 초상은 연속 yaw·고해상도 라이브 렌더를 허용하되, 원격 플레이어는 `(kind, action, 16방향, animationPhase, detailTier, lightRig)` 키의 `ui.Picture` 또는 `ui.Image` 캐시를 사용해야 한다. 체력바·파티 링·피격 점멸·코어 pulse만 별도 저비용 오버레이로 남긴다. 기존 스냅샷도 16방향을 사용하므로 캐시 방향 규격과 맞출 수 있다. `test/cyborg_render_snapshot_test.dart:11-19`

### 맵 디자인

`IsoSceneComponent`는 1 km 월드에 적합하지 않다. 기존 지면은 보이는 청크만 LRU로 유지하고 프레임당 최대 세 청크만 굽지만, `IsoSceneComponent`는 자체 `IsoGrid`·기물·배우 목록을 소유하며 매 프레임 전체 지면과 기물을 순회한다. `lib/game/level/ground_layer.dart:35-50`, `packages/provis/lib/src/flame/iso_scene.dart:84-116`, `packages/provis/lib/src/flame/iso_scene.dart:137-177`

따라서 결합 경계는 다음과 같아야 한다.

1. `LevelMap`이 타일 종류·통행·구조물의 단일 진실을 계속 담당한다. `packages/provis`의 `IsoGrid.addProp()`으로 별도 충돌 지도를 만들지 않는다. `lib/game/level/level_map.dart:143-213`, `packages/provis/lib/src/flame/iso_scene.dart:124-135`
2. 바닥 얼룩·회로 경로·얕은 데이터 웅덩이처럼 grounded이고 정적인 표현은 `GroundLayer` 청크의 `ui.Picture`에 함께 굽는다.
3. 나무·바위·건물처럼 높이가 있고 청크 밖으로 돌출되는 기물은 `IsoEntity` 기반 게임 컴포넌트로 만들고, 현재 priority/depth 및 가시 범위 스트리밍을 사용한다. `lib/game/entities/iso_entity.dart:39-50`, `lib/game/action_rpg_game.dart:1377-1446`
4. 게임 컴포넌트가 이미 `gridToScreen()` 위치로 이동한 뒤라면 `PropInstance.tile`은 원점으로 두거나 `prop.paint()`를 로컬 좌표에서 호출해야 한다. 다시 월드 타일을 `paintProp()`에 전달하면 이중 투영된다. `packages/provis/lib/src/props/prop.dart:50-106`
5. 초기 월드 배선뿐 아니라 재시작 경로에도 새 장식 레이어와 스트리밍 상태의 생성·해제가 동일하게 들어가야 한다. `lib/game/action_rpg_game.dart:277-301`, `lib/game/action_rpg_game.dart:2144-2175`

아이소 크기는 게임의 128×64를 유지하고 `IsoView(tileWidth: kTileWidth, tileHeight: kTileHeight)`로 명시해야 한다. 예제의 150×75 또는 README의 156×78을 채택하면 화면 픽셀 크기가 약 21.9% 커져 카메라 줌·선택 좌표·가시 타일 수가 함께 달라진다. `packages/provis/example/lib/screens/game_map.dart:166-179`, `packages/provis/README.md:48-56`

provis의 z 투영은 현재 게임과도 다르다. 128×64 기준 `IsoView.heightScale`은 약 78.38이지만 게임은 56이다. [판단] 일반 기물의 지면 anchor와 자체 높이 그림은 사용할 수 있으나, 공중 이동·발사체·게임플레이 고도에는 provis의 `project(..., wz)`를 사용하지 말고 기존 `gridToScreen()`과 `kHeightUnit`을 유지해야 한다. `packages/provis/lib/src/iso/iso_view.dart:35-46`, `lib/game/iso.dart:58-77`

### 세계관 및 아트 디렉션

가장 적합한 방향은 자연 판타지로 세계관을 바꾸는 것이 아니라 기존 `WorldTree` 개념을 확장한 “데이터 생태계”다. `lib/game/level/world_tree.dart:9-20`

- `TreeProp`: 잎을 자연 녹색 대신 흰색·청록으로, 줄기를 남청·회색으로 제한하여 광섬유 군락이나 손상된 데이터 수목으로 해석한다. 바람 흔들림은 멀리서도 지형 구역을 구분하는 데만 약하게 사용한다. `packages/provis/lib/src/props/tree.dart:54-159`
- `RockProp`: `mossy: false`, 밝은 회색·청록 shard 조합으로 체크섬 파편이나 붕괴한 데이터 블록을 만든다. `packages/provis/lib/src/props/rock.dart:25-64`
- `WaterProp`: reeds를 제거하고 얕은 청록 반사면으로 사용한다. 일반 파란 연못은 배제한다. `packages/provis/lib/src/props/water.dart:28-86`
- `LavaProp`: 마젠타·적색의 “corruption pool”로 기존 `TileType.hazard`에만 제한한다. 단 provis `LavaProp`의 `walkable` 의미와 실제 hazard 통행 규칙을 결합하지 말고, 충돌은 `LevelMap`을 따른다. `packages/provis/lib/src/props/water.dart:295-329`, `lib/game/level/level_map.dart:9-34`
- `GroundPatch`·`PathPatch`: 백색 플레이트 위의 회로 흔적과 데이터 흐름으로 청크에 굽는다. `packages/provis/lib/src/props/ground.dart:29-66`, `packages/provis/lib/src/props/ground.dart:192-233`
- `BuildingProp`: 대량 사용하지 않는다. 현재 벽·지붕 enum은 판타지 계열이므로, `RoofStyle.flat`, 흰색·청록, chimney 제거 조건의 희귀한 archive vault에만 시험한다. 주 구조물은 기존 `BlockComponent` 데이터 타워가 세계관에 더 맞는다. `packages/provis/lib/src/props/building.dart:13-62`, `lib/game/entities/block.dart:101-220`

[판단] 바닥의 대부분은 전투 판독을 위해 깨끗한 발광 플레이트로 남기고, 기물은 랜드마크와 소규모 군락으로 집중해야 한다. 전역에 수풀·꽃·바위를 흩뿌리면 캐릭터 실루엣과 공격 표시가 자연물의 세부 묘사에 묻힌다.

## 4. 리스크 · 함정

- `CharacterBuild.sex`가 체형에 반영되지 않으므로 직접 전환하면 VULCAN/WRAITH의 성별·실루엣 차이가 사실상 사라진다. `packages/provis/lib/src/actor/character_build.dart:95-115`
- `CyborgRenderer`의 공유 계약을 끊으면 캐릭터 선택 Flutter 화면과 Flame 게임 화면의 외형이 달라진다. `lib/auth/cyborg_portrait.dart:10-14`, `lib/game/ui/cyborg_preview.dart:10-14`
- 서버 `kind`를 `Archetype`이나 provis ID로 바꾸면 서버 whitelist와 원격 동기화가 깨진다. 서버 ID는 그대로 두고 클라이언트에서만 디자인을 매핑해야 한다. `spacetimedb/src/character.rs:17-33`, `lib/game/entities/remote_player.dart:150-158`
- provis 기본 조명·색·꽃·녹색 수풀을 그대로 쓰면 “빛으로 가득 찬 사이버 스페이스”라는 팔레트 원칙과 충돌한다. `lib/game/palette.dart:3-9`
- `IsoSceneComponent` 도입은 기존 `GroundLayer` 캐시·`LevelMap` 충돌·Flame priority라는 세 체계와 중복된다. `packages/provis/lib/src/flame/iso_scene.dart:84-177`
- 지면용 기물이 청크 경계를 넘으면 잘림이나 이음새가 생길 수 있다. [판단] 청크 bake 범위를 기물 반경만큼 확장하거나, 높이 있는 기물은 별도 컴포넌트로 분리해야 한다.
- `ui.Picture`·`ui.Image` 캐시는 상한과 명시적 dispose가 없으면 방향·동작 조합 수만큼 누적된다. provis의 `BakedPart`도 소유자가 `dispose()`해야 한다. `packages/provis/lib/src/iso/iso_view.dart:264-295`
- `test/cyborg_render_snapshot_test.dart`는 이름과 달리 환경 변수가 없으면 PNG를 쓰지 않고, 주 검증도 이미지 크기와 설계 수치다. 시각 회귀가 자동으로 실패한다고 가정해서는 안 된다. `test/cyborg_render_snapshot_test.dart:21-24`, `test/cyborg_render_snapshot_test.dart:28-72`
- `test/monster_render_path_test.dart`는 픽셀보다 컴포넌트 수·위치·배선을 검증하므로 맵 스트리밍 구조를 바꿀 때 깨질 가능성이 있다. `test/monster_render_path_test.dart:68-152`
- `test/mute_button_snapshot_test.dart`는 PC·맵 변경과 무관한 UI 테스트다. 불필요하게 기준을 갱신하면 별도 회귀를 숨길 수 있다. `test/mute_button_snapshot_test.dart:37-63`
- 프로젝트 프롬프트에는 서버 24 Hz라고 되어 있지만 현재 구현은 10 Hz이며 밀집 시 4 Hz까지 낮아진다. 시각 프레임 예산은 여전히 60 fps 기준 16.6 ms이지만, 성능 측정 보고서에서 네트워크 tick과 렌더 프레임을 혼동하면 안 된다. `spacetimedb/src/world.rs:141-172`, `lib/spacetime/spacetime_world_presence.dart:25-83`

## 5. 권고안

| 순위 | 권고 | 범위 | 근거 | 리스크 |
|---|---|---|---|---|
| 1 | 게임 쪽 공통 `LightRig`·`Surface` 카탈로그와 캐릭터 캐시를 먼저 정의한 뒤, `CyborgRenderer.drawBody()`의 플레이트·피부·관절·에너지 면을 `paintSurface`로 단계 교체한다. VULCAN/WRAITH 경로와 치수는 보존한다. 시각적 이득: 재질·광원·림라이트가 즉시 통일된다. | `lib/game/entities/cyborg_renderer.dart`, `lib/game/entities/cyborg_design.dart`, 신규 게임 측 `lib/game/visual/provis_visuals.dart`, `lib/game/visual/cyborg_render_cache.dart` | `lib/game/entities/cyborg_renderer.dart:42-135`, `packages/provis/lib/src/core/shading.dart:180-335` | 기존 그리기 경계를 한 번에 모두 바꾸면 장갑 겹침과 방향별 실루엣이 깨질 수 있으므로 부위별 전환이 필요하다. |
| 2 | 캐시는 `(kind, action, 16방향, animationPhase, detailTier, lightRig)`로 제한하고 로컬만 최고 품질 라이브 렌더, 원격은 캐시 재생으로 연결한다. 시각적 이득: 다중 접속 상황에서도 새 재질을 유지한다. | `lib/game/entities/player.dart`, `lib/game/entities/remote_player.dart`, 캐시 모듈 | `lib/game/action_rpg_game.dart:243-248`, `packages/provis/README.md:251-267` | 캐시 상한·LRU·dispose가 없으면 메모리 사용량이 폭증한다. 방향 전환 시 프레임 튐도 점검해야 한다. |
| 3 | 기존 renderer 호출 계약을 유지하거나 `CyborgArtist` 어댑터 하나로 감싸서 캐릭터 선택 초상·프리뷰·인게임이 같은 디자인을 사용하게 한다. 서버 ID는 계속 `male_cyborg`·`female_cyborg`로 둔다. | `lib/auth/cyborg_portrait.dart`, `lib/game/ui/cyborg_preview.dart`, `lib/auth/cyborg_kind.dart` | `lib/auth/cyborg_portrait.dart:93-132`, `spacetimedb/src/character.rs:17-33` | 초상과 인게임에 다른 seed·light·scale을 적용하면 동일성 계약이 깨진다. |
| 4 | 중앙 `WorldTree`를 첫 맵 쇼케이스로 삼아 provis의 metal/energy 셰이딩과 `TreeProp`의 가지·바람 표현을 “데이터 수목” 색으로 해석한다. 시각적 이득: 구조·충돌을 바꾸지 않고 중앙 랜드마크 품질이 크게 상승한다. | `lib/game/level/world_tree.dart`, `lib/game/palette.dart`, 공통 시각 모듈 | `lib/game/level/world_tree.dart:9-20`, `packages/provis/lib/src/props/tree.dart:54-159` | 자연 녹색이나 과도한 발광을 쓰면 세계관과 전투 가독성을 해친다. 기존 높이 스냅샷도 재확인해야 한다. |
| 5 | `GroundLayer`의 청크 bake 단계에 `GroundPatch`·`PathPatch`·얕은 Water 표현을 결정론적으로 추가한다. 실제 타일·통행은 `LevelMap`만 사용한다. 시각적 이득: 1 km 플레이트가 반복 바닥이 아니라 구역과 흐름으로 읽힌다. | `lib/game/level/ground_layer.dart`, `lib/game/level/level_map.dart`, 신규 게임 측 `lib/game/level/provis_prop_catalog.dart` | `lib/game/level/ground_layer.dart:153-208`, `packages/provis/lib/src/props/ground.dart:29-66` | resolved seed를 보관하지 않으면 청크 재생성 시 장식이 바뀔 수 있다. 경계 기물의 소유 청크 규칙도 필요하다. |
| 6 | 높이 있는 `TreeProp`·`RockProp`·오염 pool·희귀 archive vault는 `IsoEntity` 기반 `ProvisPropComponent`로 감싸고 기존 구조물 청크 스트리밍과 priority 정렬에 연결한다. 초기화와 restart 경로를 함께 갱신한다. | 신규 게임 측 기물 컴포넌트, `lib/game/action_rpg_game.dart` | `lib/game/entities/iso_entity.dart:39-50`, `lib/game/action_rpg_game.dart:1377-1446`, `lib/game/action_rpg_game.dart:2144-2175` | 월드 좌표를 `paintProp()`에 다시 넘기면 이중 투영된다. 기물 자체의 `walkable`을 게임 충돌로 사용해서도 안 된다. |
| 7 | 판타지 기물은 기본값을 금지하고 “archive grove / checksum shard / corruption pool / data vault” 프리셋만 허용한다. `BuildingProp`은 flat roof 희귀 랜드마크에서만 시험한다. | 게임 측 기물 카탈로그와 팔레트 | `packages/provis/lib/src/props/building.dart:13-62`, `lib/game/palette.dart:29-55` | 프리셋 규칙 없이 API를 직접 호출하면 구역마다 자연색과 광원이 달라져 아트 디렉션이 붕괴한다. |
| 8 | 마지막으로 `flutter analyze`·`flutter test`, 16방향 PC 시트, `preview_main.dart`·`offline_main.dart` DTD 스크린샷, 1/12/20/51명 플레이어 부하를 각각 검증한다. 실제 이미지 차이를 보는 golden 또는 허용오차 기반 비교도 추가 대상으로 삼는다. | `test/cyborg_render_snapshot_test.dart`, `test/world_tree_snapshot_test.dart`, `lib/preview_main.dart`, `lib/offline_main.dart` | `lib/preview_main.dart:5-15`, `lib/offline_main.dart:7-16`, `test/world_tree_snapshot_test.dart:12-45` | 단일 캐릭터 프리뷰만 확인하면 군중 밀집과 맵 장식의 raster 비용을 놓친다. |

## 6. 불확실 · 미확인

- provis 셰이딩을 Flutter 지원 대상별 GPU에서 rasterize했을 때의 실제 시간과 메모리 사용량은 현재 벤치마크만으로 확인되지 않는다. 대상 모바일·데스크톱 기기에서 별도 profile이 필요하다. `packages/provis/example/test/facing_sweep_test.dart:43-68`
- 월드 seed가 서버에서 영속적으로 제공되는지, 클라이언트 `LevelMap.generate()`의 seed가 재접속·재시작 동안 동일하게 보존되는지는 추가 추적이 필요하다. `lib/game/level/level_map.dart:251-266`
- 화면 내 일반적인 원격 플레이어·몬스터 수의 실제 분포는 상한만 확인되었고 운영 telemetry는 확인하지 못했다. 캐시 품질 단계의 임계치는 측정 후 확정해야 한다.
- `BuildingProp`의 판타지 표면을 색만 바꿔도 충분히 사이버 건축으로 읽힐지는 사람의 아트 리뷰가 필요하다. 부족하면 provis submodule 수정 대신 게임 측 custom `Prop`을 우선 작성해야 한다.
- 파티원 전용 강조색의 최종 규칙은 확인하지 못했다. 현재 확인된 `GamePalette.remotePlayer` 앰버를 일반 원격 표시로 유지하되, 파티 색은 기존 전투 UI 규칙을 추가 조사한 뒤 결정해야 한다.
