import 'package:flutter_test/flutter_test.dart';

import 'package:actionrpg/game/systems/camera_zoom.dart';

void main() {
  group('CameraZoom 단계', () {
    test('처음에는 기본 배율 100% 다', () {
      final zoom = CameraZoom();
      expect(zoom.scale, 1.0);
      expect(zoom.label, '100%');
    });

    test('한 번 누를 때마다 한 단계씩만 움직인다', () {
      final zoom = CameraZoom();
      expect(zoom.zoomIn(), isTrue);
      expect(zoom.scale, CameraZoom.steps[CameraZoom.defaultIndex + 1]);
      expect(zoom.zoomOut(), isTrue);
      expect(zoom.scale, 1.0);
    });

    test('끝까지 당겼다 되돌리면 원래 배율로 정확히 돌아온다', () {
      // 곱셈으로 늘리면 상한에서 잘려 되돌아올 자리가 어긋난다.
      // 단계를 미리 못 박아 둔 이유가 이것이다.
      final zoom = CameraZoom();
      var pushed = 0;
      while (zoom.zoomIn()) {
        pushed++;
      }
      for (var i = 0; i < pushed; i++) {
        expect(zoom.zoomOut(), isTrue);
      }
      expect(zoom.scale, 1.0);
    });

    test('상한·하한을 넘어가지 않고 넘으려 하면 false 를 준다', () {
      final zoom = CameraZoom();
      while (zoom.zoomIn()) {}
      expect(zoom.canZoomIn, isFalse);
      expect(zoom.zoomIn(), isFalse);
      expect(zoom.scale, CameraZoom.steps.last);

      while (zoom.zoomOut()) {}
      expect(zoom.canZoomOut, isFalse);
      expect(zoom.zoomOut(), isFalse);
      expect(zoom.scale, CameraZoom.steps.first);
    });

    test('단계는 작은 것부터 큰 것 순이고 기본 단계가 1.0 이다', () {
      for (var i = 1; i < CameraZoom.steps.length; i++) {
        expect(
          CameraZoom.steps[i],
          greaterThan(CameraZoom.steps[i - 1]),
          reason: '$i 번째 단계가 앞 단계보다 작다',
        );
      }
      expect(CameraZoom.steps[CameraZoom.defaultIndex], 1.0);
    });

    test('reset 하면 기본 단계로 돌아온다', () {
      final zoom = CameraZoom();
      zoom.zoomIn();
      zoom.zoomIn();
      zoom.reset();
      expect(zoom.scale, 1.0);
    });
  });

  group('CameraZoom 화면 배율', () {
    test('기준 높이에서는 기본 배율이 정확히 1.0 이다', () {
      expect(CameraZoom.baseZoomFor(CameraZoom.referenceHeight), 1.0);
    });

    test('아주 작거나 큰 창에서도 기본 배율이 상·하한 안에 머문다', () {
      expect(CameraZoom.baseZoomFor(100), CameraZoom.minBase);
      expect(CameraZoom.baseZoomFor(100000), CameraZoom.maxBase);
    });

    test('고른 배율은 창 크기가 바뀌어도 그대로 곱해진다', () {
      // 화면에서 나오는 몫과 사람이 고른 몫을 나눠 둔 이유다. 창을 줄였다고
      // "두 단계 물러나 있다" 는 선택이 지워지면 안 된다.
      final zoom = CameraZoom()..zoomOut();
      final scale = zoom.scale;
      for (final height in [420.0, 760.0, 1440.0]) {
        expect(
          zoom.zoomFor(height),
          closeTo(CameraZoom.baseZoomFor(height) * scale, 1e-9),
        );
      }
    });

    test('당길수록 카메라 배율이 커진다', () {
      final zoom = CameraZoom();
      final before = zoom.zoomFor(CameraZoom.referenceHeight);
      zoom.zoomIn();
      expect(zoom.zoomFor(CameraZoom.referenceHeight), greaterThan(before));
      zoom.zoomOut();
      zoom.zoomOut();
      expect(zoom.zoomFor(CameraZoom.referenceHeight), lessThan(before));
    });
  });
}
