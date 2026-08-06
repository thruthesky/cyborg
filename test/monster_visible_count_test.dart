@Tags(['integration'])
library;

/// **실제 렌더 조건으로 화면에 몇 기가 잡히는지** 잰다.
///
/// 구독으로 오는 수와 화면에 그려지는 수는 다르다. 그 사이를 두 가지가 자른다 —
/// 스트리밍 반경(`_monsterReleaseRadius`)과 표시 상한(`_maxActiveMonsters`).
/// "몬스터가 안 보인다" 를 말할 때 어느 단계에서 사라지는지 갈라야 한다.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:spacetimedb_sdk/spacetimedb_sdk.dart';

import 'package:actionrpg/spacetime/cyborg_connection.dart';
import 'package:actionrpg/spacetime/generated/client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 클라이언트가 실제로 쓰는 값(`ActionRpgGame`).
  const renderRadius = 34.0;
  const screenHalfWidth = 22.0;

  Future<SpacetimeDbClient> joinAt(double x, double y, String name) async {
    final client = await SpacetimeDbClient.create(
      host: kCyborgHost,
      database: kCyborgDatabase,
      ssl: kCyborgSsl,
      authStorage: InMemoryTokenStore(),
    );
    await client.connect(initialSubscriptions: kCyborgViewSubscriptions);
    await client.reducers.registerAccount(
      email: 'cnt-${DateTime.now().microsecondsSinceEpoch}@cyborg.test',
      password: 'hunter2!!',
    );
    await _until(() => client.myAccount != null);
    await client.reducers.createCharacter(name: name, kind: 'male_cyborg');
    await _until(() => client.myCharacters.count() == 1);
    await client.subscriptions.subscribe(worldSubscriptionsFor(x, y));
    await client.reducers.enterWorld(gridX: x, gridY: y);
    await _until(() => client.myWorldPlayer != null);
    await _until(() => client.monster.count() > 0,
        timeout: const Duration(seconds: 15));
    return client;
  }

  /// 서 있는 자리에서 단계별로 몇 기가 남는지 센다.
  ({int subscribed, int inRadius, int onScreen}) countAround(
    SpacetimeDbClient client,
    double x,
    double y,
  ) {
    var subscribed = 0;
    var inRadius = 0;
    var onScreen = 0;
    for (final m in client.monster.iter()) {
      if (!m.alive) continue;
      subscribed++;
      final d = math.sqrt(
        (m.gridX - x) * (m.gridX - x) + (m.gridY - y) * (m.gridY - y),
      );
      if (d <= renderRadius) inRadius++;
      if (d <= screenHalfWidth) onScreen++;
    }
    return (subscribed: subscribed, inRadius: inRadius, onScreen: onScreen);
  }

  test(
    '사냥터에 서면 화면에 몹이 보인다',
    timeout: const Timeout(Duration(minutes: 3)),
    () async {
      // 안전지대 한복판 — 여기는 몹이 없는 것이 정상이다.
      const safeX = 503.0;
      const safeY = 503.0;
      final atSafe = await joinAt(safeX, safeY, '안전지대');
      final safe = countAround(atSafe, safeX, safeY);
      // ignore: avoid_print
      print('안전지대 중심 — 구독 ${safe.subscribed} 기 · '
          '반경 $renderRadius 안 ${safe.inRadius} 기 · '
          '화면 안 ${safe.onScreen} 기');
      await atSafe.disconnect();

      // 사냥터 — 안전지대를 벗어난 자리. 여기서는 보여야 한다.
      //
      // 입장 좌표가 안전지대 밖이면 서버가 중심으로 되돌리므로, 구독만 사냥터
      // 기준으로 걸고 몹을 센다. 실제로 걸어 나갔을 때 무엇이 보일지와 같다.
      const huntX = 503.0;
      const huntY = 460.0;
      final atHunt = await joinAt(huntX, huntY, '사냥터');
      final hunt = countAround(atHunt, huntX, huntY);
      // ignore: avoid_print
      print('사냥터(중심에서 43 타일) — 구독 ${hunt.subscribed} 기 · '
          '반경 $renderRadius 안 ${hunt.inRadius} 기 · '
          '화면 안 ${hunt.onScreen} 기');
      await atHunt.disconnect();

      expect(
        hunt.subscribed,
        greaterThan(0),
        reason: '사냥터인데 구독으로 오는 몹이 없다 — 구독 범위나 스폰 문제',
      );
      expect(
        hunt.onScreen,
        greaterThan(0),
        reason: '사냥터에 서 있는데 화면 안에 몹이 한 기도 없다',
      );
    },
  );
}

Future<void> _until(
  bool Function() c, {
  Duration timeout = const Duration(seconds: 25),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!c()) {
    if (DateTime.now().isAfter(deadline)) fail('시간 초과');
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}
