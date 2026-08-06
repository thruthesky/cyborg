import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/action_rpg_game.dart';
import 'game/palette.dart';

/// 비주얼 검수 전용 진입점 — 메뉴 없이 곧장 월드를 연다.
///
/// `offline_main.dart` 는 "월드 진입" 버튼을 눌러야 시작하는데, 사람의
/// 키보드·마우스를 가로채는 방식으로 테스트하지 않는다는 규정 때문에
/// 클릭을 흉내 낼 수 없다. 그래서 `autoStart` 로 곧장 들어가는 진입점을
/// 따로 둔다.
///
/// ```sh
/// flutter run -t lib/shot_main.dart -d macos
/// ```
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShotApp());
}

class ShotApp extends StatelessWidget {
  const ShotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cyborg (검수)',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: GamePalette.skyLow,
        body: GameWidget<ActionRpgGame>(game: ActionRpgGame(autoStart: true)),
      ),
    );
  }
}
