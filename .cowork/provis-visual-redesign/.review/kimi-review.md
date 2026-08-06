• 종합본의 핵심 근거를 실제 파일과 대조하겠습니다.

• 마지막으로 테스트 관련 주장 몇 가지를 확인합니다.

• 지적 1건을 더 확인하기 위해 시드 불일치 주장의 근거를 열어 봅니다.

• ## 리뷰 판정

  종합본은 대체로 타당하다. §3 합의 표와 §4 판정의 근거를 직접 열어 대조한 결과 치명적 왜곡·환각은 발견되지 않았고, 특히 쟁점1(`CharacterBuild.sex` 미반영)은 오케스트레이터가 직접 검증해 다수결이 아니라 자료로 뒤집은 올바른 판정이다. 다만 **실질 결함 하나**: §7 권고 5(PC 셰이딩)에서 claude·codex 양쪽이 "필수"라고 한 캐시 기제(`quantizeYaw` + `BakedPart` / 원격 Picture 캐시)가 통째로 빠져, 종합본 스스로 §4 쟁점3에서 "최악 50명 화면에서 가장 위험한 변경"이라 적은 변경을 완충장치 없이 권고하게 됐다. 이 외에 구현자가 범하기 쉬운 함정(이중 투영) 누락과 사소한 인용 부정확이 있다.

  ## 지적 사항

  | # | 위치 | 종류 | 지적 | 반영 시 어떻게 |
  |---|---|---|---|---|
  | 1 | §7 권고 5 | 누락/권고 | claude 4순위(`quantizeYaw(yaw,32)` + `BakedPart` 64장 + 캐시 미스 시 기존 경로 폴백)와 codex 1~2순위("원격 캐시를 **먼저** 갖추는 것이 필수")의 핵심 완충장치가 권고문에서 탈락했다. §4 쟁점3에서 `paintSurface` 가 파츠당 saveLayer 1 + blur 3~6(`iso_view.dart:259-260` 확인)라고 스스로 적었으므로, 캐시 없는 권고 5는 근거보다 위험한 권고가 됐다 | 권고 5에 "몸통·머리·동력팩은 `quantizeYaw(32)` 로 이산화한 `BakedPart` 캐시(디자인 2종×32방향)로 굽고, 캐시 미스·임계 초과 시 기존 그라디언트 경로로 폴백" 을 명시 |
  | 2 | §7 권고 4 | 누락 | codex 가 명시한 **이중 투영 함정**이 없다. `IsoEntity.syncTransform` 이 이미 `position = gridToScreen(grid)` 를 잡는다(`iso_entity.dart:41-42` 확인). 그 안에서 `paintProp` 에 월드 `tile` 을 다시 넘기면 투영이 두 번 적용돼 기물이 엉뚱한 곳에 그려진다 — "개별 `IsoEntity` 로 감싼다"는 지시를 받은 구현자가 가장 범하기 쉬운 실수 | 권고 4에 "`PropInstance.tile` 은 원점으로 두고(또는 `prop.paint` 를 로컬 좌표에서 호출) 컴포넌트 `position` 에만 월드 투영을 맡긴다" 한 줄 추가 |
  | 3 | §6 "서버 tick 24 Hz" 행 | 미검증 | "실제는 10 Hz(밀집 시 4 Hz)"의 근거를 `world.rs:141-172` 로만 적었지만, 4 Hz 는 그 파일에 없다(grep 확인). 4 Hz 는 **클라이언트 좌표 보고 주기 하한**이다(`lib/spacetime/spacetime_world_presence.dart:46-50` 직접 확인). 서버 월드 틱은 `MONSTER_AI_MICROS = 100_000` 으로 10 Hz 고정(`world.rs:141,172`). 서버 틱과 클라이언트 업로드 주기를 한 항목 "(밀집 시 4 Hz)"로 섞어 표기했다 | 행을 둘로 분리: "서버 월드 틱 10 Hz 고정(`world.rs:141,172`)" / "클라이언트 보고 주기 10 Hz, 혼잡 시 4 Hz 하한(`spacetime_world_presence.dart:44-50`)" |
  | 4 | §4 쟁점1 · §5 | 누락 | codex 의 고유 발견 — `BuiltArtist` 는 시드 fallback 으로 `id.hashCode`(`built_artist.dart:121-123` 확인), `riggedFromArtist` 는 `Rng.fromString(id)`(`src/iso/artist_rig.dart:29-35` 확인 — codex 인용 경로 `src/art/` 는 오기) — 가 빠졌다. 이것은 kimi 의 "kind 해시 → 시드 결정론"이 **seed 를 명시할 때만** 성립함을 보여주는 반증인데, 종합본은 "아이디어 자체는 좋으나 지금 채택하지 않는다"로만 평가해 함정을 남겼다 | §4 쟁점1 말미에 "해시 시드 아이디어를 살리더라도 seed 를 명시하지 않으면 초상(`BuiltArtist`)과 인게임(rigged)의 몸이 갈라진다 — seed 강제가 전제 조건" 각주 추가 |
  | 5 | §7 권고 5 | 누락(경미) | grok 의 경고 — `Finish.energy` 는 `BlendMode.plus`(가산)라 밝은 배경에서 과다 노출 — 이 탈락했다. "빛으로 가득 찬 데이터 공간"에 `Finish.energy` 를 권하면서 주의가 없다 | 권고 5에 "energy 마감은 코어·눈 등 소면적에 한정하고 스크린샷으로 노출 튜닝" 추가 |
  | 6 | §7 검증 문단 | 과장(경미) | "1~4 는 렌더 테스트를 건드리지 않는다"는 단정이 codex 의 경고를 증발시켰다. 권고 4 는 `action_rpg_game.dart` 의 스트리밍 배선을 건드리고, `test/monster_render_path_test.dart:68-80`(직접 확인)은 바로 그 배선(서버 몹 → 화면 마운트)을 검증한다 — 깨질 수 있는 테스트가 존재한다 | 검증 문단을 "1~3 은 렌더 경로 테스트 무관, 4 는 `monster_render_path_test` 로 배선 회귀 확인"으로 수정 |
  | 7 | §7 권고 2 | 누락(경미) | haze 를 `GroundLayer.render()` 에 넣으면 `priority: -100000`(`ground_layer.dart:37`)상 모든 액터 **아래**에 칠해져, provis `paintIsoHaze`(씬 전면 감쇠)와 의미가 달라진다. claude 도 "HUD 아래에 들어가야 한다(priority 확인 필요)"라고 남겼으나 종합본이 탈락시켰다 | "지면 전용 거리 감쇠"라는 의도를 명시하거나, 전면 haze 가 목적이면 별도 레이어와 priority 를 명기 |
  | 8 | §3·§5·§6 인용 | 미검증(경미) | 줄번호 미세 드리프트: `shading.dart:129`(ambient 실제 `:131`), `water.dart:34`(reeds 기본값 실제 `:35`), `iso_stage.dart:47-49`(실제 `:48-49`), `tree.dart:26-27`(실제 `:25-26`). 내용은 전부 정확하고 줄만 1~2 어긋남 | 줄번호 일괄 교정(내용 변경 불필요) |

  ## 유지해야 할 강점

  - **§4 쟁점1 의 직접 검증**: `toSpec()` 의 `copyWith` 인자 목록(`character_build.dart:99-115`)에 sex 가 없고, `spec.dart` 에 sex 0건, `creature.dart:18-24` 의 `Sex` 가 라벨·기호 전용임을 내가 재확인했다. kimi 의 전제를 자료로 뒤집은 이 판정은 종합본 최고의 부분이다.
  - **§3 합의 표의 정확성**: `IsoView` 기본값 128×64(`iso_view.dart:16`), `heightScale ≈78.4`(`:37`), `_bakeChunk` 단색 fill 5회(`ground_layer.dart:192-201`), `CHARACTER_KINDS` 2종(`character.rs:23`), `drawBody` 3곳 공유(`player.dart:1218`·`remote_player.dart:435`·`cyborg_portrait.dart:124`), `_maxRemotePlayers = 50`(`action_rpg_game.dart:248`), README 260~418 µs(`README.md:257-264`) — 전부 실재한다.
  - **§6 반증의 공정성**: grok 의 자기철회, claude 의 `TreeProp` 부분 오류(`tree.dart:25-26` 의 `dead` 주석으로 확인), kimi 의 미독 자백을 다수결로 묻지 않고 각각 정확히 처리했다. 소수의 논리와 다수의 결론이 절반씩 맞은 `TreeProp` 부분 채택 판정도 자료와 일치한다.
  - **시스템 프롬프트의 낡은 전제 교정**: 프롬프트 전제 ④(156×78)와 "24 Hz tick"을 실제 코드(`iso_view.dart:16`, `world.rs:141-172`)로 바로잡은 것은 프롬프트 지시 1·4에 정확히 부합한다.
  - **§8 의 솔직함**: 미측정 항목(현 `drawBody` 비용, blur 굽기 시간)을 `[추측]`/미측정으로 남기고 사람 판단 지점을 명시한 부분.

  ## 확신도

  - 지적 1·2·3·6·7·8: **직접 파일을 열어 확인**했다(해당 파일:줄을 본문에 명기).
  - 지적 4: codex 의 주장을 직접 검증했고 **사실로 확인** — 단 codex 의 인용 경로(`src/art/artist_rig.dart`)는 존재하지 않고 실제는 `src/iso/artist_rig.dart` 다.
  - 지적 5: grok 의 인용(`shading.dart:637`)을 근거로 하며 해당 줄은 **직접 확인하지 않았다** [부분 추측] — 다만 `Finish.energy` 가 존재하고 권고 5 가 밝은 배경 위 가산성 마감을 무주의로 권하는 구조적 문제는 성립한다.
  - 종합본 §3 표의 10개 행 전부, §4 쟁점 1~3, §5·§6 의 주요 인용을 실제 파일과 대조 완료 — 위 표에 없는 항목은 불일치를 발견하지 못했다.

