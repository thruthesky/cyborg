import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:actionrpg/game/audio/game_audio.dart';
import 'package:actionrpg/game/palette.dart';
import 'package:actionrpg/game/ui/settings_screen.dart';

/// 소리 설정 패널을 PNG 로 뽑아 눈으로 검수한다.
///
/// 패널은 캔버스에 직접 그리는 컴포넌트라 위젯 트리로는 확인할 수 없다. 화면
/// 크기·볼륨·음소거를 바꿔 가며 실제로 그려 보는 것이 유일한 검수 방법이다.
/// 여기서 잡는 것은 "예외 없이 그려진다" 와 "손잡이가 값과 같은 자리에 있다" 다.
///
/// ```sh
/// CYBORG_SNAPSHOT_DIR=/tmp/shots flutter test test/settings_render_test.dart
/// ```
/// 환경변수가 없으면 파일을 남기지 않고 렌더링만 확인한다.
void main() {
  final outputDir = Platform.environment['CYBORG_SNAPSHOT_DIR'];

  testWidgets('소리 설정 패널이 예외 없이 그려진다', (tester) async {
    // Picture.toImage()는 실제 비동기 이벤트 루프를 필요로 하므로
    // 테스트의 FakeAsync 밖(runAsync)에서 실행해야 데드락에 걸리지 않는다.
    await tester.runAsync(() async {
      final sheet = await _renderStates();
      expect(sheet.width, greaterThan(0));
      await _save(sheet, outputDir, 'settings_screen.png');

      // 패널보다 좁은 창. 통째로 축소돼 들어가야 한다.
      final narrow = await _renderStates(screen: Vector2(320, 260));
      await _save(narrow, outputDir, 'settings_screen_narrow.png');
    });
  });

  test('열기 전에는 아무 입력도 받지 않는다', () {
    // 닫힌 패널이 히트 영역을 잡고 있으면 화면 전체가 먹통이 된다.
    final screen = SettingsScreen()..size = Vector2(900, 600);
    expect(screen.containsLocalPoint(Vector2(450, 300)), isFalse);

    screen.open();
    expect(screen.containsLocalPoint(Vector2(450, 300)), isTrue);

    screen.close();
    expect(screen.containsLocalPoint(Vector2(450, 300)), isFalse);
  });
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

/// 볼륨·음소거 조합을 세로로 이어 붙인 한 장.
Future<ui.Image> _renderStates({Vector2? screen}) async {
  final canvasSize = screen ?? Vector2(760, 420);
  const states = [
    (label: '기본값', sfx: 0.85, music: 0.5, muted: false),
    (label: '배경음 0 · 효과음 최대', sfx: 1.0, music: 0.0, muted: false),
    (label: '음소거', sfx: 0.4, music: 0.6, muted: true),
  ];

  final width = canvasSize.x;
  final height = canvasSize.y * states.length;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

  canvas.drawRect(
    Rect.fromLTWH(0, 0, width, height),
    Paint()..color = GamePalette.skyLow,
  );

  for (var i = 0; i < states.length; i++) {
    final state = states[i];
    GameAudio.setSfxVolume(state.sfx);
    await GameAudio.setMusicVolume(state.music);
    GameAudio.muted = state.muted;

    final panel = SettingsScreen()..size = canvasSize.clone();
    panel.open();
    // 열림 연출이 끝난 상태를 본다. 한 번에 큰 dt 를 주면 목표값에 붙는다.
    for (var step = 0; step < 20; step++) {
      panel.update(1 / 60);
    }

    canvas.save();
    canvas.translate(0, canvasSize.y * i);
    canvas.clipRect(Rect.fromLTWH(0, 0, canvasSize.x, canvasSize.y));
    panel.render(canvas);
    _label(canvas, state.label, const Offset(10, 10));
    canvas.restore();
  }

  // 시험 사이에 정적 상태가 새 나가지 않도록 되돌린다.
  GameAudio.muted = false;

  final picture = recorder.endRecording();
  return picture.toImage(width.round(), height.round());
}

void _label(Canvas canvas, String text, Offset at) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        color: GamePalette.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, at);
}
