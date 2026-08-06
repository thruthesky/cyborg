import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_audio.dart';

/// 플레이어가 고른 볼륨을 기기에 저장하고 [GameAudio] 에 되돌려 놓는다.
///
/// 소리 크기는 **기기에 붙는 값**이지 계정에 붙는 값이 아니다. 스피커가 큰
/// 데스크톱에서 줄여 둔 값이 휴대폰까지 따라가면 오히려 성가시므로 서버가 아니라
/// `shared_preferences` 에 남긴다.
///
/// 저장소를 열 수 없는 환경(플러그인이 없는 테스트 등)에서도 게임은 그대로
/// 굴러가야 한다. 실패하면 조용히 기본 볼륨으로 남는다.
class AudioSettings {
  AudioSettings._();

  static const String sfxKey = 'audio_sfx_volume';
  static const String musicKey = 'audio_music_volume';
  static const String mutedKey = 'audio_muted';

  /// 저장해 둔 볼륨을 읽어 [GameAudio] 에 적용한다.
  ///
  /// 게임 로딩 단계에서 [GameAudio.init] 다음에 한 번 부른다. 저장된 값이 없으면
  /// 각 항목의 기본값을 그대로 둔다 — 없는 항목만 건너뛰므로, 나중에 항목이
  /// 늘어도 예전 기기의 설정이 통째로 날아가지 않는다.
  static Future<void> load() async {
    final prefs = await _open();
    if (prefs == null) return;

    final sfx = prefs.getDouble(sfxKey);
    if (sfx != null) GameAudio.setSfxVolume(sfx);

    final music = prefs.getDouble(musicKey);
    if (music != null) await GameAudio.setMusicVolume(music);

    final muted = prefs.getBool(mutedKey);
    if (muted != null) GameAudio.muted = muted;
  }

  /// 지금 [GameAudio] 에 걸려 있는 값을 기기에 남긴다.
  ///
  /// 슬라이더를 끄는 동안이 아니라 손을 뗀 뒤에 부른다. 매 프레임 부르면 초당
  /// 수십 번 디스크에 쓰게 된다.
  static Future<void> save() async {
    final prefs = await _open();
    if (prefs == null) return;
    try {
      await prefs.setDouble(sfxKey, GameAudio.sfxVolume);
      await prefs.setDouble(musicKey, GameAudio.musicVolume);
      await prefs.setBool(mutedKey, GameAudio.muted);
    } catch (error) {
      debugPrint('볼륨 설정을 저장하지 못했다: $error');
    }
  }

  static Future<SharedPreferences?> _open() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (error) {
      debugPrint('볼륨 설정 저장소를 열지 못했다 — 기본값으로 진행한다: $error');
      return null;
    }
  }
}
