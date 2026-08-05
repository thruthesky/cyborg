import 'dart:io';
import 'dart:ui' as ui;

import 'package:actionrpg/game/iso.dart';
import 'package:actionrpg/game/level/world_tree.dart';
import 'package:actionrpg/game/palette.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 월드 중앙의 이정표 나무를 PNG 로 뽑아 눈으로 검수한다.
///
/// 이 나무의 쓸모는 "멀리서도 보이는가" 하나뿐이라, 게임 최소 배율에서도
/// 실루엣이 읽히는지가 유일한 합격 조건이다. 최소 배율은 0.55
/// (`ActionRpgGame._zoomForSize`)다.
///
/// ```sh
/// CYBORG_SNAPSHOT_DIR=/tmp/shots flutter test test/world_tree_render_test.dart
/// ```
/// 환경변수가 없으면 파일을 남기지 않고 렌더링이 예외 없이 끝나는지만 본다.
void main() {
  final outputDir = Platform.environment['CYBORG_SNAPSHOT_DIR'];

  // 렌더 원점(나무 발밑)이 놓이는 캔버스 좌표. [_renderTree]와 같은 값이다.
  const originX = 640 / 2;
  const originY = 620 * 0.82;

  testWidgets('나무가 예외 없이 렌더링된다', (tester) async {
    // Picture.toImage()는 실제 비동기 이벤트 루프를 필요로 하므로
    // 테스트의 FakeAsync 밖(runAsync)에서 실행해야 데드락에 걸리지 않는다.
    await tester.runAsync(() async {
      final full = await _renderTree(scale: 1.0);
      expect(full.width, 640);
      await _save(full, outputDir, 'world_tree.png');

      // 게임 최소 배율. 이 크기에서 이정표로 읽히는지 본다.
      final tiny = await _renderTree(scale: 0.55);
      await _save(tiny, outputDir, 'world_tree_min_zoom.png');
    });
  });

  testWidgets('나무는 발밑에서 위로 자라고 타일 한 칸보다 넓게 퍼진다', (tester) async {
    await tester.runAsync(() async {
      // 지면 격자를 빼고 나무가 칠한 화소만 잰다.
      final image = await _renderTree(scale: 1.0, ground: false);
      final ink = await _inkBounds(image);

      // 위로 자라야 한다. 발밑에서 최소 4 단위 높이만큼은 솟아야 멀리서 보인다.
      expect(ink.top, lessThan(originY - kHeightUnit * 4));

      // 아래로는 그림자와 뿌리만 있어야 한다. 지면 밑으로 파고들면 안 된다.
      expect(ink.bottom, lessThan(originY + kHeightUnit));

      // 수관이 타일 한 칸보다 넓어야 지면 격자에 파묻히지 않는다.
      expect(ink.width, greaterThan(kTileWidth));

      // 줄기가 원점 위에 서야 이정표가 월드 중앙을 가리킨다.
      expect(ink.center.dx, closeTo(originX, 24));
    });
  });

  test('그리드 좌표를 그대로 들고 있다', () {
    // 이정표가 제자리에 서려면 넘겨준 좌표가 변형되지 않아야 한다.
    final tree = WorldTree(grid: Vector2(503, 503));
    expect(tree.grid, Vector2(503, 503));
  });
}

/// 배경색과 다른 화소가 차지하는 사각형을 잰다.
///
/// 실제로 잉크가 닿은 범위라, 도형 계산이 아니라 눈에 보이는 결과를 재는 것이다.
Future<Rect> _inkBounds(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = data!.buffer.asUint8List();

  const bg = GamePalette.floorBase;
  var minX = image.width, minY = image.height, maxX = -1, maxY = -1;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final i = (y * image.width + x) * 4;
      // 안티에일리어싱 가장자리를 잉크로 세지 않도록 여유를 둔다.
      final diff = (bytes[i] - ((bg.r * 255).round())).abs() +
          (bytes[i + 1] - ((bg.g * 255).round())).abs() +
          (bytes[i + 2] - ((bg.b * 255).round())).abs();
      if (diff <= 6) continue;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }

  expect(maxX, greaterThanOrEqualTo(0), reason: '나무가 아무것도 그리지 않았다');
  return Rect.fromLTRB(
    minX.toDouble(),
    minY.toDouble(),
    maxX.toDouble(),
    maxY.toDouble(),
  );
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

/// 지면 격자 위에 선 나무를 그린다. 실제 화면과 같은 조건에서 봐야
/// 배경에 묻히는지 알 수 있다.
Future<ui.Image> _renderTree({required double scale, bool ground = true}) async {
  const width = 640.0;
  const height = 620.0;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

  canvas.drawRect(
    const Rect.fromLTWH(0, 0, width, height),
    Paint()..color = GamePalette.floorBase,
  );

  final tree = WorldTree(grid: Vector2(0, 0));
  await tree.onLoad();

  canvas.save();
  // 발밑을 화면 아래쪽에 두고 위로 자라게 한다.
  canvas.translate(width / 2, height * 0.82);
  canvas.scale(scale);

  if (ground) _drawGround(canvas);
  tree.render(canvas);

  canvas.restore();

  final picture = recorder.endRecording();
  return picture.toImage(width.toInt(), height.toInt());
}

/// 나무 발밑의 아이소메트릭 지면 격자. 배경과의 대비를 보기 위한 것이다.
void _drawGround(Canvas canvas) {
  final grid = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = GamePalette.floorGrid.withValues(alpha: 0.6);
  for (var i = -3; i <= 3; i++) {
    final a = gridToScreen(i.toDouble(), -3);
    final b = gridToScreen(i.toDouble(), 3);
    final c = gridToScreen(-3, i.toDouble());
    final d = gridToScreen(3, i.toDouble());
    canvas.drawLine(a.toOffset(), b.toOffset(), grid);
    canvas.drawLine(c.toOffset(), d.toOffset(), grid);
  }
}
