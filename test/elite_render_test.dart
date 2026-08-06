import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:actionrpg/game/action_rpg_game.dart';
import 'package:actionrpg/game/entities/enemy.dart';
import 'package:actionrpg/game/palette.dart';
import 'package:actionrpg/game/systems/elite.dart';
import 'package:actionrpg/game/systems/monster_codex.dart';

/// 정예가 **한눈에 다르게 보이는지**를 눈으로 검수한다.
///
/// 정예의 값어치는 수치에 있지만, 그 수치를 만나기 전에 플레이어가 먼저 하는
/// 일은 "저건 다르다" 를 알아보는 것이다. 발밑 고리와 이름표가 그 몫이라,
/// 그림으로 확인하지 않으면 지켜지는지 알 수 없다.
///
/// ```sh
/// CYBORG_SNAPSHOT_DIR=/tmp/shots flutter test test/elite_render_test.dart
/// ```
void main() {
  final outputDir = Platform.environment['CYBORG_SNAPSHOT_DIR'];

  testWidgets('정예는 평범한 개체와 다르게 보인다', (tester) async {
    await tester.runAsync(() async {
      final game = ActionRpgGame(autoStart: true);
      game.onGameResize(Vector2(900, 460));
      await game.onLoad();
      await game.ready();

      // 계통마다 실루엣이 달라 고리가 어디에 깔리는지도 달라진다. 보행형과
      // 포격형을 함께 세워 둘 다 확인한다.
      const cases = [
        (level: 24, elite: null),
        (level: 24, elite: EliteTrait.fortified),
        (level: 24, elite: EliteTrait.overclocked),
        (level: 24, elite: EliteTrait.warden),
        (level: 47, elite: null),
        (level: 47, elite: EliteTrait.fortified),
      ];

      final enemies = <Enemy>[];
      for (var i = 0; i < cases.length; i++) {
        final spec = cases[i];
        final enemy = Enemy(
          species: MonsterCodex.byLevel(spec.level),
          // 플레이어 곁에 세워야 이름표가 뜬다.
          grid: game.player.grid + Vector2(i * 0.6, 0),
          elite: spec.elite,
        );
        enemies.add(enemy);
        game.world.add(enemy);
      }
      await game.ready();
      // 맥동하는 고리를 한가운데 위상에서 찍기 위해 몇 프레임만 돌린다. 월드
      // 전체가 아니라 이 개체들만 돌리는 이유는 `enemy_ai_test.dart` 와 같다.
      for (var i = 0; i < 12; i++) {
        for (final enemy in enemies) {
          enemy.update(1 / 60);
        }
      }

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 900, 460));
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 900, 460),
        Paint()..color = GamePalette.floorBase,
      );

      for (var i = 0; i < enemies.length; i++) {
        final column = i % 3;
        final row = i ~/ 3;
        canvas.save();
        canvas.translate(160 + column * 280, 190 + row * 210);
        enemies[i].render(canvas);
        canvas.restore();
      }

      final image = await recorder.endRecording().toImage(900, 460);
      expect(image.width, 900);

      // 정예는 이름표를 언제나 달고 있어야 멀리서도 가려낼 수 있다.
      expect(enemies[1].isElite, isTrue);
      expect(enemies[0].isElite, isFalse);

      if (outputDir != null) {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$outputDir/elites.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        // ignore: avoid_print
        print('스냅샷 저장: ${file.path}');
      }
    });
  });
}
