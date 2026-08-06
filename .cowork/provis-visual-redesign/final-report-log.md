## 리뷰 라운드 — 2026-08-06 20:04

> 4 AI 리뷰(claude·codex·grok·kimi) → claude 종합 → final-report.md **갱신**

- **§1·§4 쟁점3 — `ui.Picture` 오해 정정(codex 1).** `render()` 가 매 프레임 `drawPicture` 하는 것을 확인(`ground_layer.dart:355-360`). Picture 는 명령 목록이지 래스터 캐시가 아니므로 "프레임 비용 0·공짜" 를 "기록 비용만 상각, 래스터 비용은 증가 → 계측 필요" 로 낮췄다. 지면 1순위 결론은 근거를 갈아끼워 유지.
- **§4 쟁점3·§6·§7 5b — "saveLayer 폭증" 철회(codex 3).** `shading.dart` 전체에 `saveLayer` 0건, `paintSurface` 는 `save()`+`clipPath()`(`:291-292`), `_metal` 에 blur 없음(`:380-430`)을 grep·직독으로 확인. 원본은 `iso_view.dart:259-260` **주석**을 구현으로 오인했다. PC 후순위 근거를 공유 4경로·50인 예산으로 교체.
- **§3·§6 — 벤치 수치 정정(codex 4).** 260 µs×50 = 13 ms 는 16.6 ms 미만이므로 "13~21 ms > 16.6 ms" 는 거짓. 또 기록만 잰 값이라 총비용의 **하한**이다(원본·claude 7 은 "상한" 이라 했으나 방향이 반대). claude 7 은 그래서 반영하지 않고 codex 4 로 대체.
- **§7 4순위 — 이중 투영 규약 추가(codex/claude/grok/kimi 공통).** `prop.dart:93` 의 `iso.project()` 와 `iso_entity.dart:41-42` 의 `position` 이 겹치는 것을 확인, §5 통찰과 위험 칸에 명시. 재시작 경로(`action_rpg_game.dart:2144-2175`)도 직접 열어 파일 칸에 반영.
- **§4 쟁점1 — "원리적으로 불가능" 완화(codex 2·grok 3).** `spec.dart:171-174` 의 생성식(hip 0.166h < shoulder 0.232h)과 `cyborg_design.dart:230-234`(hip 21 > chest 18)를 대조해 "동등 재현 불가" 로 재서술. kimi 입장도 원문대로(원형 매핑 제안·성별 미독) 정정. 기각 결론은 유지. 호박색이 UI 오버레이 전용임(claude 4)도 확인해 §8 로 이관.
- **§7 3·4순위 — 누락 복원.** `WaterProp(reeds:false, shallow:true)`(§3 에서 검증해 놓고 실행 목록에서 증발, claude 2·grok 8), `PathPatch` 의 156 기본값과 `GroundPatch` 90px vs `inflate(4)` 이음새(codex 5), `WorldTree` 우선 쇼케이스(codex 9·grok 4), `BakedPart`/`quantizeYaw` 캐시·`dispose`·`Finish.energy` 가산 주의(grok 1·kimi 1·5·claude 9), haze priority(codex 6·kimi 7), `Prop.walkable` 미사용 명시(codex 7)를 전부 근거 확인 후 반영. PC 축이 비지 않도록 5 를 5a(rimBand)·5b(재질)로 분할(claude 5).
- **검증·구조·인용 정리.** "1~4 는 렌더 테스트 무관" → `monster_render_path_test.dart:68-134` 를 직접 열어 "4 는 반드시 함께" 로 수정. §8 의 세계관 결론을 §7 "하지 않는다" 로 이동(claude 6). `drawBody` 3경로 → **4경로**(`cyborg_preview.dart:53`, grok 7). 줄번호 교정: `shading.dart:131`·`water.dart:35`·`iso_stage.dart:48-49`·`tree.dart:25-26`, 어깨폭 34/25.
- **반영하지 않은 지적.** codex 10(24 Hz 반증 삭제) — `world.rs:141,172` 가 명시적으로 10 Hz 이고 원본이 이미 "판단에 영향 없음" 으로 격리했다. `.cowork/cowork-prompt.md` 는 배경 설명이지 사실 원천이 아니다. 대신 kimi 3 을 반영해 서버 월드 틱(10 Hz)과 클라이언트 보고 주기(10 Hz/4 Hz 하한, `spacetime_world_presence.dart:44,50`)를 분리 표기했다.

- 원본 백업: `.review/final-report.before.md`

---

