import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:actionrpg/game/action_rpg_game.dart';
import 'package:actionrpg/game/level/level_map.dart';
import 'package:actionrpg/game/systems/monster_codex.dart';
import 'package:actionrpg/game/ui/hud.dart';
import 'package:actionrpg/game/ui/world_map_screen.dart';

/// 월드 지도가 **사실**을 말하는지 지킨다.
///
/// 지도는 틀려도 그럴듯해 보인다 — 축이 뒤집히거나 위험 등급 고리가 실제 주둔
/// 병력과 어긋나도 화면은 멀쩡하다. 그래서 눈으로 볼 수 없는 두 가지를 여기서
/// 붙잡는다.
///
/// 1. **자리** — 월드 좌표와 지도 위 자리의 환산이 왕복해서 제자리로 돌아온다.
/// 2. **위험 등급** — 고리의 반지름이 [MonsterCodex.regionLevel] 의 역함수다.
///    이 둘이 어긋나면 "레벨 25 고리 안쪽" 이라고 믿고 들어간 곳에 레벨 60이 선다.
void main() {
  final outputDir = Platform.environment['CYBORG_SNAPSHOT_DIR'];

  group('위험 등급 고리', () {
    const halfSpan = 503.0;

    test('고리 반지름은 그 등급이 실제로 시작되는 거리다', () {
      // 역함수가 곡선과 어긋나면 지도가 거짓말을 한다.
      for (final level in [2, 10, 25, 50, 100, 150, 200]) {
        final distance = MonsterCodex.regionDistanceFor(level, halfSpan);
        expect(
          MonsterCodex.regionLevel(distance, halfSpan),
          level,
          reason: 'Lv.$level 고리가 $distance 타일에 그려졌다',
        );
      }
    });

    test('등급이 높을수록 고리가 바깥에 놓인다', () {
      var previous = -1.0;
      for (final level in [1, 10, 25, 50, 100, 200]) {
        final distance = MonsterCodex.regionDistanceFor(level, halfSpan);
        expect(distance, greaterThan(previous));
        previous = distance;
      }
    });

    test('가장 낮은 등급은 중심, 가장 높은 등급은 월드 끝이다', () {
      expect(MonsterCodex.regionDistanceFor(1, halfSpan), 0);
      expect(
        MonsterCodex.regionDistanceFor(MonsterCodex.maxLevel, halfSpan),
        closeTo(halfSpan, 1e-9),
      );
    });

    test('지도에 그리는 다섯 고리가 모두 월드 안에 들어온다', () {
      // 고리가 지도 밖으로 나가면 그 등급대는 화면에서 사라진다.
      for (final band in WorldMapScreen.dangerBands) {
        final distance = MonsterCodex.regionDistanceFor(band.level, halfSpan);
        expect(distance, lessThanOrEqualTo(halfSpan));
        expect(distance, greaterThan(0));
      }
    });
  });

  group('좌표 환산', () {
    final view = WorldMapProjection.fit(
      area: WorldMapScreen.mapArea,
      worldWidth: 1006,
      worldHeight: 1006,
    );

    test('월드의 네 귀퉁이가 지도의 네 귀퉁이가 된다', () {
      expect(view.toMap(Vector2.zero()), view.mapRect.topLeft);
      expect(view.toMap(Vector2(1006, 1006)), view.mapRect.bottomRight);
    });

    test('월드 한가운데가 지도 한가운데에 온다', () {
      final center = view.toMap(Vector2(503, 503));
      expect(center.dx, closeTo(view.mapRect.center.dx, 1e-9));
      expect(center.dy, closeTo(view.mapRect.center.dy, 1e-9));
    });

    test('가로세로 비율을 지켜 앉는다', () {
      // 축마다 배율이 다르면 위험 등급 고리는 원인데 지형은 눌린 타원이 된다.
      // 그러면 "고리 안쪽" 이라는 판단이 방향에 따라 달라진다.
      final squished = WorldMapProjection.fit(
        area: const Rect.fromLTWH(0, 0, 400, 200),
        worldWidth: 1006,
        worldHeight: 1006,
      );
      expect(squished.mapRect.width, closeTo(squished.mapRect.height, 1e-9));
      // 남는 여백은 좌우로 균등하게 나뉘어 지도가 가운데 온다.
      expect(squished.mapRect.center.dx, closeTo(200, 1e-9));
      expect(
        squished.mapRect.width / squished.worldWidth,
        closeTo(squished.mapRect.height / squished.worldHeight, 1e-9),
      );
    });

    test('지도를 눌러 되돌린 좌표가 제자리로 온다', () {
      // 지도를 눌러 위험도를 재는 기능이 이 왕복 위에 서 있다.
      for (final grid in [
        Vector2(12, 990),
        Vector2(503, 128),
        Vector2(880, 640),
      ]) {
        final back = view.toGrid(view.toMap(grid));
        expect(back.x, closeTo(grid.x, 1e-6));
        expect(back.y, closeTo(grid.y, 1e-6));
      }
    });

    test('축을 뒤집지 않는다 — 동쪽은 오른쪽, 남쪽은 아래다', () {
      final origin = view.toMap(Vector2(100, 100));
      expect(view.toMap(Vector2(200, 100)).dx, greaterThan(origin.dx));
      expect(view.toMap(Vector2(100, 200)).dy, greaterThan(origin.dy));
    });
  });

  group('지도 화면', () {
    test('닫혀 있으면 아무 입력도 받지 않는다', () {
      // 닫힌 패널이 히트 영역을 잡고 있으면 화면 전체가 먹통이 된다.
      final screen = WorldMapScreen()..size = Vector2(900, 700);
      expect(screen.containsLocalPoint(Vector2(450, 300)), isFalse);
    });

    test('안전지대는 시작 지점과 같은 자리에 있다', () {
      // 지도의 초록 사각형이 곧 재가동 지점이라는 약속이다.
      final map = LevelMap.generate();
      expect(map.safeZone.containsPoint(map.spawn), isTrue);
    });
  });

  testWidgets('실제 월드에서 지도와 위험도 표시가 그려진다', (tester) async {
    // 지형 축소판은 실제 이벤트 루프에서 구워지므로 runAsync 안에서 돌린다.
    await tester.runAsync(() async {
      // 시작 메뉴 오버레이는 `GameWidget` 이 등록한다. 여기서는 위젯 트리 없이
      // 월드만 세우므로 곧장 들어가는 경로를 쓴다.
      final game = ActionRpgGame(autoStart: true);
      game.onGameResize(Vector2(900, 700));
      await game.onLoad();
      await game.ready();

      // Flame 의 조이스틱은 위젯 레이아웃을 거쳐야 손잡이 기준점이 정해진다.
      // 위젯 트리 없이 도는 이 시험에서는 그 한 컴포넌트만 빼고 그린다.
      final joysticks =
          game.camera.viewport.children.whereType<JoystickComponent>().toList();
      for (final joystick in joysticks) {
        joystick.removeFromParent();
      }
      for (var i = 0; i < 10; i++) {
        game.update(1 / 60);
      }

      // 게임이 만든 월드를 그대로 읽는 컴포넌트 둘을 붙여 그린다. 실제 지형·
      // 좌표·개체군에서 나온 그림이라, 눈으로 보는 것이 곧 실제 화면이다.
      final hud = Hud()..size = Vector2(900, 700);
      final screen = WorldMapScreen()..size = Vector2(900, 700);
      game.camera.viewport.addAll([hud, screen]);
      await game.ready();

      await _save(await _shoot(hud), outputDir, 'hud_danger.png');

      screen.open();
      expect(screen.containsLocalPoint(Vector2(450, 300)), isTrue);

      // 지형 굽기는 비동기다. 이미지가 도착할 틈을 준다.
      await Future<void>.delayed(const Duration(milliseconds: 120));
      for (var i = 0; i < 40; i++) {
        screen.update(1 / 60);
      }

      final withMap = await _shoot(screen);
      expect(withMap.width, 900);
      await _save(withMap, outputDir, 'world_map.png');

      // 게임 쪽 배선도 함께 확인한다 — 다른 창을 열면 지도는 물러난다. 둘 다
      // 화면을 덮으므로 겹쳐 두면 서로 눌리지 않는다.
      game.openWorldMap();
      expect(game.isWorldMapOpen, isTrue);
      game.openCharacterScreen();
      expect(game.isWorldMapOpen, isFalse);
    });
  });
}

/// 컴포넌트 하나를 화면 크기의 한 장에 담는다.
Future<ui.Image> _shoot(Component component) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 900, 700));
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 900, 700),
    Paint()..color = const Color(0xFFCFEDF8),
  );
  component.render(canvas);
  return recorder.endRecording().toImage(900, 700);
}

Future<void> _save(ui.Image image, String? dir, String name) async {
  if (dir == null) return;
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('$dir/$name');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  // ignore: avoid_print
  print('스냅샷 저장: ${file.path}');
}
