import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:spacetimedb_sdk/spacetimedb_sdk.dart';

import '../../dev/dev_login.dart';
import '../../spacetime/cyborg_connection.dart';
import '../../spacetime/generated/client.dart';
import '../../spacetime/generated/world_player.dart';
import 'world_presence.dart';

/// 같은 월드에 있는 다른 플레이어를 SpacetimeDB `world_player` 표로 주고받는다.
///
/// ## 하는 일은 셋뿐이다
///
/// 1. `world_player` 를 **구독**한다. 구독하지 않으면 표가 `public` 이어도 행이
///    한 줄도 오지 않는다 — reducer 는 멀쩡히 성공하는데 화면에는 아무도 없는,
///    "혼자 하는 MMO" 가 된다. 실제로 그 상태였다.
/// 2. [enter] 로 월드에 들어가 내 행을 만든다.
/// 3. [tick] 이 내 좌표를 주기적으로 올린다.
///
/// 남의 좌표를 받아 보간하고 그리는 일은 게임 쪽([RemotePlayer])이 한다. 여기는
/// 표를 그대로 옮기기만 하고 화면을 모른다.
class SpacetimeWorldPresence extends WorldPresence {
  SpacetimeWorldPresence(this._client);

  final SpacetimeDbClient _client;

  /// 좌표를 올리는 주기(초). 초당 10 번.
  ///
  /// 매 프레임(초당 60번) 보내면 사람 수만큼 곱해져 서버 트랜잭션이 폭증하는데,
  /// 받는 쪽은 어차피 보간해서 그리므로 그 차이를 볼 수 없다. 반대로 너무 늦추면
  /// 보간 구간이 길어져 남이 미끄러지듯 움직인다. 10 Hz 는 그 사이다.
  static const double _moveInterval = 0.1;

  /// 이만큼도 움직이지 않았으면 보내지 않는다(타일).
  ///
  /// 가만히 서 있는 사람이 초당 10 번 트랜잭션을 만들 이유가 없다.
  static const double _moveEpsilon = 0.04;

  /// 월드 입장을 다시 시도하는 간격(초).
  ///
  /// 연결이 끊기면 서버는 내 행을 지운다(`on_disconnect`). SDK 가 다시 붙어도
  /// 월드에는 없는 상태이므로, 스스로 다시 들어가지 않으면 그때부터 남의 눈에
  /// 보이지 않는다.
  static const double _retryInterval = 3.0;

  /// 거절이 이어질 때 늘려 가는 재시도 간격의 상한(초).
  static const double _maxRetryInterval = 15.0;

  int? _querySetId;

  /// 지금 월드에 들어가 있는지. 곧 "내 행이 서버에 있는지" 다.
  bool _inWorld = false;
  bool _entering = false;

  /// 다음 입장 시도까지 기다릴 시간(초).
  ///
  /// **재시도를 영영 멈추지 않는다.** 예전에는 몇 번 거절당하면 포기했는데,
  /// 거절 사유("아직 캐릭터를 고르지 않았다")는 시간이 지나면 저절로 풀리는
  /// 조건이다. 갓 만든 계정이 캐릭터 생성·선택을 서버에 반영하는 사이에 게임
  /// 화면이 먼저 뜨면 그 짧은 창에 걸리는데, 거기서 포기해 버리면 **접속해
  /// 있는 내내 남의 눈에 보이지 않는 사람**이 된다. 실제로 새 계정으로 띄운
  /// 클라이언트가 그렇게 사라졌다. 대신 간격만 늘려 서버를 두드리는 빈도를
  /// 낮춘다 — 15 초에 한 번은 아무 부담이 아니고, 조건이 풀리는 즉시 들어간다.
  double _retryDelay = _retryInterval;

  double _moveElapsed = 0;
  double _retryElapsed = 0;
  bool _sending = false;

  /// 마지막으로 서버에 올린 좌표. [_moveEpsilon] 비교의 기준이다.
  Vector2? _sentGrid;

  /// 마지막으로 서버에 올린 시선. [_facingEpsilonCos] 비교의 기준이다.
  Vector2? _sentFacing;

  /// 시선이 이 코사인값보다 더 벌어져야 다시 보낸다(약 8°).
  ///
  /// 두 단위벡터의 내적이 곧 사이각의 코사인이라, 1 에 가까울수록 "거의 같은
  /// 쪽" 이다. 미세한 흔들림까지 보내면 가만히 선 사람이 초당 10 번 트랜잭션을
  /// 만든다.
  static const double _facingEpsilonCos = 0.99;

  @override
  bool get isAvailable => true;

  @override
  Future<void> enter(Vector2 grid) async {
    if (_inWorld || _entering) return;
    _entering = true;
    devLog('월드 입장 시도…');
    try {
      // 구독이 먼저다. 입장이 성공했는데 구독이 없으면 내 행조차 돌아오지 않아
      // "들어간 것 같은데 아무도 없는" 상태가 된다.
      _querySetId ??= await _client.subscriptions.subscribe(kWorldSubscriptions);
      await _client.reducers.enterWorld(gridX: grid.x, gridY: grid.y);
      _inWorld = true;
      _sentGrid = null;
      _sentFacing = null;
      _retryDelay = _retryInterval;
      devLog('월드 입장 성공 (${grid.x.toStringAsFixed(1)}, '
          '${grid.y.toStringAsFixed(1)})');
    } on SpacetimeDbReducerException catch (e) {
      devLog('월드 입장 거절: $e — ${_retryDelay.toStringAsFixed(0)} 초 뒤 다시');
      // 아직 캐릭터가 서버에 반영되지 않았을 뿐일 수 있다. 포기하지 않고
      // 간격만 늘린다([_retryDelay] 참고).
      _backOff();
    } on SpacetimeDbException catch (e) {
      // 연결이 아직 안 섰다. [tick] 이 주기적으로 다시 부른다.
      devLog('월드 입장 실패(연결): $e');
      _backOff();
    } on Object catch (e) {
      // 여기까지 오는 것은 예상 못 한 종류의 실패다. 삼키면 원인을 영영 알 수
      // 없으므로 남긴다.
      devLog('월드 입장 실패(예상 밖): $e');
    } finally {
      _entering = false;
    }
  }

  /// 다음 입장 시도까지의 간격을 늘린다. 상한은 [_maxRetryInterval] 이다.
  void _backOff() {
    _retryDelay = math.min(_retryDelay * 2, _maxRetryInterval);
  }

  @override
  void tick(double dt, Vector2 grid, Vector2 facing) {
    if (!_inWorld) {
      _retryElapsed += dt;
      if (_retryElapsed >= _retryDelay) {
        _retryElapsed = 0;
        unawaited(enter(grid));
      }
      return;
    }

    _heartbeatElapsed += dt;
    if (_heartbeatElapsed >= _heartbeatInterval) {
      _heartbeatElapsed = 0;
      devLog('월드에 보이는 다른 요원: ${others.length} 명 '
          '(표 전체 ${_client.worldPlayer.iter().length} 줄)');
    }

    _moveElapsed += dt;
    if (_moveElapsed < _moveInterval) return;
    _moveElapsed = 0;
    unawaited(_sendPosition(grid, facing));
  }

  double _heartbeatElapsed = 0;

  /// 지금 몇 명이 보이는지 로그로 알리는 주기(초). 개발 로그가 켜졌을 때만 찍는다.
  static const double _heartbeatInterval = 5.0;

  /// 지금 좌표를 서버에 올린다.
  ///
  /// 전송 중이면 이번 값을 **버린다.** 진행도 보고와 달리 여기서 잃는 것은
  /// "0.1 초 전의 위치" 뿐이고, 다음 주기가 더 새로운 값을 들고 곧 온다.
  /// 밀린 좌표를 큐에 쌓아 뒤늦게 보내면 오히려 남의 화면에서 과거로 되돌아간다.
  Future<void> _sendPosition(Vector2 grid, Vector2 facing) async {
    if (_sending) return;

    final last = _sentGrid;
    if (last != null &&
        (last - grid).length2 < _moveEpsilon * _moveEpsilon &&
        // 제자리에서 방향만 튼 것도 남에게는 보이는 변화다. 좌표만 보고
        // 걸러내면 돌아선 사람이 남의 화면에서는 계속 이전 쪽을 보고 서 있다.
        (_sentFacing == null ||
            _sentFacing!.dot(facing) > _facingEpsilonCos)) {
      return;
    }

    _sending = true;
    try {
      await _client.reducers.moveTo(
        gridX: grid.x,
        gridY: grid.y,
        facingX: facing.x,
        facingY: facing.y,
      );
      _sentGrid = grid.clone();
      _sentFacing = facing.clone();
    } on SpacetimeDbReducerException catch (e) {
      // "먼저 월드에 들어가야 한다" — 끊겼다 다시 붙는 사이에 행이 지워졌다.
      // 다음 [tick] 이 재입장을 시도한다.
      devLog('좌표 보고 거절: $e');
      _inWorld = false;
      _sentGrid = null;
      _sentFacing = null;
    } on SpacetimeDbException catch (e) {
      // 연결이 끊긴 것뿐이다. 다음 주기에 다시 보낸다.
      devLog('좌표 보고 실패(연결): $e');
    } finally {
      _sending = false;
    }
  }

  @override
  Iterable<RemotePlayerState> get others {
    final me = _client.identity;
    // identity 가 아직 없을 수 있는 짧은 구간(초기 연결 직후)을 위해 캐릭터
    // 번호로도 한 번 더 거른다. 이 둘 중 하나라도 걸리면 나 자신이다 —
    // 내 몸 위에 내 아바타가 겹쳐 서 있는 것만큼 헷갈리는 화면이 없다.
    final myCharacterId = _client.mySession?.selectedCharacterId;

    return _client.worldPlayer.iter().where((row) {
      if (me != null && row.identity == me) return false;
      if (myCharacterId != null && row.characterId == myCharacterId) {
        return false;
      }
      return true;
    }).map(_toState);
  }

  RemotePlayerState _toState(WorldPlayer row) {
    return RemotePlayerState(
      id: row.identity.toHexString,
      characterId: row.characterId.toInt(),
      name: row.name,
      kind: row.kind,
      level: row.level,
      gridX: row.gridX,
      gridY: row.gridY,
      alive: row.alive,
    );
  }

  @override
  Future<void> leave() async {
    final id = _querySetId;
    _querySetId = null;
    _inWorld = false;
    _sentGrid = null;
    _sentFacing = null;

    try {
      await _client.reducers.leaveWorld();
    } on SpacetimeDbException {
      // 이미 끊겼다. 서버가 접속 해제로 알아서 내보낸다.
    } finally {
      if (id != null) _client.subscriptions.unsubscribe(id);
    }
  }
}
