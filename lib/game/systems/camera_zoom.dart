/// 카메라 배율. **화면이 정하는 몫과 플레이어가 고른 몫을 나눠 둔다.**
///
/// 둘을 합친 값 하나만 들고 있으면 창 크기가 바뀔 때마다 플레이어가 고른 배율이
/// 지워진다. 화면에서 나오는 기본 배율([baseZoomFor])에 고른 배율([scale])을
/// 곱하는 형태로 두면, 창을 줄이든 늘리든 "두 단계 당겨 놓았다" 는 선택이 그대로
/// 남는다.
///
/// 카메라를 직접 건드리지 않고 값만 계산한다 — 그래야 Flame 없이 시험할 수 있다.
class CameraZoom {
  /// 고를 수 있는 배율 단계. 가운데([defaultIndex])가 여태까지의 기본 배율이다.
  ///
  /// 누를 때마다 일정 비율로 곱하지 않고 단계를 미리 못 박은 이유는 이것이
  /// 버튼이기 때문이다. 곱셈이면 상·하한에서 잘려 단계가 어긋나고, 한 번 끝까지
  /// 밀어낸 뒤에는 되돌려도 원래 보던 배율로 정확히 돌아오지 못한다.
  static const List<double> steps = [0.5, 0.65, 0.8, 1.0, 1.25, 1.6, 2.0];

  /// 시작 단계. [steps] 에서 1.0 이 놓인 자리다.
  static const int defaultIndex = 3;

  /// 기본 배율을 재는 기준 화면 높이(px). 이 높이에서 기본 배율이 정확히 1.0이다.
  static const double referenceHeight = 760;

  /// 기본 배율의 하한·상한. 아주 작은 창에서 월드가 개미만 해지거나, 큰 화면에서
  /// 지나치게 확대되는 것을 막는다.
  static const double minBase = 0.55;
  static const double maxBase = 1.6;

  int _index = defaultIndex;

  /// 지금 고른 단계의 번호.
  int get index => _index;

  /// 지금 고른 배율.
  double get scale => steps[_index];

  /// 더 당길 수 있는지(단계가 남았는지).
  bool get canZoomIn => _index < steps.length - 1;

  /// 더 물러날 수 있는지.
  bool get canZoomOut => _index > 0;

  /// 화면 높이만으로 정해지는 기본 배율.
  static double baseZoomFor(double screenHeight) =>
      (screenHeight / referenceHeight).clamp(minBase, maxBase);

  /// 카메라에 실제로 넣을 배율.
  double zoomFor(double screenHeight) => baseZoomFor(screenHeight) * scale;

  /// 한 단계 당긴다. 이미 끝이면 아무것도 바꾸지 않고 false 를 준다.
  bool zoomIn() {
    if (!canZoomIn) return false;
    _index++;
    return true;
  }

  /// 한 단계 물러난다. 이미 끝이면 아무것도 바꾸지 않고 false 를 준다.
  bool zoomOut() {
    if (!canZoomOut) return false;
    _index--;
    return true;
  }

  /// 기본 단계로 되돌린다.
  void reset() => _index = defaultIndex;

  /// 버튼 사이에 띄우는 표기. 기본 단계가 100% 다.
  String get label => '${(scale * 100).round()}%';
}
