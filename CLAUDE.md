# Cyborg

- It is an action RPG game
- It is an MMORPG. Many players share the same live world at the same time.


## Workflow

You, as AI, must follow the instructions below.

- [ ] Git commit & push after work
- [ ] 작업이 끝난 다음 "/cowork:cowork ..." 를 통해서 수정 보완 작업을 해 주세요.

## Overview

- AI Robot conquered the world, Human cyborg fight back to save the world.

## References

- 형제 게임 라리엔: ` ~/apps/game/laryen` 폴더를 보고, 라리엔 게임의 로직/코드를 바탕으로 기능/코드를 복사해와도 됩니다. 단, 절대로 라리엔 게임 소스 코드를 수정해서는 안됩니다. 반드시, ` ~/apps/game/laryen` 폴더는 읽기 전용으로만 참고해야 합니다.



## World

- One open world map. Every player plays on that single shared map.
- No per-match instance, no separated stage. Players join the world, not a session.


## Multiplayer

- Multiple users must be able to join the world and play in it at the same time.
- A party travels and hunts together, and **shares experience**.
  Kill credit itself stays solo: the first attacker owns the monster, and the
  loot and the kill record go to that owner alone. There is no shared damage
  credit and no party loot rule.
- Experience from a kill is split among party members who were within 30 tiles
  of where the monster fell, alive, and in the same party. The total grows with
  headcount (+10% per extra member, so 2.1x at twelve), is divided evenly, and
  is then scaled per member by how close their level is to the monster's level
  (full within 10 levels, then 50% / 25% / nothing). The owner is exempt from
  that scaling and keeps the division remainder. A party member hunting alone
  earns exactly what they would solo.
- Party members may follow their leader. A follower auto-hunts around the leader
  and shares in every kill the group lands nearby.
- Monsters are still shared world objects. A monster one player kills is dead
  for everyone, and the kill belongs to a single player.
- Other players' presence, movement and combat must be visible to each other in real time.
- PK is allowed. A PC can attack another PC. **Party members are the one exception:
  they cannot attack each other.** Joining a party is the promise not to. This is
  not a PK-free zone — you still fight anyone outside your party, and contesting
  a tagged monster still means fighting its owner. The exception exists because
  shared experience rewards standing close together, and a swing that reaches the
  same monsters reaches the ally beside it.


## Tech Stack

- Flutter and Flame to build 2.5d isometric game.
- SpacetimeDB for the backend. **자체 호스팅 VPS 를 쓴다** — 아래 §Server 참조.


## Server

### 🛑 반드시 자체 호스팅 VPS 를 쓴다. maincloud 를 쓰지 말 것.

**`maincloud.spacetimedb.com` 으로 배포·접속하지 말라.** 무료 티어의 한도와 스로틀
때문에 게임이 돌아가지 않는다. 실측으로 확인한 것:

| | maincloud (무료) | 자체 VPS (전용) |
|---|---|---|
| AI 틱 (설정 대비 실측) | 41.7ms → **1,220ms** (30배 밀림) | 33.3ms → **35.6ms** (7% 오차) |
| `move_to` 왕복 | 300~850ms | **230ms** (= 순수 네트워크. 서버 처리 ≈ 0) |
| CPU | 발산 · reducer 10초 타임아웃 | **2.7%** |
| 에너지 | 아무도 접속 안 해도 **3일**이면 소진 | 제한 없음 |

maincloud 에서 "AOI 32 기 · 24 Hz" 로 서버가 죽었던 일이 있는데, 같은 코드가 VPS 에서는
**30 Hz 를 CPU 2.7% 로** 돌린다. 무료 인스턴스의 문제였지 코드나 SpacetimeDB 의 문제가
아니었다. **그 구별을 잊고 maincloud 수치로 성능을 판단하지 말 것.**

### 접속 정보

```
호스트     167.88.45.173
포트       3000
프로토콜   http / ws        (TLS 아직 없음 — kCyborgSsl = false)
DB 이름    withcenter-cyborg
CLI 별칭   myspace
버전       SpacetimeDB 2.7.1
월드 틱    30 Hz — 서버 `MONSTER_AI_MICROS` 와 클라 `_fastInterval` 을 **함께** 맞춘다
SSH        ssh root@167.88.45.173
```

⚠️ 이 VPS 는 **미국 보스턴**에 있다. 한국에서 왕복 **약 220ms**다. 서버 처리는 빠르지만
거리에서 오는 지연은 남아 있으므로, "느리다" 는 관찰이 나오면 **처리 지연인지 왕복
지연인지 먼저 가를 것**(`test/move_latency_test.dart` 가 이 둘을 나눠 찍는다).

### 사용법

```bash
# 배포 — -s myspace 를 빠뜨리면 maincloud 로 나간다
spacetime publish -p ./spacetimedb withcenter-cyborg -s myspace -y

# 조회 · 로그 · reducer 호출
spacetime sql   withcenter-cyborg -s myspace "SELECT id, level FROM monster LIMIT 5"
spacetime logs  withcenter-cyborg -s myspace -n 200
spacetime call  withcenter-cyborg -s myspace rebuild_monsters
spacetime call  withcenter-cyborg -s myspace reset_timers    # 틱 주기를 바꾼 뒤 반드시

# Dart 바인딩 재생성 (spacetime CLI 는 dart 를 지원하지 않는다)
dart run spacetimedb_sdk:generate --project-path ./spacetimedb --output lib/spacetime/generated
```

클라이언트 접속 설정은 [`lib/spacetime/cyborg_connection.dart`](lib/spacetime/cyborg_connection.dart)
맨 위 세 상수(`kCyborgHost`·`kCyborgDatabase`·`kCyborgSsl`)가 단일 진실이다.

### 운영

```bash
ssh root@167.88.45.173

docker ps --filter name=spacetimedb          # 상태
docker logs -f spacetimedb                   # 서버 로그
docker restart spacetimedb                   # 재시작
docker stats spacetimedb --no-stream         # CPU·메모리
```

- 컨테이너 이름 `spacetimedb` · 이미지 `clockworklabs/spacetime:v2.7.1`
- 데이터 볼륨 `/opt/spacetimedb/data` — **컨테이너를 지워도 DB 는 남는다**
- `--restart unless-stopped` — 서버 재부팅 후 자동 기동
- **같은 VPS 에 다른 서비스가 돌고 있다**(Caddy 80/443, Postgres 5433, Redis 6380,
  Centrifugo 8000). 포트와 Caddy 설정을 건드리지 말 것.

### 버전을 맞출 것

서버 이미지(2.7.1)와 로컬 CLI 의 메이저·마이너가 어긋나면 배포나 구독이 조용히 깨진다.
로컬 CLI 를 올렸다면 서버 이미지도 같은 태그로 올리고, 그 반대도 마찬가지다.


## Debugging and Testing

- Always test with DTD. Do not test the game by running and injecting/emulating the typeing or click becuase the human developer is always actively using computer and keyboard.
- Always inject the test code/function/event-handler into main() or initState() to move the page or run the event handler.
  - For instance, to login, inject login email/password on the inputs and call the event handler of login.
- Take screenshots or check logs to debug and test.


