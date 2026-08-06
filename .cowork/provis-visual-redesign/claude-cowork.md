<!-- cowork:claude | 2026-08-06 19:45:12 | exit=0 | 387s -->
# claude 분석 — provis-visual-redesign

> 요청: provis git repo 의 https://github.com/thruthesky/provis 패키지를 통해서 현재 cyborg 게임의 비주얼적 디자인을 업데이트 해 주세요.

git repo 의 provis 패키지를 git submodule 로 ./packages/provis 폴더로 submodule add 하고 -> pubspec.yaml 에 dependencies 로 추가한 다음 -> 이 패키지를 활용하여 -> cybord 게임의 멋진 pc 디자인, 게임 맵 디자인을 해 주세요.

사람 개발자는 잠을 자러 갔습니다. 당신이 모든 작업을 진행해서 끝까지 완료해주세요.

[오케스트레이터 주석 — 분석 전에 이미 끝난 것]
- git submodule add https://github.com/thruthesky/provis packages/provis → 완료. 소스가 실제로 작업공간의 packages/provis 에 있으니 직접 열어서 읽어라. README 만 보고 API 를 상상하지 마라.
- pubspec.yaml dependencies 에 provis: {path: packages/provis} 추가 → 완료. flutter pub get 통과 확인.

그러므로 '어떻게 submodule 을 추가하는가' 는 분석 대상이 아니다. 분석할 것은 '이미 붙어 있는 provis 를 이 게임의 어디에, 어떤 순서로, 무엇을 대체하며 넣어서 멋진 PC 디자인과 게임 맵 디자인을 만들 것인가' 이며, 오케스트레이터가 사람이 자는 동안 곧바로 코드를 고칠 수 있을 만큼 구체적인 실행 순서(파일·함수·위험)가 나와야 한다.

[시간 배분 조언] 앞선 시도에서 900초 제한을 넘겨 실패했다. 모든 파일을 완독하려 하지 말고, 핵심 파일(packages/provis/lib/provis.dart, packages/provis/lib/src/iso/*, packages/provis/lib/src/actor/*, packages/provis/example/lib/screens/game_map.dart, lib/game/entities/cyborg_renderer.dart 의 drawBody 시그니처, lib/game/iso.dart, lib/game/level/ground_layer.dart, lib/game/palette.dart)만 표적 독해하고 결론을 내라.
> 생성: 2026-08-06 19:45:12 · 소요 387s · 읽기 전용 분석(작업공간 미수정)

---



## 1. 결론 요약

**PC 렌더러를 provis 로 전면 대체하지 말고, 맵부터 고쳐라.** 결정적 사실 세 가지가 이 순서를 강제한다. ① provis `IsoView` 의 **기본값이 이미 128×64 라 게임 투영과 완전히 같다**(`iso_view.dart:16` vs `lib/game/iso.dart:6-9`) — 좌표계 이행 비용은 0 이고, 시스템 프롬프트가 우려한 "156×78 과의 절대 크기 차이"는 예제 화면의 선택일 뿐 패키지 규격이 아니다. ② provis 캐릭터 체계의 어휘는 **판타지 전용**이다(`Archetype {knight…paladin}`·`WeaponKind {sword…bow}`·`HeadGear {…hornedHelm}`, `spec.dart:8,21,23`) — 사이보그 임플란트·바이저·동력팩·에너지 블레이드를 담을 자리가 없어, 옮기는 순간 세계관이 무너지고 스냅샷 테스트·초상 공유(`cyborg_portrait.dart:124`)·`kind` 매핑(`remote_player.dart:154`)이 한꺼번에 깨진다. ③ 반면 **지면은 진짜로 비어 있다** — `GroundLayer._bakeChunk` 는 단색 마름모 fill + 격자선 + 배선이 전부이고(`ground_layer.dart:192-201`), provis 가 "장판이 되지 않으려면 반드시 필요하다"고 명시한 세 겹(얼룩 층위·거리 감쇠·가장자리 두께, `iso_stage.dart:110-122`)이 하나도 없다.

따라서 **1순위는 `paintIsoGround` 의 기법을 청크 굽기 안으로 이식하는 것**이다. `ui.Picture` 캐시 안에서 일어나므로 런타임 프레임 비용이 0 이고, 깨질 테스트가 없으며, 화면 전체가 한 번에 달라진다. PC 는 `paintSurface` + `BakedPart` 로 **셰이딩만 빌리는 3순위**다.

## 2. 근거

- `packages/provis/lib/src/iso/iso_view.dart:16` — `const IsoView({this.tileWidth = 128, this.tileHeight = 64})`. 게임의 `kTileWidth = 128`·`kTileHeight = 64`(`lib/game/iso.dart:6,9`)와 **동일**. 예제가 150×75 를 쓰는 것은 `example/lib/screens/game_map.dart:168` 한 줄의 선택이다.
- `packages/provis/lib/src/iso/iso_view.dart:37` — `heightScale => tileWidth * squash / sqrt2` = 128×0.866/1.414 ≈ **78.4**. 게임 `kHeightUnit = 56`(`lib/game/iso.dart:15`). **고도 단위만 어긋난다** — 평면은 같고 z 만 다르다.
- `packages/provis/lib/src/actor/spec.dart:8,21,23` — `enum Archetype { knight, berserker, ranger, mage, assassin, paladin }` / `WeaponKind { sword, greatsword, axe, staff, spear, daggers, bow, none }` / `HeadGear { none, circlet, hood, halfHelm, fullHelm, hornedHelm }`. 사이보그 어휘 없음.
- `packages/provis/lib/src/core/shading.dart:181-209` — `Finish` 19종에 `metal`·`gem`·`energy`·`stone` 포함. **재질 셰이딩 어휘는 사이버에 충분하다** — 부족한 것은 캐릭터 골격 어휘뿐이다.
- `packages/provis/lib/src/iso/iso_stage.dart:110-122` — 지면 주석: "타일마다 명도를 번갈아 칠하면 지면이 **장판**이 된다 … ① 큰 얼룩 → 작은 얼룩의 층위 ② 거리 감쇠 ③ 가장자리의 흙 두께".
- `lib/game/level/ground_layer.dart:193-197` — 실제로 `plateEven`/`plateOdd` 를 `floorBase`/`floorAlt` **단색으로 번갈아 칠한다.** 위 주석이 지목한 그 장판이다.
- `lib/game/level/ground_layer.dart:153-208` — 청크는 `ui.Picture` 로 한 번 굽고 재생만 한다. **여기 무엇을 더 그리든 매 프레임 비용은 늘지 않는다.**
- `packages/provis/README.md:257-264` — 캐릭터 1인 200프레임 반복 실측: 8분할 418 µs / 16분할 295 µs / 32분할 260 µs / 360분할 284 µs.
- `lib/game/action_rpg_game.dart:248` — `static const int _maxRemotePlayers = 50`. 위 수치를 곱하면 원격 20명만 그려도 **5.2~8.4 ms**, 60 fps 예산 16.6 ms 의 31~50%.
- `test/cyborg_render_snapshot_test.dart:36-45` — 캐릭터 키 108px, 기본 하한 줌 0.55 → **59px**, 극단 0.275 → **30px**.
- `packages/provis/lib/src/iso/iso_view.dart:302-311` — `detailFor()` 는 70px 이하에서 detail 0.25 로 떨어뜨린다. 즉 **플레이 중 원격 캐릭터 대부분은 provis 고품질 렌더의 이득을 받지 못한다.**
- `packages/provis/lib/src/iso/iso_view.dart:257-295` — `BakedPart.bake/replay`: "paintSurface 는 파츠당 saveLayer 1회 + 블러 3~6회를 쓴다. 프레임 간에 형상이 바뀌지 않는 것은 반드시 구워서 그 비용을 없앤다."
- 프롭 생성자 전수 — `TreeProp(canopyColor:, barkColor:)` `rock.dart:26-32 RockProp(seed, size, color, mossy, shards, buried)` · `water.dart:29-35 WaterProp(seed, radius, color, ripple, shallow, reeds)` · `terrain.dart:31-39 MoundProp(seed, radius, rise, isoRatio, grassColor, soilColor, walkOver, tufts)` · `building.dart:93-106 BuildingProp(seed, tiles, tileWidth, isoRatio, storeys, wall, roof, wallColor, roofColor, litWindows, ridgeAlongX, chimney)`. **모든 기물이 색을 주입받는다 — 재색칠은 물리적으로 가능하다.**
- `packages/provis/lib/src/flame/iso_scene.dart:84-181` — `IsoSceneComponent` 는 자체 `cameraOffset`·자체 `IsoGrid`·자체 `paintIsoGround(cols, rows)` 를 들고 **씬 전체를 한 번에** 그린다. 1006×1006 월드와 Flame 카메라를 쓰는 이 게임에 그대로 얹을 수 없다.
- `lib/auth/cyborg_portrait.dart:124` · `lib/game/entities/player.dart:1218` · `lib/game/entities/remote_player.dart:435` — 세 곳이 **같은** `CyborgRenderer.drawBody` 를 호출한다. 선택 화면과 게임 내 외형의 일치가 이 공유에서 나온다.
- `lib/game/entities/remote_player.dart:154-158` — `_designFor(String kind)` 가 `'female_cyborg'` 문자열 하나로 프레임을 고른다. 서버가 아는 외형은 이 문자열뿐이다.

## 3. 상세 분석

### 3-1. 좌표계 — 이행 비용이 거의 없다

가장 컸던 걱정이 사실이 아니다. provis 의 `kIso` 는 128×64 이고 게임도 128×64 다. `IsoView.project(wx, wy, wz)`(`iso_view.dart:43-46`)는 `gridToScreen()`(`lib/game/iso.dart:62-67`)과 z 항을 뺀 전부가 **수식까지 동일**하다. 따라서 `paintProp`·`paintSurface`·`BakedPart` 같은 provis 함수에 `const IsoView()` 를 그냥 넘기면 기존 히트박스·이동속도·카메라 줌·AOI 반경에 **아무 파급이 없다.**

어긋나는 것은 고도뿐이다 — provis 는 78.4, 게임은 56. 하지만 게임에서 z 를 쓰는 것은 `gridToScreen` 의 선택 인자뿐이고 provis 함수에 z 를 넘길 일이 없다. `IsoView` 는 셰이딩 파라미터 공급원(`squash` 0.866 · `elevationSin` 0.5 · `shadowRatio` 0.5)으로만 쓰면 되고, 고도는 계속 게임 값을 쓴다. **`kHeightUnit` 을 78.4 로 맞추려 들지 마라** — 얻는 것 없이 점프·투사체·타워 높이가 전부 어긋난다.

### 3-2. 맵 — 여기가 진짜 약점이고, 여기가 공짜다

현재 청크 굽기(`_bakeChunk`, `ground_layer.dart:153`)는 타일 종류별로 Path 를 합쳐 **5번의 단색 fill** 로 끝낸다. 그 위에 격자선·배선·가장자리 발광이 얹힌다. 격자선까지 있어서 provis 가 경고한 "체커 장판"의 교과서적 사례다.

결정적으로 **이 함수의 내용물은 `ui.Picture` 안에 굽혀 96개까지 LRU 캐시된다**(`ground_layer.dart:47`, `GAME-DESIGN.md:232`). 여기서 blur 를 쓰든 그라디언트를 열 겹 쌓든 **매 프레임 비용은 `drawPicture` 한 번으로 동일하다.** 유일한 비용은 굽는 순간이고, 그것도 프레임당 3개로 이미 예산이 걸려 있다(`ground_layer.dart:50`).

이식할 것은 `paintIsoGround` **함수 자체가 아니라 그 안의 세 기법**이다 — 그 함수는 `cols`/`rows` 로 맵 전체의 `field` Path 를 만들므로 1006 타일 월드에는 못 쓴다.

1. **얼룩 두 층**(`iso_stage.dart:227-261`) — 큰 타원 9개 + 작은 타원 14개를 `MaskFilter.blur` 로 번지게 해 타일 경계와 무관한 무늬를 만든다. 청크 경계에서 끊기지 않으려면 시드를 **청크 좌표가 아니라 월드 좌표**에서 뽑고, 청크 bounds 를 넘겨 이웃 청크까지 걸치도록 그린 뒤 clip 해야 한다. 게임 톤에서는 "흙 얼룩"이 아니라 **데이터 플레이트의 명도 편차·연산 부하 얼룩**으로 해석하면 세계관이 유지된다(`floorBase` ↔ `floorAlt` ↔ `floorCircuit` 사이의 미세 편차).
2. **거리 감쇠**(`iso_stage.dart:209-224`) — 세로 그라디언트로 먼 쪽을 환경광 쪽으로 민다. 청크 단위로는 어색하므로, 청크가 아니라 **`GroundLayer.render()` 에 화면 전체를 덮는 한 겹**으로 얹는 편이 맞다. `paintIsoHaze`(`iso_stage.dart:298-313`)가 그 함수이고, 게임에서는 `GamePalette.skyLow`/`horizonGlow` 를 `ambient` 자리에 넣는다.
3. **가장자리 두께**(`iso_stage.dart:157-203`) — 이미 부분적으로 있다. `_drawPlatformRim`(`ground_layer.dart:299`)이 데이터 공백과 맞닿은 변에 발광 선을 두른다. 여기에 **아래로 떨어지는 플레이트 단면**(수직 그라디언트 벽)을 더하면 "잘린 종이"가 "두께를 가진 부유 플레이트"가 된다. 세계관상 흙 지층 대신 **회로 기판의 적층 단면**으로 그리면 정합한다.

기물은 `LevelMap` 의 3층 생성(`GAME-DESIGN.md:242-257`)에 4층을 덧붙이는 형태가 자연스럽다. **구조물 스트리밍이 이미 청크 단위로 `BlockComponent` 를 마운트/회수**하고 있으므로(`GAME-DESIGN.md:233`), 같은 주기에 `PropInstance` 를 실어 나르면 새 인프라가 필요 없다. `paintProp`(`prop.dart:85-106`)은 `PropInstance` 하나를 캔버스에 그리는 순수 함수라 Flame 컴포넌트 안에서 그대로 호출 가능하다.

### 3-3. 기물의 세계관 정합 — 형상 중립적인 것만 고른다

"provis 기물을 사이버 톤으로 재색칠할 것인가"에 대한 답은 **부분 긍정**이다. 모든 프롭이 색 인자를 받으므로 재색칠은 되지만, **색으로 지울 수 없는 것은 형상**이다. 초가지붕과 활엽수 캐노피는 청록으로 칠해도 초가지붕과 나무다.

형상이 이미 중립적이거나 사이버 해석이 자연스러운 것만 채택한다.

| 프롭 | 사이버 해석 | 근거 |
|---|---|---|
| `RockProp(color:, shards:, buried:)` | 지면에서 솟은 **데이터 결정체** — `shards` 가 파편을 붙인다 | `rock.dart:26-32` |
| `PebbleField(radius, count, color)` | 파괴된 노드의 **잔해 파편** | `rock.dart:332-335` |
| `MoundProp(rise:, grassColor:, soilColor:)` | **융기한 데이터 지층** — 1 km 평면에 높이를 준다 | `terrain.dart:31-39` |
| `WaterProp(color:, ripple:, shallow:, reeds: false)` | **액체화된 데이터 풀**. `reeds: false` 로 갈대를 끈다 | `water.dart:29-35` |
| `GroundPatch(color:, blades: 0)` | `blades: 0` 이면 풀 없는 **순수 지면 얼룩** | `ground.dart:31-35` |
| `PathPatch(tileWidth:, ruts:)` | 도관 대로 위의 **마모 흔적** | `ground.dart:194-200` |

배제할 것 — `TreeProp`·`StumpProp`·`LogProp`·`FenceProp`·`GrassTuft`·`FlowerBed`. 색을 어떻게 칠해도 "숲이 있는 사이보그 게임"이 된다. `BuildingProp` 은 `WallStyle`/`RoofStyle` 목록을 확인하기 전에는 판단할 수 없다(§6).

이 선택은 세계관을 **버리지도 확장하지도 않는다** — `GAME-DESIGN.md:52-55` 의 "빛으로 가득 찬 사이버 스페이스"를 그대로 두고, 그 안에 지금 없는 **높이와 불규칙성**만 채운다. 세계관을 확장해 "폐허가 된 자연 구역"을 만드는 길도 있으나, 그것은 `GAME-DESIGN.md` 개정을 수반하는 기획 결정이라 사람이 자는 동안 오케스트레이터가 단독으로 내릴 판단이 아니다.

### 3-4. PC — 전면 대체는 손해다

`BuiltArtist`/`CharacterBuild`/`HumanoidRenderer` 로 옮기면 얻는 것은 **골격이 실제로 움직이는 것**(다리 교차·방향별 어깨/얼굴 변화, `iso_stage.dart:376-384`)과 19종 `Finish` 셰이딩이다. 잃는 것을 세면 이렇다.

- **사이보그 정체성.** `CyborgDesign` 은 임플란트·바이저·동력팩·헤어스타일·프레임별 실루엣을 수치로 들고 있다(`cyborg_design.dart:26-58`). `HumanoidSpec` 에 대응 필드가 없다. `Palette` 11색(`character_build.dart:190-214`: skin/hair/cloth/accent/metal/leather/eye/glow…)으로 청록 발광은 흉내 내지만, `hornedHelm` 을 쓴 `paladin` 은 사이보그가 아니다.
- **세 화면의 일치.** 선택 화면(Flutter 위젯) · 인게임 자기 몸 · 원격 플레이어가 한 함수를 공유한다. 하나만 바꾸면 즉시 어긋난다.
- **스냅샷 테스트 전량.** `cyborg_render_snapshot_test.dart` 는 16방향 회전 시트를 뽑고 `hasConcaveWaist`·`shoulderWidth` 를 단언한다. `CyborgDesign` 이 사라지면 이 파일은 통째로 폐기된다.
- **프레임 예산.** 260~418 µs/인 × 최대 50명 = 13~21 ms. **한 프레임을 통째로 먹는다.** `detailFor` 로 낮춰도, 59px 짜리 캐릭터에 골격을 매 프레임 푸는 것은 지금의 그라디언트 fill(`cyborg_renderer.dart:49-81`, saveLayer 0회)보다 확실히 비싸다.
- **크기 부적합.** provis 액터는 타일 폭의 1.2~1.6배(154~205px)를 전제로 설계됐다(`iso_stage.dart:47-49`). 현재 캐릭터는 108px = 타일 폭의 0.84배다. provis 품질이 나오는 크기가 아니다.

대신 **셰이딩만 빌리는** 길이 있다. `drawBody` 시그니처(`cyborg_renderer.dart:91-100`)를 **그대로 유지**한 채, 내부의 `_cylinderShade`/`_plateShade`(`cyborg_renderer.dart:49,68`)를 `paintSurface(canvas, path, Surface(color, Finish.metal, glow:…), lightRig)` 로 바꾸는 것이다. 시그니처가 같으므로 세 호출부도 스냅샷 테스트도 그대로 산다.

문제는 비용이다 — `paintSurface` 는 파츠당 saveLayer 1 + blur 3~6 (`iso_view.dart:260-262`). 몸통·머리·팔2·다리2만 세도 6 saveLayer 다. 그래서 **`BakedPart` + 이미 있는 `quantizeYaw()`**(`lib/game/iso.dart:132`)를 함께 써야 한다. 32방향 × 디자인 2종 = 64장을 굽고 재생하면 회전 비용이 상각된다. 다만 보행 스윙(`swing`·`armSwing`)이 매 프레임 바뀌므로 **몸통·머리·동력팩만 굽고 팔다리는 기존 그라디언트로 남기는** 하이브리드가 현실적이다. 이건 명백히 4순위 작업이며, 1·2순위를 끝낸 뒤 남는 시간에 손대는 것이 맞다.

### 3-5. 쓰면 안 되는 provis API

`IsoSceneComponent`·`IsoController`·`IsoGrid`·`MoveMarker`·`screenToTile` 은 **모두 배제한다.** `IsoSceneComponent` 는 자체 카메라 오프셋과 자체 지면 렌더를 들고 있어 Flame 카메라·`GroundLayer` 와 이중화되고, `IsoController` 는 클라이언트 A* 경로탐색이라 "클라이언트를 신뢰하지 않는다"는 서버 설계 원칙과 정면으로 충돌한다. 빌릴 것은 **순수 함수와 값 타입뿐**이다: `paintSurface`·`Surface`·`Finish`·`LightRig`·`BakedPart`·`paintProp`·`PropInstance`·`Prop` 구현체들·`paintIsoHaze`·`propShadow`·`Rng`·`Noise`.

## 4. 리스크 · 함정

- **청크 경계에서 얼룩이 끊긴다.** `_bakeChunk` 는 32타일 사각형 안만 그린다. 얼룩 시드를 청크 인덱스로 뽑으면 32타일마다 무늬가 반복되고 경계가 눈에 띈다. **월드 좌표 기반 `Rng` 로 시드를 뽑고, 청크 bounds 를 넉넉히 inflate 해 이웃까지 걸치게 그린 뒤 clip** 해야 한다. `_bakeChunk` 는 이미 `bounds.inflate(4)` 를 쓰지만(`ground_layer.dart:156`) 얼룩에는 턱없이 좁다.
- **`MaskFilter.blur` 를 굽는 비용.** 굽기가 프레임당 3청크로 제한돼 있어도(`ground_layer.dart:50`), 청크 하나에 blur 타원 23개(`iso_stage.dart:231,246`)를 넣으면 굽는 순간의 비용이 지금의 몇 배가 된다. **빠르게 이동할 때 프레임 스파이크가 돌아올 수 있다** — `_chunkBudgetPerFrame` 을 2 또는 1 로 낮추는 조정이 함께 필요할 수 있고, 그러면 이번엔 청크가 늦게 채워져 빈 땅이 보인다. 이 트레이드오프를 실제 프로파일 없이 단정하지 마라.
- **`ui.Picture` 메모리.** blur 는 Picture 크기를 늘리지 않지만 래스터화 캐시는 늘린다. 96청크 × 더 복잡한 Picture 가 모바일에서 어떻게 되는지 측정되지 않았다.
- **`paintProp` 의 `grounded` 스케일이 게임과 다르다.** 눕는 기물은 `iso.shadowRatio`(=0.5)로 눌리고 서는 기물은 `iso.squash`(=0.866)로 눌린다(`prop.dart:98-103`). 게임의 `BlockComponent` 는 이런 압축을 하지 않고 직접 마름모를 그린다. **같은 화면에서 두 규약이 섞이면 접지선이 어긋나 기물이 떠 보인다.**
- **깊이 정렬 이중화.** provis 는 `depth = tile.dx + tile.dy` 로 자체 정렬하고(`prop.dart:78`), 게임은 Flame `priority = (x+y+bias)*100` 으로 정렬한다(`lib/game/iso.dart:84-86`). 프롭을 개별 `PositionComponent` 로 감싸 게임 규약에 편입시켜야지, `paintProps` 로 묶어 그리면 **그 묶음 전체가 하나의 priority 를 갖게 되어 캐릭터가 기물을 관통하거나 덮인다.**
- **`drawBody` 시그니처를 바꾸는 순간 세 파일이 동시에 깨진다** — `player.dart:1218`·`remote_player.dart:435`·`cyborg_portrait.dart:124`. 특히 마지막은 **Flutter 위젯 층**이라 Flame 쪽만 고치면 선택 화면과 게임 내 외형이 갈라진다.
- **`_maxRemotePlayers = 50` 은 상한이지 평균이 아니다.** 안전지대(50×50)에 사람이 몰리면 실제로 50명이 한 화면에 온다(`action_rpg_game.dart:245-248`). PC 렌더 비용을 올리는 모든 변경은 **이 최악의 경우로 검산해야** 한다.
- **`GAME-DESIGN.md:172-178` 은 "캐릭터는 빌보드, 방향은 두 불리언"이라고 적혀 있지만 실제 코드는 연속 yaw 다**(`cyborg_renderer.dart:85-87`, `lib/game/iso.dart:122`). 문서가 코드보다 낡았다. 문서를 근거로 삼은 판단은 틀린다.
- **`packages/provis` 는 submodule 이므로 절대 수정하지 않는다.** 필요한 기능이 없으면 게임 쪽에서 우회한다.

## 5. 권고안

| 순위 | 권고 | 범위 | 근거 | 리스크 |
|---|---|---|---|---|
| 1 | **지면 얼룩 두 층을 청크 굽기에 이식.** `GroundLayer._bakeChunk` 안, `_drawTileGrid` **직전**에 provis `Rng`/`Noise` 로 월드 좌표 기반 blur 타원(큰 9 + 작은 14)을 `GamePalette.floorAlt`↔`floorCircuit` 사이 미세 편차로 깐다. 시드는 **청크 인덱스가 아니라 월드 타일 좌표**에서. 시각 이득: 체커 장판 → 살아 있는 데이터 표면. | 클라이언트 렌더 (`lib/game/level/ground_layer.dart:153-208`) | `iso_stage.dart:226-261` 기법 · `ground_layer.dart:193-197` 단색 fill 확인 | 굽기 비용 증가 → `_chunkBudgetPerFrame`(`:50`) 재조정 필요할 수 있음. 청크 경계 이음새. 스냅샷 테스트 없음(안전) |
| 2 | **플레이트 단면 + 화면 haze.** `_drawPlatformRim`(`:299`)에 아래로 떨어지는 수직 그라디언트 벽(회로 적층 단면)을 더하고, `GroundLayer.render()` 끝에 `paintIsoHaze` 방식 한 겹(`skyLow`→투명)을 얹는다. 시각 이득: 부유 플레이트에 **두께**가 생기고 먼 곳에 깊이가 생긴다. | 클라이언트 렌더 (`ground_layer.dart:299-378`) | `iso_stage.dart:157-203, 298-313` | haze 는 매 프레임 전면 rect 1회 — 값싸지만 HUD 아래에 들어가야 한다(`priority` 확인 필요) |
| 3 | **중립 형상 기물 4종 도입.** `RockProp`·`PebbleField`·`MoundProp`·`WaterProp` 을 `GamePalette` 색으로 주입해 데이터 결정체·파편·지층·데이터 풀로 재해석. 배치는 `LevelMap.generate()` 3층 뒤에 4층으로 추가하고, 마운트는 기존 구조물 스트리밍(0.25초·여유 16타일) 주기에 얹는다. **각 기물을 개별 `PositionComponent` 로 감싸 `depthPriority()` 를 부여**한다. | 클라이언트 렌더 + 맵 생성 (`lib/game/level/level_map.dart`, 새 컴포넌트) | `rock.dart:26-32` · `terrain.dart:31-39` · `water.dart:29-35` 가 전부 색 인자 노출 · `GAME-DESIGN.md:242-257` 3층 구조 | `paintProp` 의 `grounded` 스케일 규약과 게임 `BlockComponent` 규약 충돌(§4). 통행 판정을 `LevelMap` 과 반드시 동기화 — 서버는 이 기물을 모르므로 **통행 불가 기물은 놓지 말고 전부 `walkable` 로** 두는 것이 안전 |
| 4 | **PC 셰이딩 승급 (셰이딩만, 골격은 그대로).** `CyborgRenderer.drawBody` **시그니처 불변**. 내부 `_cylinderShade`/`_plateShade`(`:49,68`)를 `paintSurface(… Surface(c, Finish.metal, glow:…) …)` 로 교체하되, **몸통·머리·동력팩만** 적용하고 팔다리는 기존 그라디언트 유지. `quantizeYaw(yaw, 32)`(`lib/game/iso.dart:132`)로 이산화해 `BakedPart` 캐시(디자인 2종 × 32방향 = 64장). 화면 내 캐릭터가 임계치를 넘으면 캐시 미스분은 기존 경로로 폴백. | 클라이언트 렌더 (`lib/game/entities/cyborg_renderer.dart`) | `shading.dart:274-286` · `iso_view.dart:257-295` `BakedPart` · README:257-264 성능 | **최대 위험 항목.** 50명 동시 화면에서 saveLayer 폭증 가능. 스냅샷 3종(`cyborg_render_snapshot_test.dart`·`monster_render_path_test.dart`)이 **의도적으로** 달라진다 — PNG 를 다시 뽑아 눈으로 검수해야 한다. 초상(`cyborg_portrait.dart:124`)은 시그니처 유지 덕에 자동으로 따라온다 |
| 5 | **캐릭터 키 108 → 150 전후 검토.** provis 권장은 타일 폭의 1.2~1.6배(154~205px). 현재 0.84배라 격자에 묻힌다. `CyborgDesign.totalHeight` 만 올리면 렌더는 따라오지만 `_tapHeight = 104`(`remote_player.dart:58`)·이름표 위치·`_zoomForSize` 기준(760px, `action_rpg_game.dart:377`)이 함께 움직인다. | 클라이언트 (`cyborg_design.dart`, `remote_player.dart`, `action_rpg_game.dart`) | `iso_stage.dart:47-49` · `cyborg_render_snapshot_test.dart:36` | 히트박스(`bodyRadius: 0.28`)와 서버 판정은 무관하나, **군중 속 겹침이 심해진다** — MMORPG 에서 식별성이 오히려 나빠질 수 있다. 1~4 를 끝낸 뒤 스크린샷으로 판단할 것 |
| — | **하지 않는다: `CharacterBuild`/`HumanoidRenderer` 전면 이행, `IsoSceneComponent`/`IsoController`/`IsoGrid` 채택, `TreeProp`·`FenceProp`·`FlowerBed` 등 자연물 도입, `kHeightUnit` 을 78.4 로 변경** | — | `spec.dart:8,21,23`(사이보그 어휘 부재) · `iso_scene.dart:84-181`(카메라·격자 이중화) · 서버 권위 원칙 | 채택 시 세계관·테스트·프레임 예산이 동시에 무너진다 |

**실행 순서 요약** — 1 → 2 를 먼저 끝내고 `flutter analyze` + `flutter test` 로 회귀가 없음을 확인한다(이 둘은 렌더 스냅샷을 건드리지 않는다). 그 다음 3 을 넣고 DTD 스크린샷으로 기물이 접지선에 맞는지 본다. 4 는 별도 커밋으로 분리하고, `CYBORG_SNAPSHOT_DIR=... flutter test test/cyborg_render_snapshot_test.dart` 로 PNG 를 뽑아 **59px·30px 축소 시트에서 실루엣이 살아 있는지** 확인한 뒤에만 채택한다. 5 는 사람의 판단을 받는 것이 낫다.

## 6. 불확실 · 미확인

- **`TreeKind` 7종의 실제 형상** (`tree.dart:14`) — enum 이름만 확인했고 각 종이 어떻게 그려지는지 보지 않았다. 그중 침엽수·고사목 계열이 데이터 공간의 안테나·타워로 재해석될 여지가 있는지는 미확인이다.
- **`WallStyle`(`building.dart:14`)·`RoofStyle`(`:32`)·`RoofSkin`(`:50`) 의 값 목록** — 이것을 확인해야 `BuildingProp` 을 데이터 타워로 재활용할 수 있는지 판단된다. `stone`/`flat` 계열이 있다면 3순위에 포함할 만하다. **현 보고서는 이를 배제도 채택도 하지 않았다.**
- **현재 `CyborgRenderer.drawBody` 의 실측 프레임 비용** — 측정된 적이 없다. provis 의 260~418 µs 와 비교할 기준선이 없으므로, 4순위의 "확실히 비싸진다"는 판단은 `paintSurface` 가 saveLayer+blur 를 쓰고 현재 코드가 쓰지 않는다는 **구조적 근거**에 의존한다. 실제 배수는 `[추측]` 이다.
- **`_bakeChunk` 에 blur 23개를 추가했을 때의 실제 굽기 시간** — 미측정. `_chunkBudgetPerFrame` 조정이 필요한지는 프로파일 후에만 안다.
- **`enemy.dart`(1,243줄)의 AI 로봇 4종 골격이 provis 로 갈 수 있는지** — 열어 보지 않았다. `Finish.chitin`/`scale`/`metal` 이 있어 가능성은 있으나 근거가 없다.
- **`packages/provis/example/` 가 이 Flutter 버전에서 실제로 빌드·실행되는지** — 확인하지 않았다. 참조 화면을 눈으로 보고 판단하려면 필요하다.
- **`monster_render_path_test.dart`·`mute_button_snapshot_test.dart` 의 구체적 단언** — 열지 않았다. 1~3순위는 이들을 건드리지 않을 것으로 보이나(`[추측]`), 4순위 착수 전에 반드시 읽어야 한다.
- **사람의 판단이 필요한 지점** — 세계관을 확장해 "데이터 공간에 침식한 이질적 자연 구역"을 만들 것인가. 그것을 허용하면 `TreeProp` 계열까지 열려 시각적 풍요가 크게 늘지만, `GAME-DESIGN.md` §2.2 의 개정을 수반한다. **오케스트레이터가 단독으로 내릴 결정이 아니라고 판단해 이번 권고에서는 배제했다.**
