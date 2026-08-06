## 리뷰 판정

종합본은 대체로 타당하고, 핵심 판정(IsoScene 배제·128×64 유지·PC 전면 이행 기각·지면 bake 우선·`TreeKind.dead` 부분 채택·grok 1차 철회 반영)은 원본·코드와 잘 맞는다.  
**가장 중요한 결함:** §7 순위 5(PC 셰이딩)에서 claude·codex가 권고의 핵심으로 둔 **`BakedPart`/방향·부위 캐시·`quantizeYaw` 완화책**이 거의 빠져, “위험이 높음”만 남고 실행 가능한 방어선이 빈약해졌다. 사람이 자는 동안 오케스트레이터가 손대면 saveLayer 폭증으로 바로 깨질 수 있다.  
그다음으로, kimi 주장을 §4에서 **단정으로 과장 인용**한 점과, codex 고유의 **WorldTree 쇼케이스·이중 투영 함정** 누락이 실질적이다.

## 지적 사항

| # | 위치 | 종류 | 지적 | 반영 시 어떻게 |
|---|---|---|---|---|
| 1 | §7 순위 5 | 누락·권고 | PC 셰이딩을 넣으면서 원본의 필수 완화책이 빠졌다. claude는 `quantizeYaw(32)` + `BakedPart`(몸통·머리·동력팩 굽기, 팔다리 라이브)를 명시했고(`claude-cowork.md` §5-4), codex는 원격용 `(kind, action, 16방향, …)` 캐시를 2순위로 올렸다. final은 `paintSurface` 교체와 “50명 검산”만 남겼다. 시스템 프롬프트가 요구하는 **N명 환산 + 캐시 전략**이 권고 본문에서 끊긴다. | 순위 5에 (a) 부위 제한, (b) `BakedPart` 또는 동등 `ui.Picture` 캐시 키, (c) 캐시 미스/임계치 초과 시 기존 그라디언트 폴백, (d) 로컬 라이브 vs 원격 캐시 분리를 실행 조건으로 박아라. 캐시 없이 전 부위 `paintSurface`는 “하지 않는다”에 넣는 편이 안전하다. |
| 2 | §4 쟁점1 / kimi 재진술 | 과장·왜곡 | final은 kimi가 *“infiltrator 의 여성형 실루엣도 provis 가 만들어 준다”*고 찬성한 것처럼 적었다. 실제 kimi는 매핑표·시드 다양성을 제안했고, §6에서 **`HumanoidRenderer` 성별/`Sex` 처리는 미독·미확인**이라고 스스로 밝혔다(`kimi-cowork.md` §6). 반증 자체(sex→체형 미반영)는 맞지만, 소수 의견의 전제를 부풀린 뒤 부수는 형태다. | kimi 입장을 “시드 해시로 원격 다양성 + assassin/assassin 매핑 찬성; **여성 실루엣은 미확인**”으로 고쳐 쓰고, 기각 근거는 codex가 검증한 `toSpec()` sex 누락에 집중하라. |
| 3 | §4 쟁점1 결론 문장 | 과장 | *“VULCAN/WRAITH 실루엣 구분이 **원리적으로 불가능**”*은 과하다. `sex`가 체형에 안 들어가는 것은 직접 확인됨(`character_build.dart:99-114`, `spec.dart`에 sex 없음). 다만 `heightScale`·`muscle`·`armorHeaviness`·`archetype`으로 **부분 실루엣 차이는 가능**하다. “현 `CyborgDesign` 수치(오목 허리·어깨 34 등)를 재현할 API가 없다”가 정확한 표현이다, 전면 이행 기각 결론은 그대로 유지 가능하다. | “원리적으로 불가능” → “성별/프레임 수치 계약을 provis 어휘로 **동등 재현 불가**; 남는 것은 색·대략적 원형뿐”으로 완화. |
| 4 | §5·§7 | 누락 | codex 고유 통찰 **`WorldTree` 우선 쇼케이스**가 사라졌다. `world_tree.dart:14-16`은 이미 “데이터가 자라 굳은 나무” 세계관 선례이고, 충돌 없음·`IsoEntity` 깊이 정렬이 갖춰져 있다. TreeProp `dead` 신규 배치(순위 4, 중위험)보다 **기존 랜드마크 재질 승급이 저위험·고정합**인데 권고 표에 없다. | §5에 codex 항목으로 추가하고, §7에 순위 3~4 사이(또는 수직 prop 전에) “`WorldTree`에 metal/energy·provis 가지 기법 이식”을 넣어라. 세계관 확장 없이도 맵이 “멋져 보이는” 검증 가능한 1차 산출물이 된다. |
| 5 | §7 순위 4 위험 열 | 누락 | codex가 강조한 **이중 투영** 함정이 없다: 컴포넌트가 이미 `gridToScreen`으로 이동한 뒤 `paintProp`에 월드 `tile`을 다시 넘기면 위치가 이중 적용된다(`prop.dart` / codex §3-4). squash·깊이만 적혀 있으면 구현 시 기물이 화면 밖으로 튀는 전형적 버그가 재발한다. | 순위 4 위험에 “로컬 원점 + `prop.paint` 또는 `PropInstance.tile=0` 규약 / 월드 tile 재주입 금지”를 명시. |
| 6 | §7 검증 문단 | 누락 | 맵·스트리밍을 건드리는 순위 3~4인데, codex가 짚은 `test/monster_render_path_test.dart`(컴포넌트 수·배선) 위험이 없다. final은 `cyborg_render_snapshot_test`와 “1~4는 렌더 테스트 비해당”에 가깝게 쓰지만, **맵 스트리밍 구조 변경은 스냅샷이 아니어도 테스트가 깨질 수 있다.** | 검증에 `monster_render_path_test` 포함 여부 확인을 넣고, “1~4 무관” 단정을 철회하거나 범위 한정(“PC 스냅샷만 무관”)으로 고쳐라. |
| 7 | §3 합의 “세 화면이 drawBody 공유” | 미검증·누락 | 인용 세 곳(`player`·`remote`·`portrait`)은 맞다. 그러나 grok/codex가 적은 **`cyborg_preview.dart:53` 네 번째 공유 경로**가 빠졌다. 시그니처 불변 권고의 근거를 약하게 만든다. | “4경로 공유(… + `cyborg_preview.dart`)”로 고치고, 순위 5 영향 범위에 프리뷰를 포함. |
| 8 | §7 기물 목록 vs 원본 | 누락·논리 | 다수 원본이 `WaterProp(reeds: false)`를 데이터 풀로 권했는데(claude 3·codex 5·grok 1·kimi 5), final 권고 표에는 **Water가 없다.** §3에서 `reeds` 기본 true까지 검증해 놓고 실행 목록에서 증발했다. | grounded bake(순위 3) 또는 구역 장식에 `WaterProp(color: stream/hazard 계열, reeds: false)`를 재삽입하거나, “이번 범위 제외 + 이유”를 §8에 명시. |
| 9 | §1·§7 vs 요청 범위 | 논리 | 시스템 프롬프트 요구는 **멋진 PC + 멋진 맵**이다. final 결론은 맵 중심이 강하고 PC는 “셰이딩만·5순위”다. 다수 원본·sex/어휘 근거상 전면 이행 기각은 옳다. 다만 **요청 대비 의도적 범위 축소**가 §1에 한 줄로 선언되지 않아, 오케스트레이터가 PC를 미완성으로 끝낼 여지를 남긴다. | §1에 “이번 완료 정의: 맵 풍요 + PC 재질 승급; 골격/`CharacterBuild`/임플란트 어휘는 후속(§8)”을 완료 조건으로 못 박아라. |
| 10 | §5 claude 귀속 | 과장(경미) | “지면=최대 이득/최저 위험 연결은 claude만”은 다소 과하다. grok 1순위·kimi 2순위도 같은 축이다. claude가 **단색 fill 5회 해부 + iso_stage 장판 경고 연결**을 가장 선명히 한 것은 사실이다. | “가장 선명히 연결” 정도로 표현을 낮추면 공정성이 산다. 판정(지면 우선)은 유지. |

## 유지해야 할 강점

- **`CharacterBuild.sex` → `toSpec()` 미전달 / `HumanoidSpec`에 sex 없음**을 직접 열어 확인한 뒤 kimi 전면 이행을 기각한 판정 — 자료 기반 이견 처리의 모범.
- **`TreeKind.dead` 주석·형상 근거로 claude 전량 배제와 다수 채택을 절충**한 쟁점 2 — “형상은 색으로 안 지워진다” 논리를 살리면서도 실행 가능한 기물을 남김.
- **grok 1차 “수직 prop 전부 GroundLayer bake” 철회**를 §5·§6·§7에 일관 반영 — 반증 누락 없음.
- **IsoSceneComponent 배제, 타일 128×64 유지, 고도 78.4 vs 56은 z 미사용 시 무관, BuildingProp `tileWidth: 156` 함정, LightRig 프리셋 암흑** 등 §3 합의 항목이 실제 파일과 대체로 일치.
- **스냅샷 테스트가 픽셀 golden이 아니라 예외+설계 수치**라는 codex 지적, README µs에 래스터 미포함 — §6 반증으로 잘 살림.
- **서버 kind 2종 불변 · provis submodule 불변 · 통행은 LevelMap 권위 · 장식 walkable** — 시스템 프롬프트·서버 원칙과 충돌하지 않음.
- 우선순위 표에 (파일·이득·위험)이 있고, “하지 않는다” 목록이 명확함.

## 확신도

- **높음 (코드·원본 직접 확인):** sex/`toSpec` 누락, TreeKind.dead 주석, GroundLayer 단색 fill·priority −100000·budget 3, IsoView 기본 128×64, BuildingProp tileWidth 156, WaterProp reeds 기본 true, drawBody 4경로, `_maxRemotePlayers = 50`, 스냅샷 테스트 동작, kimi §6 미독 문구, claude/codex의 BakedPart·캐시 권고, codex WorldTree·이중 투영 문구.
- **중간:** “지면이 PC 셰이딩보다 시각 이득이 크다”는 아트 판단(구조·위험 비교는 타당하나 스크린샷 실측 없음). WaterProp 의도적 제외 여부(원본엔 있고 final엔 없어 **누락으로 보는 쪽**이 타당).
- **[추측] 아님 / 측정 부재는 종합본 §8과 동일:** 현재 `drawBody` vs `paintSurface` 실측 배수, blur bake 스파이크 크기.
