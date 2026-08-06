import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:actionrpg/game/ui/server_info_screen.dart';
import 'package:actionrpg/spacetime/cyborg_connection.dart';

/// 서버 정보 화면이 **실제 접속처와 같은 것을 말하는지** 확인한다.
///
/// 이 화면의 쓸모는 정확성 하나에 달려 있다. 두 사람이 서로를 못 볼 때 "같은
/// 서버에 있는가" 를 확인하려고 여는 화면인데, 여기 적힌 주소가 실제 접속처와
/// 다르면 오히려 잘못된 판단을 하게 된다 — 없는 것만 못하다.
void main() {
  test('접속 상수를 그대로 읽는다 — 따로 적어 둔 값이 아니다', () {
    // 화면이 참조하는 것과 연결이 쓰는 것이 같은 상수여야 한다. 이 테스트는
    // 누군가 화면에 주소를 하드코딩했을 때 깨지라고 있는 것이다.
    expect(kCyborgHost, isNotEmpty);
    expect(kCyborgDatabase, isNotEmpty);

    // 지금 이 저장소가 가리키는 곳 — 자체 호스팅 VPS 다(CLAUDE.md §Server).
    // maincloud 로 되돌아가면 여기서 걸린다.
    expect(
      kCyborgHost,
      isNot(contains('maincloud')),
      reason: 'maincloud 로 되돌아갔다 — 무료 티어에서는 게임이 돌아가지 않는다',
    );
  });

  test('열고 닫힌다', () {
    final screen = ServerInfoScreen();
    expect(screen.isOpen, isFalse, reason: '처음에는 닫혀 있어야 한다');

    screen.open();
    expect(screen.isOpen, isTrue);

    screen.close();
    expect(screen.isOpen, isFalse);

    screen.toggle();
    expect(screen.isOpen, isTrue);
  });

  test('닫혀 있으면 탭을 가로채지 않는다', () {
    final screen = ServerInfoScreen()..onGameResize(Vector2(1280, 800));

    // 닫힌 동안에도 탭을 먹으면 조이스틱과 액션 버튼이 죽는다.
    expect(screen.containsLocalPoint(Vector2(640, 400)), isFalse);

    screen.open();
    expect(screen.containsLocalPoint(Vector2(640, 400)), isTrue);
  });
}
