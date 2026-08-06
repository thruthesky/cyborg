import 'package:flame/components.dart';

/// 월드에 함께 들어와 있는 다른 요원 한 명의 최신 상태.
///
/// 서버 `world_player` 행을 게임이 쓰는 형태로 옮긴 것이다. **값 객체다** —
/// 갱신은 새 스냅샷으로 갈아 끼우고, 화면에 서 있는 몸([RemotePlayer])이 그
/// 값으로 자기를 맞춘다.
class RemotePlayerState {
  const RemotePlayerState({
    required this.id,
    required this.characterId,
    required this.name,
    required this.kind,
    required this.level,
    required this.gridX,
    required this.gridY,
    required this.alive,
  });

  /// 이 사람을 가리키는 안정적인 열쇠. 서버 identity 를 문자열로 옮긴 값이다.
  ///
  /// 캐릭터 번호가 아니라 identity 를 쓰는 이유는 서버 표의 기본 키가 그것이기
  /// 때문이다. 한 사람이 캐릭터를 바꿔 다시 들어와도 같은 행이 갱신될 뿐이라,
  /// 화면에서도 같은 몸이 이어진다.
  final String id;

  final int characterId;
  final String name;

  /// 서버가 아는 캐릭터 종류 id(`male_cyborg` 등). 어떤 몸으로 그릴지 정한다.
  final String kind;

  final int level;

  final double gridX;
  final double gridY;

  /// 서버가 보는 생사. 쓰러진 사람은 그리지 않는다.
  final bool alive;

  Vector2 get grid => Vector2(gridX, gridY);
}

/// 같은 월드에 있는 다른 플레이어를 주고받는 연동 지점.
///
/// 게임 로직은 이 인터페이스만 알고 있으므로 백엔드가 없어도 그대로 돌아간다.
/// 실제 구현은 `lib/game/net/spacetime_world_presence.dart` 에 있다.
///
/// [GameSync] 와 나눠 둔 이유는 두 통신의 성격이 다르기 때문이다. 진행도 보고는
/// **가끔 올리기만 하는** 단방향이고 늦어도 되지만, 여기는 **초당 여러 번
/// 오가는** 양방향이라 지연이 곧 조작감이다. 한 인터페이스에 묶으면 한쪽 사정에
/// 맞춘 주기가 다른 쪽을 망친다.
abstract class WorldPresence {
  const WorldPresence();

  /// 서버가 다른 플레이어를 알려 줄 수 있는 상태인지.
  bool get isAvailable => false;

  /// 월드에 들어간다. 이 뒤로 내 위치가 남에게 보이기 시작한다.
  ///
  /// [grid] 는 입장할 자리다. 서버가 자리를 정하지 않고 받는 이유는 재접속 때
  /// 서 있던 곳으로 돌아가기 위해서다.
  Future<void> enter(Vector2 grid) async {}

  /// 매 프레임 호출된다. 내 위치와 시선을 주기적으로 올린다.
  ///
  /// [facing] 까지 보내는 이유는 남이 **어느 쪽을 보고 있는지**가 좌표만으로는
  /// 복원되지 않기 때문이다. 멈춰 서서 방향만 튼 사람은 좌표가 그대로라, 받는
  /// 쪽에서 이동 방향으로 추측하면 계속 엉뚱한 데를 보고 서 있게 된다.
  void tick(double dt, Vector2 grid, Vector2 facing) {}

  /// 지금 월드에 보이는 **나를 제외한** 사람들.
  Iterable<RemotePlayerState> get others => const [];

  /// 월드에서 나간다. 로그아웃·화면 종료처럼 더는 [tick] 이 오지 않는 길목에서.
  ///
  /// 부르지 않아도 서버가 접속 해제를 감지해 내보내지만(`on_disconnect`),
  /// 그때까지 남는 몇 초 동안 조종하는 사람이 없는 몸이 월드에 서 있게 된다.
  Future<void> leave() async {}
}

/// 아무와도 연결되지 않은 오프라인 구현. 월드에는 나 혼자다.
class OfflineWorldPresence extends WorldPresence {
  const OfflineWorldPresence();
}
