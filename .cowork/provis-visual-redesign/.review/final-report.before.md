# final-report — provis-visual-redesign

> 요청: provis 패키지를 submodule 로 붙이고(완료), 그것으로 cyborg 게임의 **PC 디자인과 게임 맵
> 디자인**을 멋지게 만들어라. 사람은 자러 갔고 끝까지 완료해야 한다.
>
> 분석: claude · codex · grok(2-pass) · kimi 4인 모두 성공.
> ⚠️ claude·kimi 는 1차에서 900초 제한 초과로 실패해 `COWORK_TIMEOUT=2400` 으로 재실행했다.
> 종합: 오케스트레이터가 근거 `파일:줄` 을 직접 열어 교차검증.

---

## 1. 결론

**PC 렌더러는 갈아엎지 말고 셰이딩만 빌린다. 진짜 약점은 지면이고, 거기가 공짜다.**

세 가지가 이 순서를 강제한다.

1. **지면은 실제로 비어 있다.** `GroundLayer._bakeChunk` 는 타일 종류별 단색 fill **5번** + 격자선 +
   도관 + 테두리가 전부다(`lib/game/level/ground_layer.dart:192-201` 직접 확인). provis 가 "이렇게
   하면 땅이 아니라 **장판**이 된다"고 명시적으로 경고한 바로 그 구조다
   (`packages/provis/lib/src/iso/iso_stage.dart:110-122`).
2. **그 지면은 `ui.Picture` 안에 구워져 96개까지 캐시된다**(`ground_layer.dart:47,153-208`).
   여기에 무엇을 더 그리든 **매 프레임 비용은 `drawPicture` 한 번으로 동일하다.** 깨질 테스트도 없다.
3. **PC 를 provis 캐릭터 체계로 옮기면 잃는 것이 얻는 것보다 크다.** `CharacterBuild.sex` 는
   **체형에 전혀 반영되지 않는다** — `toSpec()` 이 sex 를 넘기지 않고, `HumanoidSpec` 에 sex 개념
   자체가 없다(직접 확인, §4 쟁점1). VULCAN(남성 강습)/WRAITH(여성 침투)의 실루엣 구분이
   **원리적으로 불가능해진다.**

따라서 실행 순서는 **① 공용 브리지 → ② 지면 재질 → ③ grounded 기물 → ④ 수직 기물 → ⑤ PC 셰이딩**이다.
아이소 규격은 **바꾸지 않는다** — provis `IsoView` 기본값이 이미 128×64 로 게임과 같다.

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
| `WaterProp` 은 `reeds: true` 가 기본 | ✅ `water.dart:34` — 명시적으로 꺼야 갈대가 안 나온다 |
| `BuildingProp` 은 `tileWidth: 156` 이 기본 | ✅ `building.dart:96` — 게임에 넣으려면 128 명시 필수 |
| `LightRig` 프리셋은 어두운 씬용 | ✅ `daylight.ambient = 0xFF31415F`(`shading.dart:129`) 등 모두 어두운 남색. 밝은 데이터 공간에는 커스텀 리그가 필요 |
| 서버가 아는 외형은 2종뿐 | ✅ `CHARACTER_KINDS = ["male_cyborg","female_cyborg"]`(`spacetimedb/src/character.rs:23`) |
| 세 화면이 `drawBody` 를 공유 | ✅ `player.dart:1218` · `remote_player.dart:435` · `cyborg_portrait.dart:124` |
| 원격 다수에서 provis 풀 렌더는 예산 초과 | ✅ README 실측 260~418 µs/인(`README.md:257-264`), `_maxRemotePlayers = 50`(`action_rpg_game.dart:248`) → 최악 13~21 ms > 16.6 ms |

---

## 4. 이견 — 자료로 판정

### 쟁점 1 — PC 를 `CharacterBuild`/`HumanoidRenderer` 로 이행할 것인가

- **kimi(찬성, 3순위)**: `kind` 문자열을 해시해 시드로 쓰면 서버 무수정으로 원격마다 다른 몸이
  나온다. `infiltrator` 의 여성형 실루엣도 provis 가 만들어 준다.
- **claude·codex·grok(반대 또는 최후순위)**: 사이보그 어휘 부재, 성별 미반영, 프레임 예산.

**판정: 기각 (자료가 소수 3인을 지지한다).**

kimi 자신이 §6 에서 *"`HumanoidRenderer.paint` 의 내부 구현(성별 `Sex` 처리)은 미독"* 이라고 적었다.
그 미독 부분을 직접 열었다.

```
packages/provis/lib/src/actor/character_build.dart:99-115  toSpec()
  → HumanoidSpec.generate(s, forceArchetype: archetype) 를 부르고
    copyWith(palette, headGear, weapon, hasCape, hasPauldrons, hasShield,
             armorHeaviness, muscle, hairLength, glowRunes, heightScale)
    ← sex 가 없다.
packages/provis/lib/src/actor/spec.dart  → 'sex'/'Sex' grep 결과 0건.
packages/provis/lib/src/art/creature.dart:18-24 → enum Sex 는 label('Male')·symbol('♂') 전용.
```

즉 **provis 에서 `Sex` 는 표시용 라벨이고 체형 생성에 전혀 관여하지 않는다.** kimi 의 전제
("infiltrator 의 여성형 실루엣이 나온다")가 성립하지 않는다. 이행하면 `CyborgDesign` 이 수치로
들고 있는 두 프레임의 차이(`cyborg_design.dart:178-268` — 어깨폭 34/·, 오목 허리, 골반 높이,
목 길이)가 통째로 사라지고, 남는 구분은 색뿐이다.

추가로 provis 캐릭터 어휘는 판타지 전용이다 — `Archetype {knight…paladin}` ·
`WeaponKind {sword…bow}` · `HeadGear {…hornedHelm}`(`spec.dart:8,21,23`). 임플란트 7종·바이저·
동력팩(`cyborg_design.dart:283-304`)을 담을 자리가 없다.

**kimi 의 "kind 해시 → 시드로 다양성" 아이디어 자체는 좋으나 지금 채택하지 않는다** — 원격
플레이어가 무작위 원형(mage·ranger)으로 나오면 "인간 사이보그 저항군"이 아니게 된다.
군중 식별은 이미 `GamePalette.remotePlayer` 호박색과 이름표가 담당한다(`palette.dart:130-134`).

### 쟁점 2 — `TreeProp` 을 쓸 것인가

- **claude(배제)**: "색을 어떻게 칠해도 초가지붕은 초가지붕이고 활엽수 캐노피는 나무다."
- **codex·grok·kimi(채택)**: 광섬유 군락 / 데이터 수관 / 안테나 고사목으로 재해석.

**판정: 부분 채택.** claude 자신이 §6 에서 *"`TreeKind` 7종의 실제 형상은 보지 않았다"* 고 적었다.
열어 보니 종마다 실루엣이 근본적으로 다르다(`packages/provis/lib/src/props/tree.dart:14-37`).

| 종 | 주석 원문 | 판정 |
|---|---|---|
| `dead` | "잎이 없고 **가지만 남았다**. 실루엣 자체가 이야기를 한다" | **채택** — 잎이 없으니 "나무 티"가 나는 캐노피가 아예 없다. 데이터 공간의 안테나·붕괴한 신호탑으로 읽힌다 |
| `conifer` | "처진 바늘잎 층이 위로 좁아진다. **수직선을 만들어 화면을 잡아 준다**" | **조건부 채택** — 청록 단색 + 낮은 밀도로 데이터 스파이어 |
| `broadleaf`·`blossom`·`willow`·`bush` | 둥근 수관 / 꽃 / 늘어진 잎 | **배제** — claude 가 옳다. 색을 바꿔도 숲이다 |

즉 claude 의 논지("형상은 색으로 지울 수 없다")를 채택하되, 그 기준을 적용하면 `dead` 는
**통과한다**. 다수의 결론과 소수의 논리를 자료가 각각 절반씩 지지한 경우다.

`BuildingProp` 은 `WallStyle.stone` · `RoofStyle.flat` 이 실재하지만(`building.dart:14-40`),
텍스처 단위가 돌·벽돌이라 데이터 센터로 읽힐지 불확실하다 → **이번 범위에서 제외**(§8).

### 쟁점 3 — 무엇을 1순위로 할 것인가

- **codex**: PC 셰이딩 + 캐시가 1순위.
- **claude·grok·kimi**: 지면이 먼저.

**판정: 지면 먼저.** claude 의 논거를 직접 검증했고 모두 사실이다.

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
지목한 바로 그것이다(`iso_stage.dart:113-114`). 그리고 이 전부가 `ui.Picture` 안이므로
**런타임 프레임 비용 증가가 0이고, 이 경로를 검증하는 테스트가 없다.**

반면 PC 셰이딩(`paintSurface`)은 파츠당 saveLayer 1 + blur 3~6 을 쓴다(`iso_view.dart:260-262`)
— 최악 50명 화면에서 가장 위험한 변경이다. **위험이 낮고 이득이 큰 것부터** 한다.

---

## 5. 고유 통찰 — 하나만 발견했으나 검증됨

- **claude** — "지면이 진짜 약점이고 청크 캐시 안이라 공짜다." 다른 셋도 청크 bake 를 언급했지만,
  *현재 지면이 단색 fill 5번뿐이라는 사실*과 *그래서 여기가 가장 큰 이득/가장 낮은 위험*이라는
  연결을 지은 것은 claude 뿐이다. ✅ 검증됨.
- **codex** — "`CharacterBuild.sex` 가 체형에 반영되지 않는다." 쟁점1 을 뒤집은 결정적 사실.
  ✅ 검증됨(§4).
- **grok** — "수직 prop 을 `GroundLayer` 에 구우면 깊이 가림이 영구히 틀린다."
  ✅ `ground_layer.dart:37` `priority: -100000` vs `iso_entity.dart:44` `depthPriority(grid)`.
  grok 이 **1차에서 스스로 주장했다가 2차에서 철회한** 항목이다(`grok-cowork.md` §7).
- **claude** — "provis 액터는 타일 폭의 1.2~1.6배(154~205px)를 전제로 설계됐는데 현 캐릭터는
  108px = 0.84배다." ✅ `iso_stage.dart:47-49`, `cyborg_design.dart:182`. provis 품질이 나오는
  크기가 아니라는 지적. 다만 키를 올리면 군중 겹침이 심해지므로 §8 로 보류.

---

## 6. 반증 — 근거가 틀린 주장

| 주장 | 누가 | 반증 |
|---|---|---|
| "`CharacterBuild` 로 옮기면 infiltrator 의 여성형 실루엣이 나온다" | kimi | **틀렸다.** provis 에 sex 기반 체형 분기가 없다(§4 쟁점1). kimi 스스로 미독을 자백했다 |
| "`TreeProp` 은 색을 어떻게 칠해도 숲이 된다" | claude | **부분적으로 틀렸다.** `TreeKind.dead` 는 "잎이 없고 가지만 남았다"(`tree.dart:26-27`) — 캐노피가 없어 이 논리가 적용되지 않는다 |
| "Prop 전부를 GroundLayer 청크에 구워 넣는다" | grok 1차 | **grok 이 2차에서 스스로 철회.** 수직 prop 은 priority −100000 에 고정돼 깊이가 깨진다. 채택하지 않는다 |
| "스냅샷 테스트가 시각 회귀를 자동으로 잡아 준다" | (암묵 전제) | **틀렸다.** `cyborg_render_snapshot_test.dart` 는 `CYBORG_SNAPSHOT_DIR` 없으면 PNG 를 쓰지 않고, 단언은 "예외 없이 렌더링되는가 + 설계 수치"뿐이다(`test/cyborg_render_snapshot_test.dart:21-45`). codex 가 정확히 지적했다 |
| "README 418 µs 를 그대로 프레임 비용으로 쓸 수 있다" | (네 AI 공통 인용) | **불완전하다.** 측정 루프는 `PictureRecorder` 기록까지만 포함하고 래스터화·GPU 합성이 빠져 있다(`example/test/facing_sweep_test.dart:44-68`). 상한 추정으로만 쓴다 |
| "서버 tick 24 Hz" | 시스템 프롬프트 | codex 가 `spacetimedb/src/world.rs:141-172` 근거로 실제는 10 Hz(밀집 시 4 Hz)라고 지적. **렌더 예산과는 무관**하므로 이번 판단에 영향 없음 |

---

## 7. 최종 권고

> 범위: **`lib/**` 만 수정.** `packages/provis/**` 는 submodule 이므로 불변. 서버 불변.

| 순위 | 권고 | 파일 | 시각적 이득 | 위험 |
|---|---|---|---|---|
| **1** | **공용 브리지 신설** — `kGameIso`(=`const IsoView()`), 밝은 데이터 공간용 커스텀 `LightRig cyberDaylight`(높은 ambient·청록 rim), `GamePalette` → `Surface`/`Finish` 헬퍼를 한 곳에 모은다. 이후 모든 provis 호출이 이것만 쓴다 | 신규 `lib/game/visual/provis_bridge.dart` | 없음(기반) | 없음 — 신규 파일 |
| **2** | **지면 재질 이식** — `_bakeChunk` 안에 ① 얼룩 2층(큰/작은 blur 타원, **월드 좌표 시드**), ② 플레이트 단면(아래로 떨어지는 수직 그라디언트 = 회로 적층), 그리고 `GroundLayer.render()` 에 ③ 화면 haze 한 겹 | `lib/game/level/ground_layer.dart` | **가장 큼.** 체커 장판 → 두께와 깊이를 가진 데이터 표면 | 낮음. 굽기 비용 증가 → `_chunkBudgetPerFrame`(현 3) 조정 필요할 수 있음. 청크 경계 이음새 |
| **3** | **grounded 기물 bake** — `GroundPatch(blades: 0)` · `PebbleField` · `PathPatch` 를 청크 bake 에 결정론적으로 심는다. `grounded == true` 라 깊이 문제가 없다. 통행은 `LevelMap` 만 권위 | `lib/game/level/ground_layer.dart` | 지면에 불규칙성과 구역감 | 낮음. 경계 걸침은 inflate 로 대응 |
| **4** | **수직 기물 스트리밍** — `RockProp`(데이터 결정) · `MoundProp`(융기 지층) · `TreeProp(kind: dead)`(신호탑 잔해)를 **개별 `IsoEntity` 컴포넌트**로 감싸 기존 구조물 스트리밍 주기에 얹는다. **전부 `walkable`**(서버가 모르는 기물이므로 통행 막지 않음) | 신규 `lib/game/level/provis_prop.dart`, `lib/game/level/level_map.dart`, `action_rpg_game.dart` | 1 km 평면에 **높이와 랜드마크**가 생긴다 | **중.** 깊이 정렬·squash 규약(`paintProp` 은 0.866 압축, 게임 블록은 무압축)·bake 예산 |
| **5** | **PC 셰이딩 승급** — `CyborgRenderer.drawBody` **시그니처 불변**. 내부 `_cylinderShade`/`_plateShade` 를 `paintSurface(… Finish.metal/energy …)` + `rimBand` 로 교체하되 **몸통·머리·동력팩만**, 팔다리는 기존 그라디언트 유지 | `lib/game/entities/cyborg_renderer.dart` | 금속·발광의 재질감, 밝은 배경에서 실루엣이 살아남 | **높음.** saveLayer 폭증 위험. 최악 50명으로 검산 필요 |
| — | **하지 않는다** — `CharacterBuild`/`HumanoidRenderer` 전면 이행 · `IsoSceneComponent`/`IsoController`/`IsoGrid` · `TreeProp` 활엽수/벚꽃/버들/덤불 · `GrassTuft`/`FlowerBed`/`FenceProp`/`StumpProp`/`LogProp` · `BuildingProp` · `kHeightUnit` 을 78.4 로 변경 · 타일 규격 150/156 | — | — | 채택 시 세계관·성별 실루엣·프레임 예산이 동시에 무너진다 |

**검증**: 각 단계 후 `flutter analyze`(error/warning 0) + `flutter test`. 1~4 는 렌더 테스트를
건드리지 않는다. 5 는 별도 커밋으로 분리하고 `CYBORG_SNAPSHOT_DIR` 로 PNG 를 뽑아 **59px·30px
축소에서 실루엣이 살아 있는지** 확인한다.

---

## 8. 미해결 · 사람 판단 필요

- **캐릭터 키 108 → 150 전후 상향.** provis 권장 비율에는 못 미치지만, 올리면 군중 겹침이 심해져
  MMORPG 식별성이 **오히려 나빠질 수 있다**. `_tapHeight`·이름표·`_zoomForSize` 가 함께 움직인다.
  스크린샷을 보고 사람이 판단하는 편이 낫다.
- **세계관 확장 여부.** "데이터 공간에 침식한 이질적 자연 구역"을 공식화하면 `TreeProp` 계열 전체와
  `BuildingProp` 이 열려 시각적 풍요가 크게 늘지만 `GAME-DESIGN.md` 개정을 수반한다. 이번에는
  **확장하지 않고**, 형상이 중립적인 것만 쓴다.
- **`enemy.dart`(1,243줄) AI 로봇의 화풍 격차.** PC 와 지면만 개선하면 로봇이 상대적으로 낡아 보일
  수 있다. 이번 요청 범위(PC·맵) 밖이라 손대지 않았다.
- **실측 프로파일.** 현재 `drawBody` 의 프레임 비용이 측정된 적이 없어 provis 대비 배수는 `[추측]`.
  `_bakeChunk` 에 blur 를 넣었을 때의 굽기 시간도 미측정 — 5순위 착수 전 DTD 계측 권장.

---

## 9. 적용 결과

*(구현 후 기록)*
