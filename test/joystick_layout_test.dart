import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart' show EdgeInsets, Offset, Size;
import 'package:flutter_test/flutter_test.dart';

import 'package:actionrpg/game/ui/touch_controls.dart';

/// 조이스틱은 배경 원·손잡이·드래그 영역이 한자리에 겹쳐야 쓸 수 있다.
///
/// 셋이 어긋나도 예외 하나 나지 않고 화면만 조용히 망가지므로, 눈으로 볼 수
/// 없는 이곳에서 자리를 직접 재 둔다. 실제 게임(`ActionRpgGame._addTouchControls`)
/// 이 쓰는 것과 같은 치수로 조립한다.
void main() {
  const backgroundRadius = 62.0;
  const knobRadius = 26.0;
  const margin = 40.0;
  const screen = Size(800, 600);

  /// 조이스틱의 화면상 중심. 여백과 배경 반경에서 나온다.
  const center = Offset(margin + backgroundRadius, 600 - margin - backgroundRadius);

  JoystickComponent buildJoystick() => JoystickComponent(
        knob: JoystickKnob(radius: knobRadius),
        background: JoystickBase(radius: backgroundRadius),
        knobRadius: backgroundRadius - knobRadius,
        margin: const EdgeInsets.only(left: margin, bottom: margin),
      );

  /// 게임을 실제 위젯으로 띄워 컴포넌트 생명주기를 끝까지 돌린다.
  Future<JoystickComponent> pumpJoystick(WidgetTester tester) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final joystick = buildJoystick();
    final game = FlameGame();
    // 게임 루프를 도는 것은 `tester.pump` 뿐이다. 여기서 `add` 를 await 하면
    // 아직 돌지 않은 루프를 기다리며 그대로 멈춘다.
    game.camera.viewport.add(joystick);

    await tester.pumpWidget(GameWidget(game: game));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(joystick.isMounted, isTrue, reason: '조이스틱이 붙지 않았다');
    return joystick;
  }

  group('조이스틱 배치', () {
    testWidgets('배경 원이 드래그 영역을 정확히 덮는다', (tester) async {
      // 배경에 Anchor.center 를 주면 원이 조이스틱 사각형의 좌상단 모서리를
      // 중심으로 그려진다. 화면 왼쪽으로 반이 잘려 나가고 손잡이와 드래그
      // 영역만 제자리에 남아, 조이스틱이 고장 난 것처럼 보인다.
      final joystick = await pumpJoystick(tester);
      final background = joystick.background!;

      expect(background.isMounted, isTrue);
      expect(background.anchor, Anchor.topLeft);
      expect(background.position, Vector2.zero());
      expect(background.size, joystick.size);
    });

    testWidgets('조이스틱 사각형이 좌하단 여백대로 놓인다', (tester) async {
      // 탭 차폐막(`ActionRpgGame._joystickCenter`)이 이 자리를 그대로 베껴
      // 쓴다. 어긋나면 가장자리를 짚은 탭이 월드로 새어 캐릭터가 걸어간다.
      final joystick = await pumpJoystick(tester);

      expect(joystick.anchor, Anchor.center);
      expect(joystick.position, Vector2(center.dx, center.dy));
      expect(joystick.size, Vector2.all(backgroundRadius * 2));
    });

    testWidgets('손잡이는 배경 한가운데에서 쉰다', (tester) async {
      final joystick = await pumpJoystick(tester);

      expect(joystick.knob!.anchor, Anchor.center);
      expect(joystick.knob!.position, joystick.size / 2);
    });

    testWidgets('끝까지 밀어도 손잡이가 배경 밖으로 나가지 않는다', (tester) async {
      final joystick = await pumpJoystick(tester);

      // 배경 반경보다 한참 멀리 끌어 본다.
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(300, 0));
      await tester.pump(const Duration(milliseconds: 16));

      final rest = joystick.size / 2;
      final pushed = (joystick.knob!.position - rest).length;
      expect(pushed, greaterThan(0), reason: '조이스틱이 드래그를 받지 못했다');
      expect(
        pushed + knobRadius,
        lessThanOrEqualTo(backgroundRadius + 0.001),
        reason: '손잡이가 배경 링 밖으로 나갔다',
      );
      expect(joystick.intensity, closeTo(1, 0.001));

      await gesture.up();
    });
  });
}
