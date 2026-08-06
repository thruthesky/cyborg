import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:actionrpg/game/art/cyborg_artist.dart';
import 'package:actionrpg/game/entities/cyborg_design.dart';
import 'package:actionrpg/game/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provis/provis.dart' show kGround, kStage;

/// 손그림 액터([CyborgArtist])를 시트로 뽑아 눈으로 검수한다.
///
/// 절차 렌더는 컴파일된다고 해서 보이는 것이 아니다. 값이 조금만 어긋나도
/// 파츠가 몸 밖으로 튀어나가거나 화면 밖으로 사라지는데, 그 어느 것도 예외를
/// 던지지 않는다. **눈으로 보는 것이 유일한 검증**이다.
///
/// ```sh
/// CYBORG_SNAPSHOT_DIR=/tmp/shots flutter test test/cyborg_artist_sheet_test.dart
/// ```
void main() {
  final outputDir = Platform.environment['CYBORG_SNAPSHOT_DIR'];

  testWidgets('두 프레임의 8방향이 예외 없이 그려진다', (tester) async {
    await tester.runAsync(() async {
      final sheet = await _rotationSheet(steps: 8);
      expect(sheet.width, greaterThan(0));
      await _save(sheet, outputDir, 'artist_rotation.png');
    });
  });

  testWidgets('게임 크기(108px)로 줄여도 실루엣이 남는다', (tester) async {
    await tester.runAsync(() async {
      // 게임 안에서 이 몸은 108px 이고, 기본 배율에서 59px 까지 준다.
      // 그 크기에서 무너지면 플레이 중에는 없는 디테일이다.
      final tiny = await _rotationSheet(steps: 8, targetHeight: 59);
      await _save(tiny, outputDir, 'artist_ingame_size.png');
    });
  });

  testWidgets('게임에 세운 몸이 요구한 키와 맞는다', (tester) async {
    // 눈으로 보면 "좀 작아 보인다" 에서 멈추지만, 픽셀을 세면 어긋난 정도가
    // 수치로 나온다. 골격 기준 길이와 실제 실루엣 높이가 다르다는 사실을
    // 놓치면 캐릭터가 의도보다 10% 작게 서고, 그 차이는 기물과 나란히 놓고
    // 봐야 겨우 눈치챈다.
    await tester.runAsync(() async {
      const want = 108.0;
      final box = await _drawnBounds(want);

      // 발밑 원점에서 정수리까지가 요구한 키와 맞아야 한다.
      //
      // 아래쪽은 재지 않는다 — 접지 그림자는 지면에 **눕는** 것이라 발밑보다
      // 아래로 퍼지는 것이 정상이고, 그것을 몸으로 세면 키가 부풀려진다.
      expect(-box.top, closeTo(want, want * 0.09),
          reason: '요구한 키 $want 와 실제 실루엣 높이가 다르다');
      // 좌우도 사람 비율을 벗어나지 않아야 한다. 어깨가 키를 넘으면 파츠가
      // 몸 밖으로 튀어나간 것이다.
      expect(box.width, lessThan(want * 0.9),
          reason: '실루엣이 가로로 벌어졌다');
    });
  });

  test('초상과 게임 액터를 잇는 build 가 비어 있지 않다', () {
    // 이것이 비면 명부에서 고른 인물과 맵에서 걷는 인물이 갈린다.
    for (final design in [CyborgDesign.assault, CyborgDesign.infiltrator]) {
      final artist = CyborgArtist(design);
      expect(artist.build.palette, isNotNull);
      expect(artist.build.headGear, isNotNull);
      // 게임이 스윙을 따로 연출하므로 무기를 들면 칼이 두 자루가 된다.
      expect(artist.build.weapon, isNotNull);
      expect(artist.accent, design.accent);
    }
  });
}

/// 두 프레임 × [steps] 방향 시트.
Future<ui.Image> _rotationSheet({
  required int steps,
  double targetHeight = 320,
}) async {
  final designs = [CyborgDesign.assault, CyborgDesign.infiltrator];
  final scale = targetHeight / kStage.height;
  final cellW = kStage.width * scale;
  final cellH = kStage.height * scale;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, cellW * steps, cellH * designs.length),
    Paint()..color = GamePalette.skyLow,
  );

  for (var row = 0; row < designs.length; row++) {
    final artist = CyborgArtist(designs[row]);
    for (var i = 0; i < steps; i++) {
      artist.yaw = i * 2 * math.pi / steps;
      // 걷는 중간 자세로 뽑는다. 정지 자세만 보면 다리가 교차하는지 알 수 없다.
      artist.swing = math.sin(i * 0.9);
      artist.armSwing = -math.sin(i * 0.9) * 0.7;

      canvas.save();
      canvas.translate(cellW * i, cellH * row);
      canvas.scale(scale);
      // 무대 원점은 가운데 아래다.
      canvas.translate(kStage.width / 2, 0);
      artist.paint(canvas, i * 0.31);
      canvas.restore();
    }
  }

  return recorder.endRecording().toImage(
        (cellW * steps).ceil(),
        (cellH * designs.length).ceil(),
      );
}

/// 게임 좌표계([paintCyborgAtFeet])로 세운 몸이 실제로 차지하는 범위.
///
/// 발밑이 원점이므로 y 는 음수 쪽으로 올라간다. 반환 사각형은 **원점 기준**이다.
Future<Rect> _drawnBounds(double height) async {
  // 몸이 원점 위로 올라가므로 캔버스를 아래로 밀어 두고 그린다.
  const pad = 40.0;
  final w = (height * 2 + pad * 2).ceil();
  final h = (height + pad * 2).ceil();
  final originY = h - pad;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.translate(w / 2, originY);
  paintCyborgAtFeet(
    canvas,
    CyborgArtist(CyborgDesign.assault),
    height: height,
    time: 0,
  );
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) return Rect.zero;

  final bytes = data.buffer.asUint8List();
  var top = h, bottom = -1, left = w, right = -1;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      // 접지 그림자는 옅게 깔리므로 문턱을 두어 몸만 잡는다.
      if (bytes[(y * w + x) * 4 + 3] < 90) continue;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
      if (x < left) left = x;
      if (x > right) right = x;
    }
  }
  if (bottom < 0) return Rect.zero;
  return Rect.fromLTRB(
    left - w / 2,
    top - originY,
    right - w / 2,
    bottom - originY,
  );
}

Future<void> _save(ui.Image image, String? dir, String name) async {
  if (dir == null) return;
  Directory(dir).createSync(recursive: true);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  if (data == null) return;
  File('$dir/$name').writeAsBytesSync(data.buffer.asUint8List());
  // ignore: avoid_print
  print('시트 저장: $dir/$name');
}
