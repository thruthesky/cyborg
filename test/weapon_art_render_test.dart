import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:actionrpg/game/entities/weapon_art.dart';
import 'package:actionrpg/game/palette.dart';
import 'package:actionrpg/game/systems/weapon.dart';

/// 일곱 계통의 그림을 실제로 그려 본다.
///
/// 무기 그림은 전부 [Canvas] 명령이라 위젯 트리에도 스냅샷 비교에도 걸리지
/// 않는다. 그래서 여기서 잡는 것은 눈이 아니라 **예외**다 — 반지름이 음수인
/// 원, 시그마가 0 이하인 블러, 길이가 0인 경로처럼 특정 진행도에서만 터지는
/// 값들은 화면에 띄워 보기 전에는 드러나지 않는다. 계통이 넷에서 일곱으로
/// 늘면서 그런 자리가 세 배로 늘었다.
///
/// PNG 로 눈으로 검수하려면:
/// ```sh
/// CYBORG_SNAPSHOT_DIR=/tmp/shots flutter test test/weapon_art_render_test.dart
/// ```
/// 환경변수가 없으면 파일을 남기지 않고 렌더링만 확인한다.
void main() {
  final outputDir = Platform.environment['CYBORG_SNAPSHOT_DIR'];

  /// 계통마다 반드시 그려 봐야 하는 무기 한 자루씩.
  ///
  /// 등급을 낮은 쪽·높은 쪽 둘 다 고른다. 날의 수·눈금 간격·슬릿 개수가 모두
  /// 등급에서 나오므로, 한 등급만 보면 `gradeIndex ~/ 3` 같은 자리가 0일 때만
  /// 확인한 것이 된다.
  final samples = <({String name, Weapon weapon})>[
    for (final level in [1, 12, 340])
      for (final weaponClass in WeaponClass.values)
        (
          name: '${weaponClass.name}_lv$level',
          weapon: _weaponOf(weaponClass, level),
        ),
  ];

  test('모든 계통이 스윙 전 구간에서 예외 없이 그려진다', () {
    // 진행도를 촘촘히 훑는다. 계통마다 마디가 나뉘는 지점이 다르고
    // (드라이버는 0.45·0.72, 해머는 0.35·0.70) 그 경계에서 값이 뒤집히므로,
    // 몇 개만 찍어 보면 하필 안전한 자리만 밟는다.
    for (final sample in samples) {
      final length = sample.weapon.weaponClass.comboLength;
      for (var comboStep = 0; comboStep < length; comboStep++) {
        final finisher = comboStep == length - 1;
        for (var i = 0; i <= 40; i++) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 200, 200));
          expect(
            () => WeaponArt.drawSwing(
              canvas,
              weapon: sample.weapon,
              progress: i / 40,
              baseAngle: 0.7,
              comboStep: comboStep,
              finisher: finisher,
            ),
            returnsNormally,
            reason: '${sample.name} 이 진행도 ${i / 40} 에서 터진다',
          );
          recorder.endRecording().dispose();
        }
      }
    }
  });

  test('등에 멘 모습과 바닥 아이콘이 예외 없이 그려진다', () {
    for (final sample in samples) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 200, 200));
      // 노출도 0(몸에 완전히 가림)과 1(정면) 양끝을 다 밟는다.
      for (final reveal in [0.0, 0.5, 1.0]) {
        expect(
          () => WeaponArt.drawHolstered(
            canvas,
            sample.weapon,
            at: const Offset(100, 100),
            span: 46,
            reveal: reveal,
          ),
          returnsNormally,
          reason: '${sample.name} 을 등에 멘 모습이 터진다',
        );
      }
      expect(
        () => WeaponArt.drawPickup(
          canvas,
          sample.weapon.weaponClass,
          sample.weapon.glow,
        ),
        returnsNormally,
        reason: '${sample.name} 의 바닥 아이콘이 터진다',
      );
      recorder.endRecording().dispose();
    }
  });

  testWidgets('일곱 계통을 한 장으로 뽑아 눈으로 검수한다', (tester) async {
    // Picture.toImage()는 실제 비동기 이벤트 루프를 필요로 하므로
    // 테스트의 FakeAsync 밖(runAsync)에서 실행해야 데드락에 걸리지 않는다.
    await tester.runAsync(() async {
      final swings = await _renderSwings();
      expect(swings.width, greaterThan(0));
      await _save(swings, outputDir, 'weapon_swings.png');

      final kit = await _renderHolsteredAndPickups();
      await _save(kit, outputDir, 'weapon_kit.png');
    });
  });
}

/// [weaponClass] 계통의 [level] 짜리 무기 한 자루를 굴려 낸다.
///
/// 생성자가 비공개라 굴림 말고는 무기를 만들 길이 없다. 그것이 의도된
/// 제약이다 — 무기는 레벨에서 유도되거나 잔해에서 나오는 둘 중 하나여야 하고,
/// 테스트라고 세 번째 길을 뚫으면 그 제약이 코드에서만 지켜지는 규칙이 된다.
Weapon _weaponOf(WeaponClass weaponClass, int level) {
  if (WeaponSystem.classForLevel(level) == weaponClass) {
    return WeaponSystem.forLevel(level);
  }
  for (var seed = 0; seed < 40000; seed++) {
    final rolled = WeaponSystem.rollDrop(math.Random(seed), monsterLevel: level);
    if (rolled.weaponClass == weaponClass && rolled.level == level) {
      return rolled;
    }
  }
  throw StateError('$weaponClass Lv.$level 을 굴려 내지 못했다');
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

/// 계통을 세로로, 스윙의 진행도를 가로로 늘어놓은 한 장.
///
/// 한 계통의 한 타가 한 줄이라 **궤적이 서로 다른지**를 줄끼리 견줘 볼 수
/// 있다. 이 파일이 지키려는 설계가 그것이다 — 계통이 다르면 그림도 통째로
/// 달라야 하고, 두 줄이 비슷해 보이면 그 둘은 색만 다른 같은 무기다.
Future<ui.Image> _renderSwings() async {
  const cell = 150.0;
  const steps = 6;
  final classes = WeaponClass.values;

  final width = cell * steps + 110;
  final height = cell * classes.length;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width, height),
    Paint()..color = GamePalette.skyLow,
  );

  for (var row = 0; row < classes.length; row++) {
    final weaponClass = classes[row];
    // 340 레벨은 등급이 높아 날이 갈라지고 무늬가 촘촘한 구간이다.
    final weapon = _weaponOf(weaponClass, 340);
    final y = cell * row;

    _label(canvas, weaponClass.name.toUpperCase(), Offset(10, y + cell / 2));
    canvas.drawLine(
      Offset(0, y),
      Offset(width, y),
      Paint()..color = GamePalette.textPrimary.withValues(alpha: 0.12),
    );

    for (var i = 0; i < steps; i++) {
      final progress = i / (steps - 1);
      canvas.save();
      canvas.translate(110 + cell * i + cell / 2, y + cell * 0.78);
      WeaponArt.drawSwing(
        canvas,
        weapon: weapon,
        progress: progress,
        // 오른쪽 아래를 향해 휘두른다. 정면(0)으로 두면 아이소메트릭
        // 화면에서 실제로 보게 되는 각도가 아니다.
        baseAngle: 0.5,
        comboStep: weaponClass.comboLength - 1,
        finisher: true,
      );
      canvas.restore();
    }
  }

  final picture = recorder.endRecording();
  return picture.toImage(width.round(), height.round());
}

/// 등에 멘 실루엣과 바닥 아이콘을 계통별로 늘어놓은 한 장.
///
/// 이 둘은 **붙기 전에 상대가 무엇을 들었는지** 를 말하는 그림이라 서로 다른
/// 것보다 서로 헷갈리지 않는 것이 중요하다. 나란히 놓고 보는 이유다.
Future<ui.Image> _renderHolsteredAndPickups() async {
  const cell = 120.0;
  final classes = WeaponClass.values;
  final width = cell * classes.length;
  const height = cell * 2;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 1000, height));
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width, height),
    Paint()..color = GamePalette.skyLow,
  );

  for (var i = 0; i < classes.length; i++) {
    final weapon = _weaponOf(classes[i], 340);
    final x = cell * i;
    _label(canvas, classes[i].name.toUpperCase(), Offset(x + 8, 6));

    canvas.save();
    canvas.translate(x + cell / 2, cell * 0.62);
    WeaponArt.drawHolstered(
      canvas,
      weapon,
      at: Offset.zero,
      span: 52,
      reveal: 1,
    );
    canvas.restore();

    canvas.save();
    canvas.translate(x + cell / 2, cell * 1.5);
    WeaponArt.drawPickup(canvas, weapon.weaponClass, weapon.glow);
    canvas.restore();
  }

  final picture = recorder.endRecording();
  return picture.toImage(width.round(), height.round());
}

void _label(Canvas canvas, String text, Offset at) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        color: GamePalette.textPrimary,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, at);
}
