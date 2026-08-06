import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:actionrpg/game/audio/audio_settings.dart';
import 'package:actionrpg/game/audio/game_audio.dart';

/// 볼륨 설정이 기기에 남는 것을 잠근다.
///
/// 이 파일이 지키는 문장은 둘이다.
///
/// 1. **고른 볼륨은 다음 접속에도 남는다.** 소리가 큰 기기에서 한 번 줄여 놓으면
///    그 뒤로는 줄이지 않아도 된다.
/// 2. **볼륨은 0~1 을 벗어나지 않는다.** 벗어난 값이 그대로 재생에 들어가면
///    오디오 백엔드가 예외를 던지거나 소리가 찢어진다.
///
/// 저장소가 없는 환경에서도 게임은 굴러가야 하므로 "저장 실패는 무음이 아니라
/// 기본값" 이라는 것도 함께 확인한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // 정적 상태라 시험 사이에 값이 새 나간다. 매번 기본값에서 출발시킨다.
    GameAudio.setSfxVolume(0.85);
    await GameAudio.setMusicVolume(0.5);
    GameAudio.muted = false;
  });

  group('볼륨 저장', () {
    test('저장한 볼륨은 다음 접속에서 그대로 돌아온다', () async {
      GameAudio.setSfxVolume(0.3);
      await GameAudio.setMusicVolume(0.1);
      GameAudio.muted = true;
      await AudioSettings.save();

      // 앱을 다시 띄운 셈 치고 값을 흐트러뜨린다.
      GameAudio.setSfxVolume(1);
      await GameAudio.setMusicVolume(1);
      GameAudio.muted = false;

      await AudioSettings.load();

      expect(GameAudio.sfxVolume, closeTo(0.3, 1e-9));
      expect(GameAudio.musicVolume, closeTo(0.1, 1e-9));
      expect(GameAudio.muted, isTrue);
    });

    test('저장된 값이 없으면 기본 볼륨을 그대로 둔다', () async {
      await AudioSettings.load();

      expect(GameAudio.sfxVolume, closeTo(0.85, 1e-9));
      expect(GameAudio.musicVolume, closeTo(0.5, 1e-9));
      expect(GameAudio.muted, isFalse);
    });

    test('예전 기기에 없던 항목만 건너뛴다', () async {
      // 항목이 늘어날 때마다 예전 설정이 통째로 날아가면 안 된다.
      SharedPreferences.setMockInitialValues({AudioSettings.sfxKey: 0.2});

      await AudioSettings.load();

      expect(GameAudio.sfxVolume, closeTo(0.2, 1e-9));
      expect(GameAudio.musicVolume, closeTo(0.5, 1e-9));
    });
  });

  group('볼륨 범위', () {
    test('1 을 넘겨 넣어도 1 에서 멈춘다', () async {
      GameAudio.setSfxVolume(2.5);
      await GameAudio.setMusicVolume(9);

      expect(GameAudio.sfxVolume, 1.0);
      expect(GameAudio.musicVolume, 1.0);
    });

    test('음수를 넣어도 0 에서 멈춘다', () async {
      GameAudio.setSfxVolume(-1);
      await GameAudio.setMusicVolume(-0.4);

      expect(GameAudio.sfxVolume, 0.0);
      expect(GameAudio.musicVolume, 0.0);
    });

    test('저장소에 망가진 값이 들어 있어도 범위 안으로 끌어온다', () async {
      // 기기 저장소는 앱 밖에서도 고쳐질 수 있다. 읽은 값을 그대로 믿지 않는다.
      SharedPreferences.setMockInitialValues({
        AudioSettings.sfxKey: 42.0,
        AudioSettings.musicKey: -3.0,
      });

      await AudioSettings.load();

      expect(GameAudio.sfxVolume, 1.0);
      expect(GameAudio.musicVolume, 0.0);
    });
  });
}
