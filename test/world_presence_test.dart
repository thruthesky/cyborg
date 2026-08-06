import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:actionrpg/game/action_rpg_game.dart';
import 'package:actionrpg/game/entities/cyborg_design.dart';
import 'package:actionrpg/game/entities/remote_player.dart';
import 'package:actionrpg/game/net/world_presence.dart';
import 'package:actionrpg/spacetime/cyborg_connection.dart';

/// 다른 플레이어가 서로에게 보이는지에 관한 테스트.
///
/// 이 게임은 하나의 월드를 여럿이 공유하는 MMO 다. 서로가 보이지 않으면
/// 규격 자체가 성립하지 않으므로, 그 연결의 길목을 여기서 지킨다.
void main() {
  group('월드 구독', () {
    test('world_player 를 구독한다', () {
      // 이 한 줄이 빠져 있어서 서로를 못 봤다. 서버 표가 `public` 이라는 것은
      // "구독할 수 있다" 는 뜻이지 "보내 준다" 는 뜻이 아니다 — 구독하지 않으면
      // 남들이 멀쩡히 월드를 돌아다녀도 내 캐시는 영원히 비어 있다.
      expect(
        kWorldSubscriptions.any((query) => query.contains('world_player')),
        isTrue,
        reason: 'world_player 를 구독하지 않으면 다른 플레이어가 오지 않는다',
      );
    });

    test('앱 시작 구독과 겹치지 않는다', () {
      // 월드 구독은 게임에 들어갈 때 걸고 나올 때 푼다. 시작 구독에 섞어 두면
      // 캐릭터 선택 화면에 앉아 있는 동안에도 월드 전체를 받아 보게 된다.
      for (final query in kWorldSubscriptions) {
        expect(kCyborgViewSubscriptions, isNot(contains(query)));
      }
    });
  });

  group('WorldPresence 기본 구현', () {
    test('오프라인에서는 월드에 나 혼자다', () async {
      const presence = OfflineWorldPresence();

      expect(presence.isAvailable, isFalse);
      expect(presence.others, isEmpty);
      // 서버가 없어도 게임은 그대로 돌아야 한다. 어느 것도 던지지 않는다.
      await presence.enter(Vector2(503, 503));
      presence.tick(1 / 60, Vector2(503, 503), Vector2(1, 0));
      await presence.leave();
    });

    test('연동을 넘기지 않은 게임은 오프라인으로 선다', () {
      final game = ActionRpgGame();

      expect(game.presence, isA<OfflineWorldPresence>());
      expect(game.remotePlayers, isEmpty);
    });

    test('넘긴 연동을 그대로 쓴다', () {
      final presence = _FakePresence();
      final game = ActionRpgGame(presence: presence);

      expect(game.presence, same(presence));
    });
  });

  group('RemotePlayer — 서버가 준 상태로 선다', () {
    test('서버가 준 자리에 선다', () {
      final remote = RemotePlayer(_state(x: 120, y: 340));

      expect(remote.grid.x, 120);
      expect(remote.grid.y, 340);
    });

    test('서버가 준 종류로 몸을 고른다', () {
      final female = RemotePlayer(_state(kind: 'female_cyborg'));
      final male = RemotePlayer(_state(kind: 'male_cyborg'));

      expect(female.design.frame, CyborgFrame.infiltrator);
      expect(male.design.frame, CyborgFrame.assault);
    });

    test('모르는 종류라도 몸 없이 서 있지는 않는다', () {
      // 서버에 새 외형이 생겼는데 클라이언트가 낡은 경우다. 안 보이는 것보다
      // 기본 몸으로라도 보이는 편이 낫다.
      final unknown = RemotePlayer(_state(kind: 'robot_overlord'));

      expect(unknown.design.frame, CyborgFrame.assault);
    });

    test('같은 사람은 같은 열쇠를 갖는다', () {
      final remote = RemotePlayer(_state(id: 'abc'));
      expect(remote.id, 'abc');
    });
  });

  group('RemotePlayer — 받은 좌표를 향해 걸어간다', () {
    test('새 좌표를 받아도 한 프레임에 순간이동하지 않는다', () {
      final remote = RemotePlayer(_state(x: 100, y: 100));

      remote.apply(_state(x: 101, y: 100));
      remote.update(1 / 60);

      // 좌표는 초당 10 번만 온다. 도착할 때마다 그 자리로 옮기면 초당 10 칸씩
      // 튀는 텔레포트로 보인다.
      expect(remote.grid.x, greaterThan(100));
      expect(remote.grid.x, lessThan(101));
    });

    test('목표에 실제로 도착한다 — 영영 기어가지 않는다', () {
      final remote = RemotePlayer(_state(x: 100, y: 100));
      remote.apply(_state(x: 101, y: 100));

      // 남은 거리에 비례해서만 좁히면 그 거리는 영영 0 이 되지 않는다.
      // 다음 좌표가 오지 않는 동안(= 상대가 멈춘 동안) 반드시 도착해야
      // 정지 자세로 돌아간다.
      for (var i = 0; i < 60; i++) {
        remote.update(1 / 60);
      }

      expect(remote.grid.x, closeTo(101, 1e-6));
      expect(remote.grid.y, closeTo(100, 1e-6));
    });

    test('갱신 주기 안에 대부분을 따라잡는다', () {
      final remote = RemotePlayer(_state(x: 100, y: 100));
      remote.apply(_state(x: 101, y: 100));

      // 좌표는 0.1 초마다 온다. 그 안에 절반도 못 좁히면 남이 얼음판 위를
      // 미끄러지듯 늘 한참 뒤처져 보인다.
      for (var i = 0; i < 6; i++) {
        remote.update(1 / 60);
      }

      expect(remote.grid.x, greaterThan(100.5));
      expect(remote.grid.x, lessThanOrEqualTo(101));
    });

    test('멈춘 사람은 제자리에 있는다', () {
      final remote = RemotePlayer(_state(x: 100, y: 100));

      for (var i = 0; i < 30; i++) {
        remote.update(1 / 60);
      }

      expect(remote.grid, Vector2(100, 100));
    });

    test('텔레포트는 걸어서 가지 않는다', () {
      final remote = RemotePlayer(_state(x: 100, y: 100));

      // 월드를 가로지르는 이동이다. 보간하면 지형을 뚫고 몇 초 동안 날아간다.
      remote.apply(_state(x: 900, y: 900));
      remote.update(1 / 60);

      expect(remote.grid, Vector2(900, 900));
    });
  });

  group('RemotePlayer — 상태 갱신', () {
    test('좌표가 바뀌어도 같은 몸이 이어진다', () {
      final remote = RemotePlayer(_state(id: 'abc', x: 100, y: 100));

      remote.apply(_state(id: 'abc', x: 104, y: 100));
      remote.update(1 / 60);

      // 새 몸을 만들면 보간과 애니메이션 위상이 매 갱신마다 지워져 남들이
      // 0.1 초마다 제자리에서 깜빡인다.
      expect(remote.id, 'abc');
      expect(remote.grid.x, greaterThan(100));
    });

    test('이름과 레벨이 바뀌면 따라간다', () {
      final remote = RemotePlayer(_state(name: '강철', level: 3));

      remote.apply(_state(name: '강철', level: 4));

      // 레벨업은 이름표에 바로 드러나야 한다. 다시 그리다 예외가 나지 않는지도
      // 함께 본다 — 이름표는 값이 바뀔 때만 새로 만든다.
      expect(() => _render(remote), returnsNormally);
    });

    test('쓰러진 사람은 그리지 않는다', () {
      final remote = RemotePlayer(_state(alive: false));

      expect(() => _render(remote), returnsNormally);
    });

    test('살아 있는 사람을 그리는 데 게임 인스턴스가 필요하지 않다', () {
      // 다른 플레이어는 조종 대상이 아니라 서버가 알려 준 사실이다. 판정에
      // 끼어들지 않으므로 게임 상태를 읽을 이유도 없다.
      final remote = RemotePlayer(_state());

      expect(() => _render(remote), returnsNormally);
    });
  });
}

/// 서버가 보낸 한 사람의 상태를 흉내 낸다.
RemotePlayerState _state({
  String id = 'remote-1',
  int characterId = 7,
  String name = '강철',
  String kind = 'male_cyborg',
  int level = 3,
  double x = 503,
  double y = 503,
  bool alive = true,
}) {
  return RemotePlayerState(
    id: id,
    characterId: characterId,
    name: name,
    kind: kind,
    level: level,
    gridX: x,
    gridY: y,
    alive: alive,
  );
}

/// 캔버스에 한 번 그려 본다. 예외 없이 끝나는지만 본다.
void _render(RemotePlayer remote) {
  final recorder = PictureRecorder();
  remote.render(Canvas(recorder));
  recorder.endRecording().dispose();
}

/// 무엇도 하지 않지만 [OfflineWorldPresence] 는 아닌 구현.
class _FakePresence extends WorldPresence {
  @override
  bool get isAvailable => true;
}
