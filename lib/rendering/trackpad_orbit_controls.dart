import 'package:three_js/three_js.dart' as three;

/// OrbitControls tuned for macOS trackpads (adapted from the Object Editor):
///   one-finger (click) drag -> rotate
///   two-finger drag         -> pan
///   pinch / mouse wheel     -> zoom
///
/// Also detects a plain click (press + release with negligible movement) and
/// reports it via [onClick] with the element-local pixel position, so the view
/// can ray-pick a ring. Doing it here is reliable because the controls already
/// receive every pointer event on the GL canvas (a Flutter GestureDetector over
/// the canvas does not).
class TrackpadOrbitControls extends three.OrbitControls {
  TrackpadOrbitControls(super.object, super.listenableKey, {this.onClick});

  final void Function(double x, double y)? onClick;

  double _downX = 0, _downY = 0;
  bool _moved = false;

  bool _isTrackpadDrag(dynamic event) => event.pointerType == 'touch_pad';

  @override
  void onPointerDown(event) {
    if (enabled == false) return;
    _downX = (event.clientX as num?)?.toDouble() ?? 0;
    _downY = (event.clientY as num?)?.toDouble() ?? 0;
    _moved = false;
    if (_isTrackpadDrag(event)) {
      if (pointers.isEmpty) {
        domElement.addEventListener(
            three.PeripheralType.pointermove, onPointerMove);
        domElement.addEventListener(
            three.PeripheralType.pointerup, onPointerUp);
      }
      addPointer(event);
      if (enablePan == false) return;
      handleMouseDownPan(event);
      state = three.OrbitState.pan;
      return;
    }
    super.onPointerDown(event);
  }

  @override
  void onPointerMove(event) {
    if (enabled == false) return;
    final dx = ((event.clientX as num?)?.toDouble() ?? _downX) - _downX;
    final dy = ((event.clientY as num?)?.toDouble() ?? _downY) - _downY;
    if (dx.abs() + dy.abs() > 4) _moved = true;
    if (_isTrackpadDrag(event)) {
      if (enablePan == false || state != three.OrbitState.pan) return;
      handleMouseMovePan(event);
      return;
    }
    super.onPointerMove(event);
  }

  @override
  void onPointerUp(event) {
    if (!_moved && onClick != null) {
      onClick!(
        (event.clientX as num?)?.toDouble() ?? _downX,
        (event.clientY as num?)?.toDouble() ?? _downY,
      );
    }
    super.onPointerUp(event);
  }
}
