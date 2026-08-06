import 'package:shared_preferences/shared_preferences.dart';
import 'package:spacetimedb_sdk/spacetimedb_sdk.dart';

/// 접속할 SpacetimeDB 호스트.
///
/// `spacetime.json` 의 `server` 와 같은 곳을 가리켜야 한다. 서버를 바꾸면
/// 여기와 `spacetime.json` 을 함께 고친다.
const String kCyborgHost = 'maincloud.spacetimedb.com';

/// 데이터베이스 이름. `spacetime.json` 의 `database` 와 같다.
const String kCyborgDatabase = 'withcenter-cyborg';

/// maincloud 는 wss/https 로만 받는다. 로컬 서버로 바꾸면 `false` 로 둔다.
const bool kCyborgSsl = true;

/// 접속하자마자 거는 구독.
///
/// **view 도 구독해야 행이 온다.** 이름이 `my_*` 라 서버가 알아서 밀어 줄 것
/// 같지만 그렇지 않다 — 구독하지 않으면 reducer 는 멀쩡히 성공하는데 클라이언트
/// 캐시는 영원히 비어 있어, "가입은 됐는데 로그인 화면에 그대로 있는" 증상이
/// 된다(`test/spacetime_integration_test.dart` 가 이 조합을 지킨다).
///
/// 실제 테이블(`account`·`account_secret`·`session`·`player_character`)은 모두
/// 비공개라 구독 대상이 아니다.
///
/// 여기 있는 셋은 앱이 켜져 있는 내내 필요하다. 리더보드는 볼 때만 필요하므로
/// 따로 뺐다([kLeaderboardSubscriptions]).
const List<String> kCyborgViewSubscriptions = [
  'SELECT * FROM my_account',
  'SELECT * FROM my_session',
  'SELECT * FROM my_characters',
];

/// 월드에 들어가 있는 동안 거는 구독.
///
/// **이것이 "같은 월드" 를 성립시키는 한 줄이다.** `world_player` 는 서버에서
/// `public` 이지만, 공개는 "구독할 수 있다" 는 뜻이지 "보내 준다" 는 뜻이 아니다.
/// 구독하지 않으면 남들이 멀쩡히 월드를 돌아다니는 동안 내 화면에는 아무도
/// 없는다 — 서로를 못 보던 원인이 이것이었다.
///
/// 표 전체를 받는다. 1 km 월드에 사람이 흩어져 있어도 행 하나가 수십 바이트라
/// 지금 규모에서는 문제가 되지 않는다. 동시 접속이 수백을 넘기면 그때
/// 사각형 구독(`WHERE grid_x BETWEEN ...`)으로 좁힌다.
///
/// 몬스터(`monster`)는 아직 넣지 않는다. 클라이언트가 자기 개체군을 따로 굴리고
/// 있어서, 지금 함께 구독하면 같은 자리에 두 벌이 겹쳐 보인다. 그쪽은 몬스터를
/// 서버 권위로 옮기는 작업과 함께 다뤄야 한다.
const List<String> kWorldSubscriptions = [
  'SELECT * FROM world_player',
];

/// 리더보드 화면이 떠 있는 동안에만 거는 구독.
///
/// 순위표는 **누가 레벨업하든** 다시 계산되어 구독자 전원에게 밀려온다. 월드에
/// 사람이 많을수록 그 빈도가 올라가므로, 아무도 보고 있지 않은 동안까지 받아 둘
/// 이유가 없다. 화면을 열 때 걸고 닫을 때 푼다.
const List<String> kLeaderboardSubscriptions = [
  'SELECT * FROM leaderboard',
  'SELECT * FROM my_rank',
];

/// SpacetimeDB 접속 토큰을 기기에 저장한다.
///
/// 이 토큰은 곧 **이 기기의 identity** 이고, 서버의 `session` 표가 identity 를
/// 계정에 연결한다. 즉 토큰을 유지하는 것이 곧 "로그인 상태 유지" 다. 토큰이
/// 사라지면 새 identity 를 받게 되어 다시 로그인해야 한다.
///
/// 저장소로 `shared_preferences` 를 쓴다. 키체인(`flutter_secure_storage`)이
/// 더 안전하지만 플랫폼마다 별도 설정이 필요하고, 여기 담기는 값은 계정
/// 비밀번호가 아니라 **이 기기의 세션 토큰**이다. 기기 저장소를 읽을 수 있는
/// 공격자는 이미 앱 데이터 전체에 접근할 수 있다.
class PrefsTokenStore implements AuthTokenStore {
  static const String _key = 'spacetimedb_token';

  @override
  Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  @override
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
  }

  @override
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
