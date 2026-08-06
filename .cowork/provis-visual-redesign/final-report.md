# final-report — provis-visual-redesign

> 요청: provis 패키지를 submodule 로 붙이고(완료), 그것으로 cyborg 게임의 **PC 디자인과 게임 맵
> 디자인**을 멋지게 만들어라. 사람은 자러 갔고 끝까지 완료해야 한다.
>
> 분석: claude · codex · grok(2-pass) · kimi 4인 모두 성공.
> ⚠️ claude·kimi 는 1차에서 900초 제한 초과로 실패해 `COWORK_TIMEOUT=2400` 으로 재실행했다.
> 종합: 오케스트레이터가 근거 `파일:줄` 을 직접 열어 교차검증.
> 2차: 네 AI 의 리뷰를 받아 근거를 재확인하고 정정했다(§3·§4·§6·§7).

---

## 1. 결론

**PC 렌더러는 갈아엎지 말고 셰이딩만 빌린다. 진짜 약점은 지면이고, 거기가 가장 싸다.**

세 가지가 이 순서를 강제한다.

1. **지면은 실제로 비어 있다.** `GroundLayer._bakeChunk` 는 타일 종류별 단색 fill **5번** + 격자선 +
   도관 + 테두리가 전부다(`lib/game/level/ground_layer.dart:192-201` 직접 확인). provis 가 "이렇게
   하면 땅이 아니라 **장판**이 된다"고 명시적으로 경고한 바로 그 구조다
   (`packages/provis/lib/src/iso/iso_stage.dart:110-122`).
2. **그 지면은 `ui.Picture` 안에 기록돼 96개까지 캐시된다**(`ground_layer.dart:47,153-208`).
   ⚠️ 정정: `ui.Picture` 는 래스터 이미지가 아니라 **드로잉 명령 목록**이고, `render()` 는 매 프레임
   `canvas.drawPicture(chunk.picture)` 를 호출한다(`ground_layer.dart:355-360`). 따라서 상각되는 것은
   **경로 생성·명령 기록 비용**(청크가 새로 보일 때만 발생)이고, **래스터 비용은 매 프레임 다시 든다.**
   그래도 지면이 가장 싼 자리인 것은 변하지 않는다 — 늘어나는 것은 화면 안 소수 청크의 픽셀 채우기이지
   액터 수 × 파츠 수가 아니고, 이 경로를 검증하는 렌더 테스트가 없다. 다만 "공짜"는 아니므로
   **bake 시간과 raster 스레드 시간을 단계 2 직후 계측한다**(§7 검증).
3. **PC 를 provis 캐릭터 체계로 옮기면 잃는 것이 얻는 것보다 크다.** `CharacterBuild.sex` 는
   **체형에 전혀 반영되지 않고**(`toSpec()` 이 sex 를 넘기지 않으며 `HumanoidSpec` 에 sex 개념이 없다),
   폭 수치를 직접 넘길 통로도 없다. VULCAN(어깨 34 > 골반 19)/WRAITH(골반 21 > 가슴 18 인 모래시계)의
   실루엣 계약을 **`CharacterBuild` 어휘로는 동등 재현할 수 없다**(§4 쟁점1).

따라서 실행 순서는 **① 공용 브리지 → ② 지면 재질 → ③ grounded 기물 → ④ 수직 기물 → ⑤ PC 셰이딩**이다.
아이소 규격은 **바꾸지 않는다** — provis `IsoView` 기본값이 이미 128×64 로 게임과 같다.

**이번 차수의 완료 정의**: 맵은 재질·기물·깊이까지 손대고, PC 는 **재질 승급(림 → 몸통 재질)까지**만
한다. 골격·`CharacterBuild`·임플란트 어휘 확장은 이번 범위 밖이며 §8 에 남긴다. 요청이 PC 와 맵을
나란히 요구했으므로, PC 축이 통째로 비지 않도록 순위 5 를 저위험(5a)·고위험(5b)으로 쪼갠다.

---

## 2. 네 AI 의견 대조

| 쟁점 | claude | codex | grok | kimi | 판정 |
|---|---|---|---|---|---|
| `IsoSceneComponent` 전면 채택 | 배제 | 배제 | 배제 | 배제 | **합의 — 배제** |
| 타일 규격 | 128×64 유지 | 128×64 유지 | 128×64 유지 | 128×64 유지 | **합의 — 유지** |
| 청크 bake 활용 | 핵심 | 5순위 | 1순위 | 2순위 | **합의 — 채택** |
| 세계관 | 유지 | 유지+재색 | 유지+재색 | 확장(오염구역) | **유지+재색** |
| PC 전면 이행 | 반대 | 반대 | 고위험 후순위 | **찬성** | **기각**(§4 쟁점1) |
| `TreeProp` | 전량 배제 | 채택 | 채택(dead/pine) | 채택 | **부분 채택**(§4 쟁점2) |
| 1순위 | 지면 | PC 셰이딩 | grounded bake | LightRig→지면 | **지면**(§4 쟁점3) |
| 서버 `kind` | 2종 유지 | 2종 유지 | 2종 유지 | 2종 유지(해시 시드) | **합의 — 유지** |

---

## 3. 합의 — 검증 통과

| 주장 | 검증 |
|---|---|
| provis `IsoView` 기본값이 128×64 로 게임과 동일 | ✅ `packages/provis/lib/src/iso/iso_view.dart:16` vs `lib/game/iso.dart:6,9`. `const IsoView kIso = IsoView()`(`iso_view.dart:62`)를 그대로 쓸 수 있다. README 156×78·예제 150×75 는 그 화면의 선택일 뿐 |
| 고도 스케일만 어긋난다 (provis ≈78.4 vs 게임 56) | ✅ `heightScale => tileWidth*squash/√2` = 128×0.866/1.414 ≈ 78.4(`iso_view.dart:37`), `kHeightUnit = 56`(`lib/game/iso.dart:15`). **평면 투영식은 동일**하므로 z 를 넘기지 않으면 무관 |
| `IsoSceneComponent` 는 1 km 월드에 부적합 | ✅ 자체 `cameraOffset`·자체 `IsoGrid`·자체 `paintIsoGround(cols,rows)` 를 들고 씬 전체를 매 프레임 순회(`iso_scene.dart:84-181`). Flame 카메라·`GroundLayer`·`LevelMap` 과 삼중 이중화 |
| 모든 기물이 색을 주입받는다 | ✅ `TreeProp(canopyColor,barkColor)` · `RockProp(color)` · `WaterProp(color,reeds)` · `MoundProp(grassColor,soilColor)` · `GroundPatch(color,blades)` · `PebbleField(color)` 전부 확인 |
| `WaterProp` 은 `reeds: true` 가 기본 | ✅ `water.dart:35` — 명시적으로 꺼야 갈대가 안 나온다. 통행 여부는 `walkable => shallow`(`water.dart:82`), 눕는 기물이라 `grounded => true`(`:76`) |
| `BuildingProp` 은 `tileWidth: 156` 이 기본 | ✅ `building.dart:96` — 게임에 넣으려면 128 명시 필수 |
| **`PathPatch` 도 `tileWidth: 156` 이 기본** | ✅ `packages/provis/lib/src/props/ground.dart:195`. 156 함정은 `BuildingProp` 전용이 아니다 — 길을 쓰려면 `tileWidth: 128`·`isoRatio: 0.5` 를 명시해야 한다(codex 지적, 확인) |
| `LightRig` 프리셋은 어두운 씬용 | ✅ `daylight.ambient = 0xFF31415F`(`shading.dart:131`) 등 모두 어두운 남색. 밝은 데이터 공간에는 커스텀 리그가 필요 |
| 서버가 아는 외형은 2종뿐 | ✅ `CHARACTER_KINDS = ["male_cyborg","female_cyborg"]`(`spacetimedb/src/character.rs:23`) |
| **네** 화면이 `drawBody` 를 공유 | ✅ `player.dart:1218` · `remote_player.dart:435` · `cyborg_portrait.dart:124` · **`lib/game/ui/cyborg_preview.dart:53`**(grok 지적, 확인). 시그니처 불변 요구의 근거가 하나 더 늘었다 |
| 원격 다수에서 provis 풀 렌더는 예산을 위협한다 | ⚠️ **수치 정정.** README 실측 260~418 µs/인(`README.md:259-264`), `_maxRemotePlayers = 50`(`action_rpg_game.dart:248`) → 50인 환산 **13~21 ms**. 즉 16.6 ms 를 넘는 것은 418 µs 쪽뿐이고 260 µs 쪽은 예산의 78% 다. 게다가 이 수치는 `PictureRecorder` **기록까지만** 재고 래스터화·GPU 합성이 빠져 있으므로(`example/test/facing_sweep_test.dart:48-64`) 총 프레임 비용의 **하한**이다. 하한만으로 예산의 78~126% 를 먹는다는 뜻이라 위험 판정은 유지되지만, "초과 확정"이 아니라 "계측 전까지 고위험"이다 |

---

## 4. 이견 — 자료로 판정

### 쟁점 1 — PC 를 `CharacterBuild`/`HumanoidRenderer` 로 이행할 것인가

- **kimi(찬성, 3순위)**: `kind` 문자열을 해시해 시드로 쓰면 서버 무수정으로 원격마다 다른 몸이
  나온다. `assault→knight` · `infiltrator→assassin` 강제 매핑을 함께 제안했다. 단 kimi 자신이 §6 에서
  **`HumanoidRenderer` 의 성별/`Sex` 처리는 미독**이라고 밝혔다.
- **claude·codex·grok(반대 또는 최후순위)**: 사이보그 어휘 부재, 성별 미반영, 프레임 예산.

**판정: 기각 (자료가 소수 3인을 지지한다).**

kimi 가 미독이라 적은 부분을 직접 열었다.

```
packages/provis/lib/src/actor/character_build.dart:99-115  toSpec()
  → HumanoidSpec.generate(s, forceArchetype: archetype) 를 부르고
    copyWith(palette, headGear, weapon, hasCape, hasPauldrons, hasShield,
             armorHeaviness, muscle, hairLength, glowRunes, heightScale)
    ← sex 가 없다. 폭·비율 수치도 없다.
packages/provis/lib/src/actor/spec.dart  → 'sex'/'Sex' grep 결과 0건.
packages/provis/lib/src/art/creature.dart:18-24 → enum Sex 는 label('Male')·symbol('♂') 전용.
```

**정정(codex·grok 지적 반영): "원리적으로 불가능"은 과장이다.** `archetype`·`muscle`·
`armorHeaviness`·`hasPauldrons`·`heightScale` 로 **어느 정도의 실루엣 차이는 만들 수 있다**
(`character_build.dart:38-93`, 원형별 대역은 `spec.dart:119-146`). 정확한 기각 근거는 **동등 재현
불가**다.

```
packages/provis/lib/src/actor/spec.dart:171-174 (generate)
  shoulderWidth: h * 0.232 * broad
  waistWidth   : h * 0.146 * (0.85 + broad * 0.18)
  hipWidth     : h * 0.166 * (0.9  + broad * 0.12)
  → hipWidth 계수(0.166)가 shoulderWidth 계수(0.232)보다 항상 작다.
```

`CyborgDesign.infiltrator` 는 `hipWidth 21 > chestWidth 18`(`cyborg_design.dart:230,234`)인
**모래시계**이고, 주석이 그 이유를 못박아 두었다 — *"골반이 가슴보다 넓어야 실제로 모래시계가 된다.
같으면 '잘록한 원통'에 그쳐 축소했을 때 남성형과 구분되지 않는다"*(`:232-233`). provis 의 생성식은
이 관계를 만들지 못하고, `toSpec()` 은 폭을 넘길 인자조차 없다. `assault` 는 어깨 34·목 5.5,
`infiltrator` 는 어깨 25·목 9.5(`:183,190,229,238`) — 이 수치 계약이 통째로 사라진다.

추가로 provis 캐릭터 어휘는 판타지 전용이다 — `Archetype {knight…paladin}` ·
`WeaponKind {sword…bow}` · `HeadGear {…hornedHelm}`(`spec.dart:8,21,23`). 임플란트 7종·바이저·
동력팩(`cyborg_design.dart:283-304`)을 담을 자리가 없다.

**kimi 의 "kind 해시 → 시드로 다양성" 아이디어도 지금 채택하지 않는다.** 서버가 아는 `kind` 는 2종뿐이라
해시 시드도 **두 값만** 나온다 — 개인별 다양성은 생기지 않는다. 그리고 시드를 명시하지 않으면 초상과
인게임의 몸이 갈린다: `BuiltArtist` 는 `_build.seed ?? id.hashCode & 0x7FFFFFF`
(`built_artist.dart:122`), `riggedFromArtist` 는 `Rng.fromString(a.id).intRange(...)`
(`src/iso/artist_rig.dart:35`) — **두 fallback 이 서로 다르다**(kimi 지적, 확인). 이 아이디어를 언젠가
살리더라도 `seed` 강제가 전제 조건이다.

**남은 문제는 지우지 않는다.** 원격 플레이어의 몸은 지금도 내 몸과 같은 2종뿐이고,
`GamePalette.remotePlayer` 호박색은 **UI 오버레이 층에서만** 식별을 담당한다 —
이름표(`remote_player.dart:507`)·HP바(`:542`)·미니맵 점(`hud.dart:505-513`)에만 쓰이고 몸체에는
쓰이지 않는다(claude 지적, 확인). 즉 실루엣 층의 군중 식별성은 여전히 약점이며 §8 로 남긴다.

### 쟁점 2 — `TreeProp` 을 쓸 것인가

- **claude(배제)**: "색을 어떻게 칠해도 초가지붕은 초가지붕이고 활엽수 캐노피는 나무다."
- **codex·grok·kimi(채택)**: 광섬유 군락 / 데이터 수관 / 안테나 고사목으로 재해석.

**판정: 부분 채택.** claude 자신이 §6 에서 *"`TreeKind` 7종의 실제 형상은 보지 않았다"* 고 적었다.
열어 보니 종마다 실루엣이 근본적으로 다르다(`packages/provis/lib/src/props/tree.dart:13-36`).

| 종 | 주석 원문 | 판정 |
|---|---|---|
| `dead` | "잎이 없고 **가지만 남았다**. 실루엣 자체가 이야기를 한다"(`tree.dart:25-26`) | **채택** — 잎이 없으니 "나무 티"가 나는 캐노피가 아예 없다. 데이터 공간의 안테나·붕괴한 신호탑으로 읽힌다 |
| `conifer` | "처진 바늘잎 층이 위로 좁아진다. **수직선을 만들어 화면을 잡아 준다**"(`:18`) | **조건부 채택** — 청록 단색 + 낮은 밀도로 데이터 스파이어 |
| `broadleaf`·`blossom`·`willow`·`bush` | 둥근 수관 / 꽃 / 늘어진 잎 | **배제** — claude 가 옳다. 색을 바꿔도 숲이다 |

즉 claude 의 논지("형상은 색으로 지울 수 없다")를 채택하되, 그 기준을 적용하면 `dead` 는
**통과한다**. 다수의 결론과 소수의 논리를 자료가 각각 절반씩 지지한 경우다.

**단, 신규 나무를 흩뿌리기 전에 기존 `WorldTree` 부터 손댄다**(codex·grok 지적, 확인). 월드 중앙의
`WorldTree` 는 이미 *"무대가 전산망 내부이므로 자연 그대로의 나무가 아니라 **데이터가 자라 굳은
나무**로 그린다"* 는 세계관 선례이고(`lib/game/level/world_tree.dart:14-16`), `IsoEntity` 상속이라
깊이 정렬이 이미 맞으며(`:21-23`), 개체 수가 1 이라 프레임 위험이 없다. 화풍 정합을 검증할 **가장
싼 A/B 대상**이다.

`BuildingProp` 은 `WallStyle.stone` · `RoofStyle.flat` 이 실재하지만(`building.dart:14-40`),
텍스처 단위가 돌·벽돌이라 데이터 센터로 읽힐지 불확실하다 → **이번 범위에서 제외**(§7 "하지 않는다").

### 쟁점 3 — 무엇을 1순위로 할 것인가

- **codex**: PC 셰이딩 + 캐시가 1순위.
- **claude·grok·kimi**: 지면이 먼저.

**판정: 지면 먼저.** 근거를 직접 검증했다.

`_bakeChunk`(`ground_layer.dart:153-208`)를 열어 보면 실제 그리기는 이것이 전부다.

```dart
canvas.drawPath(plateEven, fill..color = GamePalette.floorBase);   // 단색
canvas.drawPath(plateOdd,  fill..color = GamePalette.floorAlt);    // 단색
canvas.drawPath(conduit,   fill..color = GamePalette.floorCircuit);// 단색
canvas.drawPath(stream,    fill..color = GamePalette.floorStream); // 단색
canvas.drawPath(hazard,    fill..color = GamePalette.floorHazard); // 단색
_drawTileGrid(...); _drawConduitTraces(...); _drawPlatformRim(...);
```

체커 단색 + 격자선 — provis 주석이 *"격자는 개발 중 좌표를 확인하는 도구이지 땅이 아니다"* 라고
지목한 바로 그것이다(`iso_stage.dart:113-114`).

**PC 셰이딩이 후순위인 이유도 정정한다.** 원본은 `paintSurface` 가 "파츠당 saveLayer 1 + blur 3~6"
이라고 적었는데, 이는 `iso_view.dart:259-260` **주석의 서술**이고 구현과 다르다 — `shading.dart` 전체에
`saveLayer` 는 **0건**이며 `paintSurface` 는 `c.save()` + `c.clipPath(path)` 를 쓴다
(`shading.dart:291-292`). `Finish.metal` 기본 경로는 그라디언트 `drawRect` 2회 + 선택적 스크래치이고
blur 가 없다(`shading.dart:380-430`). blur 는 `s.glow > 0` 일 때의 `glowPath`(`:355-357`)와
`rimBand`(`:1004-1005,1017`) 등 **선택 경로**에 생긴다.

그래도 PC 를 뒤에 두는 근거는 남는다.
1. 공유 경로가 **4곳**이라(§3) 회귀 표면이 가장 넓다.
2. 50인 환산이 하한만으로 예산의 78~126% 다(§3 마지막 행).
3. 지면과 달리 파츠 수 × 액터 수로 곱해진다.
→ **위험이 낮고 이득이 큰 것부터** 한다. 다만 "saveLayer 폭증"은 근거로 쓰지 않으며, 실제 비용 배수는
계측 전까지 `[추측]` 이다.

---

## 5. 고유 통찰 — 검증된 것만

- **claude** — "지면이 진짜 약점이고 청크 bake 안이라 값이 싸다." 다른 셋도 청크 bake 를 언급했고
  grok 1순위·kimi 2순위도 같은 축이지만, *현재 지면이 단색 fill 5번뿐이라는 사실*과 provis 의 "장판"
  경고를 **가장 선명하게 연결**한 것은 claude 다. ✅ 검증됨(단 "프레임 비용 0"은 §1 에서 정정).
- **codex** — "`CharacterBuild.sex` 가 체형에 반영되지 않는다." 쟁점1 을 뒤집은 결정적 사실.
  ✅ 검증됨(§4).
- **codex** — "`paintProp` 에 월드 타일을 넘기면 **이중 투영**된다." ✅ 검증됨.
  `paintProp` 은 첫 줄이 `final anchor = iso.project(it.tile.dx, it.tile.dy)` 이고 곧바로
  `c.translate(anchor)` 한다(`packages/provis/lib/src/props/prop.dart:93-97`). 게임의 `IsoEntity` 는
  이미 `position = gridToScreen(...)` 으로 화면 좌표를 잡은 컴포넌트다(`iso_entity.dart:40-43`).
  **4순위에서 가장 범하기 쉬운 버그**이며 §7 에 규약으로 박았다.
- **codex** — "`WorldTree` 가 이미 데이터-나무 선례다." ✅ `world_tree.dart:14-16`. 신규 기물보다 먼저
  써야 할 저위험 쇼케이스(§4 쟁점2).
- **grok** — "수직 prop 을 `GroundLayer` 에 구우면 깊이 가림이 영구히 틀린다."
  ✅ `ground_layer.dart:37` `priority: -100000` vs `iso_entity.dart:43` `depthPriority(grid)`.
  grok 이 **1차에서 스스로 주장했다가 2차에서 철회한** 항목이다(`grok-cowork.md` §7).
- **claude** — "provis 액터는 타일 폭의 1.2~1.6배(154~205px)를 전제로 설계됐는데 현 캐릭터는
  108px = 0.84배다." ✅ `iso_stage.dart:48-49`, `cyborg_design.dart:182`. provis 품질이 나오는
  크기가 아니라는 지적. 다만 키를 올리면 군중 겹침이 심해지므로 §8 로 보류.
- **kimi** — "초상과 인게임의 시드 fallback 이 다르다." ✅ `built_artist.dart:122` vs
  `src/iso/artist_rig.dart:35`. 해시 시드 아이디어의 숨은 전제조건(§4 쟁점1).

---

## 6. 반증 — 근거가 틀린 주장

| 주장 | 누가 | 반증 |
|---|---|---|
| "`CharacterBuild` 로 옮기면 infiltrator 의 여성형 실루엣이 나온다" | kimi | **틀렸다.** provis 에 sex 기반 체형 분기가 없다(§4 쟁점1). kimi 스스로 미독을 자백했다. 다만 kimi 는 원형 강제 매핑을 함께 제안했으므로, 정확한 반증은 "성별이 아니라 **폭 계약**을 재현할 통로가 없다"이다 |
| "`TreeProp` 은 색을 어떻게 칠해도 숲이 된다" | claude | **부분적으로 틀렸다.** `TreeKind.dead` 는 "잎이 없고 가지만 남았다"(`tree.dart:25-26`) — 캐노피가 없어 이 논리가 적용되지 않는다 |
| "Prop 전부를 GroundLayer 청크에 구워 넣는다" | grok 1차 | **grok 이 2차에서 스스로 철회.** 수직 prop 은 priority −100000 에 고정돼 깊이가 깨진다. 채택하지 않는다 |
| "`paintSurface` 는 파츠당 saveLayer 1 + blur 3~6 을 쓴다" | 종합 1차(주석 인용) | **틀렸다.** 그 문장은 `iso_view.dart:259-260` 주석이고, `shading.dart` 에 `saveLayer` 는 0건이며 `paintSurface` 는 `save()`+`clipPath()` 다(`shading.dart:291-292`). `Finish.metal` 기본 경로에 blur 없음(`:380-430`). codex 가 정확히 지적했다 |
| "스냅샷 테스트가 시각 회귀를 자동으로 잡아 준다" | (암묵 전제) | **틀렸다.** `cyborg_render_snapshot_test.dart` 는 `CYBORG_SNAPSHOT_DIR` 없으면 PNG 를 쓰지 않고, 단언은 "예외 없이 렌더링되는가 + 설계 수치"뿐이다(`test/cyborg_render_snapshot_test.dart:21-45`). codex 가 정확히 지적했다 |
| "README 418 µs × 50 = 예산 초과 확정" | (네 AI 공통 인용) | **불완전하다.** ① 260 µs 쪽은 13 ms 로 16.6 ms 를 넘지 않는다. ② 측정 루프는 `PictureRecorder` 기록까지만 포함하고 래스터화·GPU 합성이 빠져 있어(`example/test/facing_sweep_test.dart:48-64`) 총비용의 **하한**이다. 결론(고위험)은 유지하되 "초과 확정"으로 쓰지 않는다 |
| "서버 tick 24 Hz" | 시스템 프롬프트(`.cowork/cowork-prompt.md:22,52`) | 실제 서버 월드 틱은 **10 Hz 고정** — `MONSTER_AI_MICROS = 100_000` 이고 주석이 "**10 Hz** — 이 게임의 월드 틱이다"라고 명시한다(`spacetimedb/src/world.rs:141,172`). 별개로 **클라이언트 좌표 보고 주기**가 10 Hz 기본·혼잡 시 4 Hz 하한이다(`lib/spacetime/spacetime_world_presence.dart:44,50`) — 1차 종합은 이 둘을 "10 Hz(밀집 시 4 Hz)"로 뭉쳤다(kimi 지적, 확인). **어느 쪽도 렌더 예산과는 무관**하므로 이번 판단에 영향 없음 |

> codex 는 "시스템 프롬프트를 뒤집었으니 이 행을 삭제하라"고 요구했으나 반영하지 않았다.
> `.cowork/cowork-prompt.md` 는 프로젝트 배경 설명이지 사실의 원천이 아니고, 코드가 명시적으로 10 Hz 를
> 선언하며, 종합본은 이미 이 사실을 결론에서 격리했다. 사실을 사실대로 적고 영향 없음을 밝히는 편이
> 낡은 전제를 그대로 옮기는 것보다 낫다.

---

## 7. 최종 권고

> 범위: **`lib/**` 만 수정.** `packages/provis/**` 는 submodule 이므로 불변. 서버 불변.

| 순위 | 권고 | 파일 | 시각적 이득 | 위험 |
|---|---|---|---|---|
| **1** | **공용 브리지 신설** — `kGameIso`(=`const IsoView()`), 밝은 데이터 공간용 커스텀 `LightRig cyberDaylight`(높은 ambient·청록 rim), `GamePalette` → `Surface`/`Finish` 헬퍼를 한 곳에 모은다. 이후 모든 provis 호출이 이것만 쓴다 | 신규 `lib/game/visual/provis_bridge.dart` | 없음(기반) | 없음 — 신규 파일 |
| **2** | **지면 재질 이식** — `_bakeChunk` 안에 ① 얼룩 2층(큰/작은 blur 타원, **월드 좌표 시드**), ② 플레이트 단면(아래로 떨어지는 수직 그라디언트 = 회로 적층), 그리고 `GroundLayer.render()` 에 ③ **지면 전용 거리 감쇠 그라디언트**. ⚠️ provis `paintIsoHaze` 를 여기 그대로 쓰지 않는다 — 그 함수는 화면 `Rect view` 를 덮는 씬 전면 감쇠이고(`iso_stage.dart:294-312`), `GroundLayer` 는 `priority: -100000`(`ground_layer.dart:37`)이라 모든 액터 **아래**에 칠해진다. 진짜 전면 haze 를 원하면 액터 위·HUD 아래의 별도 뷰포트 레이어로 설계한다 | `lib/game/level/ground_layer.dart` | **가장 큼.** 체커 장판 → 두께와 깊이를 가진 데이터 표면 | 낮음~중. bake 시간 증가 → `_chunkBudgetPerFrame`(현 3) 조정 필요. **래스터 비용도 증가하므로 계측 필수**(§1 근거2). 청크 경계 이음새 |
| **3** | **grounded 기물 bake** — `GroundPatch(blades: 0)` · `PebbleField` · `PathPatch` · **`WaterProp(reeds: false, shallow: true)`**(데이터 풀 — 4인 모두 후보로 올렸고 `grounded => true`(`water.dart:76`)라 깊이 위험이 0이다. `TileType.stream` 과 의미가 겹치므로 stream 타일 **위가 아닌** 평지 저지대에만 심는다)를 청크 bake 에 결정론적으로 심는다. ⚠️ `PathPatch(tileWidth: 128, isoRatio: 0.5)` 를 **반드시 명시**(기본 156, `ground.dart:195`). ⚠️ 경계 처리: 현재 bake 캔버스는 `bounds.inflate(4)` 뿐인데(`ground_layer.dart:156`) `GroundPatch` 기본 반경은 90px 이다 — 장식은 **전역 feature-cell 로 소유 청크를 하나 정하고**, 이웃 청크가 같은 좌표로 재현하도록 inflate 폭을 prop bounds + blur 로 계산한다. 통행은 `LevelMap` 만 권위 | `lib/game/level/ground_layer.dart` | 지면에 불규칙성과 구역감 | 낮음~중. 경계 중복 소유 |
| **4** | **수직 기물 스트리밍** — 먼저 **`WorldTree` 재질 승급**(이미 "데이터가 자라 굳은 나무", `world_tree.dart:14-16` — 개체 1, 깊이 정렬 기존, 세계관 무충돌)으로 화풍을 A/B 검증한 뒤, `RockProp`(데이터 결정) · `MoundProp(walkOver: true)`(융기 지층) · `TreeProp(kind: dead)`(신호탑 잔해)를 **개별 `IsoEntity` 컴포넌트**로 감싸 기존 구조물 스트리밍 주기에 얹는다.<br>⚠️ **이중 투영 금지 규약**: `PropInstance.tile` 은 `Offset.zero` 로 두거나 `prop.paint()` 를 로컬 좌표에서 직접 부른다. 월드 타일을 `paintProp` 에 넘기면 `iso.project()`(`prop.dart:93`)와 `IsoEntity.position`(`iso_entity.dart:41-42`)이 **두 번 더해져** 기물이 맵 반대편에 그려진다.<br>⚠️ **통행**: provis 의 `Prop.walkable` 을 쓰지 않는다(`RockProp` 은 false·`tree` 는 bush 만 true). 게임은 `LevelMap` 만 권위이므로 이 기물들은 통행을 막지 않으며, 그래서 **관통해 보여도 어색하지 않은 곳**(비통행 타일 위·낮은 융기)에 배치하거나 홀로그램처럼 보이게 칠한다.<br>⚠️ **수량 예산**: 화면 내 동시 개체 상한을 수치로 정하고, `detailFor()`(`iso_view.dart:302-310`)로 거리별 디테일을 낮춘다. 정지 기물은 `TreeProp(wind: 0)` 등으로 형상을 고정해 캐시 가능 상태로 둔다 | 신규 `lib/game/level/provis_prop.dart`, `lib/game/level/world_tree.dart`, `lib/game/level/level_map.dart`, `lib/game/action_rpg_game.dart` — **초기 배선(`:281-305`)과 재시작 경로(`:2144-2175`) 양쪽** | 1 km 평면에 **높이와 랜드마크**가 생긴다 | **중.** 깊이 정렬·이중 투영·squash 규약(`paintProp` 은 grounded 에 `shadowRatio`, 수직에 `squash` 적용)·개체 예산 |
| **5a** | **PC 실루엣 보강(저위험)** — `drawBody` 시그니처 불변. 몸체 외곽에 `rimBand` 한 겹만 얹어 밝은 배경에서 실루엣이 살아남게 한다. 파츠 전면 `paintSurface` 없이 가능하며 blur 1~2회로 끝난다(`shading.dart:989-1008`). **PC 축을 이번 차수에 비우지 않기 위한 최소 산출물** | `lib/game/entities/cyborg_renderer.dart` | 배경 대비 실루엣 분리 | 낮음~중. 공유 4경로 전부에 영향(초상·프리뷰 포함) |
| **5b** | **PC 재질 승급(고위험)** — `_cylinderShade`/`_plateShade` 는 `Paint` 를 반환하는 헬퍼이고(`cyborg_renderer.dart:49,68`) `paintSurface` 는 `Canvas`+`Path` 를 받아 즉시 그리는 `void` 다(`shading.dart:274-286`) — **헬퍼 교체가 아니라 `_drawTorso`·`_drawHead`·동력팩의 해당 호출부를 Path 단위로 리팩터링**한다. 팔다리는 기존 그라디언트 유지.<br>⚠️ **캐시 전제**: 몸통·머리·동력팩처럼 프레임 간 형상이 고정된 파츠는 `quantizeYaw` 로 방향을 이산화한 `BakedPart` 로 굽고, 캐시 미스·임계 초과 시 기존 그라디언트로 폴백한다. 로컬 플레이어는 라이브, 원격 다수는 캐시로 분리한다.<br>⚠️ **자원**: `BakedPart` 를 쓰면 액터 제거 시 `dispose()` 필수이고 **광원이 바뀌면 전량 무효화**해야 한다(`iso_view.dart:262-263,293-294`).<br>⚠️ **`Finish.energy` 는 `BlendMode.plus` 가산 합성**(`shading.dart:636`)이라 밝은 데이터 공간에서 과다 노출된다 — 코어·눈 등 소면적에 한정하고 스크린샷으로 노출을 맞춘다 | `lib/game/entities/cyborg_renderer.dart` | 금속·발광의 재질감 | **높음.** 공유 4경로 회귀 + 50인 예산. 캐시 없이 전 파츠 적용은 하지 않는다 |
| — | **하지 않는다** — `CharacterBuild`/`HumanoidRenderer` 전면 이행 · `IsoSceneComponent`/`IsoController`/`IsoGrid` · `TreeProp` 활엽수/벚꽃/버들/덤불 · `GrassTuft`/`FlowerBed`/`FenceProp`/`StumpProp`/`LogProp` · `BuildingProp` · **세계관 확장(오염구역·이질적 자연)** — `GAME-DESIGN.md` 개정을 수반하므로 이번 차수에서 제외하고 형상이 중립적인 기물만 쓴다 · `kHeightUnit` 을 78.4 로 변경 · 타일 규격 150/156 | — | — | 채택 시 세계관·실루엣 계약·프레임 예산이 동시에 무너진다 |

**검증**:

- 각 단계 후 `flutter analyze`(error/warning 0) + `flutter test`.
- **1~3 은 렌더 경로 테스트를 건드리지 않는다. 4 는 `test/monster_render_path_test.dart` 를 반드시
  함께 돌린다** — 이 테스트는 `ActionRpgGame` 을 실제 `onLoad()` 하고 30프레임 돌려
  `game.world.children` 을 세는 **부팅·스트리밍 통합 테스트**다(`:68-88`, `:90-134`). 단언이
  `whereType<Enemy>()` 라 직접 충돌은 없으나 배선 예외는 여기서 터진다.
- 5a·5b 는 별도 커밋으로 분리하고 `CYBORG_SNAPSHOT_DIR` 로 PNG 를 뽑아 **59px·30px 축소에서 실루엣이
  살아 있는지** 확인한다. 스냅샷 테스트 자체는 픽셀 golden 이 아니므로(§6) 사람 눈 확인이 필요하다.
- **DTD 계측**(시스템 프롬프트 요구): 단계 2 직후 청크 이동 시 bake 시간과 raster 스레드 p50/p95,
  단계 4 직후 액터-기물 앞뒤 교차, 단계 5 직후 1/12/50인 프레임 비용. 계측을 5순위까지 미루지 않는다 —
  2순위가 이미 래스터 비용을 늘리기 때문이다.

---

## 8. 미해결 · 사람 판단 필요

- **캐릭터 키 108 → 150 전후 상향.** provis 권장 비율(타일 폭의 1.2~1.6배, `iso_stage.dart:48-49`)에는
  못 미치지만, 올리면 군중 겹침이 심해져 MMORPG 식별성이 **오히려 나빠질 수 있다**.
  `_tapHeight`·이름표·`_zoomForSize` 가 함께 움직인다. 스크린샷을 보고 사람이 판단하는 편이 낫다.
- **원격 플레이어 실루엣이 2종뿐이라는 약점.** 호박색은 이름표·HP바·미니맵 등 **UI 오버레이에서만**
  식별을 담당하고 몸체에는 쓰이지 않는다(§4 쟁점1). 서버 `kind` 를 늘리지 않고 실루엣 층에서 개인을
  가르는 방법(장비 색 변주·액세서리 슬롯)은 별도 설계가 필요하다.
- **세계관 확장 여부는 다음 차수에 재검토.** 이번 차수의 결론은 "확장하지 않는다"(§7 "하지 않는다").
  공식화하면 `TreeProp` 계열 전체와 `BuildingProp` 이 열리지만 `GAME-DESIGN.md` 개정을 수반한다.
- **`enemy.dart`(1,243줄) AI 로봇의 화풍 격차.** PC 와 지면만 개선하면 로봇이 상대적으로 낡아 보일
  수 있다. 이번 요청 범위(PC·맵) 밖이라 손대지 않았다.
- **실측 프로파일.** 현재 `drawBody` 의 프레임 비용이 측정된 적이 없어 provis 대비 배수는 `[추측]` 이다
  (§4 쟁점3 에서 "saveLayer 폭증" 근거를 철회했으므로 더욱 그렇다). `_bakeChunk` 에 blur 를 넣었을 때의
  굽기 시간과 청크 래스터 시간도 미측정 — **2순위 직후** DTD 계측 필요.
- **`kind` 해시 시드를 언젠가 살릴 경우의 전제조건.** `seed` 를 명시하지 않으면 초상(`BuiltArtist`,
  `id.hashCode`)과 인게임(`riggedFromArtist`, `Rng.fromString(id)`)의 몸이 갈린다(§5).

---

## 9. 적용 결과

> §1~8 은 **수정 전 사실의 기록**이므로 손대지 않았다. 이 절만 덧붙인다.

### 9.1 범위 변경 — 사람이 도중에 넓혔다

작업 중 사람이 두 번 개입했다.

1. **"pc 와 몬스터 디자인도 하고, 게임 맵 디자인도 해 주세요."**
   → `enemy.dart`(AI 로봇)는 §8 에서 "이번 요청 범위(PC·맵) 밖"으로 뒀던 항목인데,
   명시적으로 요청됐으므로 범위에 넣었다.
2. **"pc 와 몬스터의 디자인을 월등히 더 높여주세요. 특히 provis 패키지를 사용해서."**
   → §7 이 5b 를 "높음 위험 · 캐시 없이 전 파츠 적용은 하지 않는다"로 묶어 두었으나,
   사람이 재차 품질을 요구했으므로 **그 제한을 풀고 전 파츠로 확대**했다. 리포트의 판단을
   사람의 결정이 덮은 것이며, 그 사실을 여기 남긴다.

### 9.2 적용 — §7 순위대로

| 순위 | 상태 | 무엇을 했나 |
|---|---|---|
| 1 | ✅ | `lib/game/visual/provis_bridge.dart` 신설. `iso`(128×64) · 밝은 데이터 공간용 커스텀 `LightRig`(프리셋 ambient 가 짙은 남색이라 그대로 쓰면 지면이 회보라 장판이 된다) · 월드좌표 결정론 `Rng` · 팔레트→얼룩색 |
| 2 | ✅ | `ground_layer.dart` — 얼룩 2층(월드 고정 8타일 격자) · 플레이트 단면(회로 적층) · 지면 전용 거리 감쇠. `paintIsoHaze` 는 §7 경고대로 쓰지 않았다 |
| 3 | ✅ | 같은 파일 `_drawGroundProps` — `GroundPatch(blades:0)` · `PebbleField` · `PathPatch(tileWidth:128)` · `WaterProp(reeds:false, shallow:true)` 를 청크에 bake |
| 4 | ✅ | `WorldTree` 재질 승급(`Finish.gem`·`metal`·`rimBand`) → `provis_prop.dart` 신설로 `RockProp`·`MoundProp`·`TreeProp(dead)` 를 `IsoEntity` 스트리밍. `action_rpg_game.dart` 의 **초기 배선과 재시작 경로 양쪽** 갱신 |
| 5a | ⏭️ | **건너뛰었다.** 몸통에 이미 손으로 만든 림 라이트가 있어(`cyborg_renderer.dart` 흉갑 마무리) 중복이면 이득 없이 blur 비용만 는다 |
| 5b | ✅✅ | §7 제한을 풀고 **전 파츠**로: 팔·다리·무릎판·어깨패드·골반·흉갑·머리 → `Finish.metal`, 바이저 → `Finish.gem`. 손수 만든 셰이딩 헬퍼 `_cylinderShade`·`_plateShade` 를 **삭제**했다 |
| 추가 | ✅ | **몬스터**(범위 확대): 드론·보행형·중장갑형·지휘관의 판을 `Finish.metal`, 흉부 코어를 `Finish.energy` 로 |

### 9.3 리포트가 경고한 함정 — 전부 회피 확인

- **이중 투영**(§5 codex 고유통찰): `paintProp` 을 쓰지 않고 `prop.paint()` 를 로컬 좌표에서
  직접 불렀다. `ProvisPropComponent.render` 와 `_drawGroundProps` 양쪽에 근거를 주석으로 박았다.
- **깊이 붕괴**(§5 grok): 수직 기물은 `GroundLayer`(priority −100000)가 아니라 `IsoEntity` 로.
  `grounded == true` 인 것만 청크에 구웠다.
- **`tileWidth: 156` 기본값**: `PathPatch(tileWidth: kTileWidth)` 명시. `BuildingProp` 은 미채택.
- **통행 이중화**: provis `Prop.walkable` 을 쓰지 않고 `LevelMap` 만 권위로 뒀다. 서버가 모르는
  기물이 벽이 되면 클라이언트마다 다른 지형이 된다.
- **`Finish.energy` 과다 노출**: 가산 합성이므로 흉부 코어·바이저 같은 좁은 면적에만.
- **재시작 경로**: `_loadedProps.clear()` 추가.

### 9.4 리포트의 근거 하나를 실측으로 뒤집었다

§4 쟁점3 은 PC 를 후순위로 둔 이유 중 하나로 "`paintSurface` 는 파츠당 saveLayer 1 + blur 3~6"
을 들었고, 2차 리뷰가 이미 이를 정정했다. 구현 중 다시 확인했다.

```
packages/provis/lib/src/core/shading.dart  → 'saveLayer' grep 결과 0건
paintSurface  → c.save() + c.clipPath(path)
_metal(...)   → MaskFilter grep 결과 0건 (그라디언트 drawRect 중심)
```

즉 `Finish.metal` 은 예상보다 훨씬 싸다. **전 파츠 확대가 가능했던 실질적 근거**가 이것이다.

다만 공짜는 아니므로 방어선을 함께 넣었다 — `drawBody` 에 `detail` 파라미터를 신설하고 기본값을
**0.55**(몬스터는 0.45)로 두었다. 첫 승급 시트에서 다리가 얼룩덜룩했는데, 108px 캐릭터에 금속
스크래치를 전부 그린 탓이었다. provis 자신도 `detailFor` 에서 70px 이하에 0.25 를 준다.

### 9.5 화면 검수로 잡은 것 (사람이 스크린샷 4장을 보내 확인)

| 증상 | 원인 | 조치 |
|---|---|---|
| 지면이 여전히 흰 장판 | 얼룩 색을 `floorAlt`·`floorCircuit`·`floorStream` 에서 골랐는데 **전부 바탕(`floorBase`)과 명도가 비슷**해 그려도 보이지 않았다 | 바탕보다 **어두운** 쪽(`floorGrid`·`wallLeft`·`horizonGlow`)에서 고르도록 변경 |
| 얼룩이 여전히 옅음 | 방사형 그라디언트가 중심만 진하고 곧바로 투명 | 절반 지점까지 농도 유지(stops 3단), alpha 상향 |
| 화면이 더 창백해짐 | 거리 감쇠 alpha 0.34 가 과함 | 0.16 으로 |
| 격자가 지면을 지배 | 선 alpha 0.55 | 0.30 (세계관 요소라 제거하지 않고 이음새로 물러나게만) |
| 수직 기물이 화면에 하나도 없음 | 셀 16타일 × 30% | 10타일 × 55% |
| 결정·신호탑이 캐릭터보다 큼 | `RockProp` 은 내부에서 size 에 최대 1.35배를 더 곱한다 | size 46~82 → 28~48, 신호탑 150~240 → 115~165(`WorldTree` 236 과 확실히 구분) |
| 신호탑이 그냥 회색 고목 | 형상만 빌려와 정체성이 없음 | 가지 끝에 명멸 표지등 3개를 게임 쪽에서 덧그림 |

### 9.6 하지 못한 것

- **provis 기물 그림자가 검다.** `propShadow` 가 `0xFF05070E` 를 하드코딩한다
  (`packages/provis/lib/src/props/prop.dart:159`). 흰빛 데이터 공간에서 무겁다.
  레이어 `ColorFilter` 로 미는 우회를 시도했다가 **되돌렸다** — 그림자만 골라 밝힐 수 없어
  신호탑의 짙은 줄기까지 지워지고, 액터마다 `saveLayer` 가 하나씩 붙는다. 기물 크기를 낮춰
  그림자도 함께 줄이는 선에서 멈췄다. 근본 해결은 provis 에 그림자 색 인자가 필요하며
  그것은 submodule 수정이라 이번 범위 밖이다.
- **DTD 프레임 계측**(§7 검증 요구). 실행·스크린샷까지만 했고 bake 시간·raster p50/p95 는
  재지 못했다. 밀집(원격 20~50인) 상황의 실측도 없다. `detail` 방어선은 넣었으나 **수치로
  검증되지 않았다.**
- §8 의 캐릭터 키 상향, 원격 실루엣 다양화, 세계관 확장은 그대로 남는다.

### 9.7 검증

- `flutter analyze lib/` — **error 0**. warning 4 는 `git stash` 로 대조해 **변경 전과 동일**함을
  확인했다(내가 추가한 것 0).
- `flutter test` — 렌더 관련(스냅샷·몬스터 경로·월드트리·맵) 전부 통과.
  전체 실행에서 `login_flow_test.dart` 1건이 실패했으나 **단독 실행은 통과**하며, 실서버 통합
  테스트가 병렬 실행 시 흔들리는 flaky 다(변경 전 기준선에서도 통과).
- 시각 검수: `CYBORG_SNAPSHOT_DIR` 로 16방향 시트 PNG 를 뽑아 **59px 축소에서도 실루엣과
  두 프레임(VULCAN/WRAITH) 구분이 살아 있음**을 확인. macOS 릴리스 빌드를 띄워 게임 화면
  스크린샷으로 지면·기물·PC 를 확인.
- 커밋: `7bdb7f4` — 땅에 자국을 내고, 몸에 금속을 입힌다 (cowork: provis-visual-redesign)
