import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ring.dart';
import '../models/units.dart';
import '../state/project_controller.dart';

/// True while a text field has focus, so global key shortcuts stand down and
/// let the field handle typing / cursor movement.
final editingTextProvider = StateProvider<bool>((ref) => false);

/// Handle a key event at the root, before focus traversal can consume it.
/// Returns [KeyEventResult.handled] when a shortcut fired.
KeyEventResult handleBowlKey(WidgetRef ref, KeyEvent event) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
    return KeyEventResult.ignored;
  }
  if (ref.read(editingTextProvider)) return KeyEventResult.ignored;

  final key = event.logicalKey;
  final hk = HardwareKeyboard.instance;
  final fine = hk.isAltPressed;
  final shift = hk.isShiftPressed;
  final cmd = hk.isMetaPressed || hk.isControlPressed;
  final ctrl = ref.read(projectControllerProvider.notifier);

  // Undo / redo (work regardless of selection).
  if (key == LogicalKeyboardKey.keyZ && cmd) {
    shift ? ctrl.redo() : ctrl.undo();
    return KeyEventResult.handled;
  }

  final ring = ref.read(selectedRingProvider);
  if (ring == null) return KeyEventResult.ignored;

  final unit = ref.read(displayUnitProvider);
  final step = fine ? UnitFormat.fineStep(unit) : UnitFormat.coarseStep(unit);

  void resizeOuter(int dir) {
    ctrl.updateRing(ring.id, (r) {
      final od = (r.outerDiameter + dir * step).clamp(1.0, 100000.0);
      return r.copyWith(
        outerDiameter: od,
        innerDiameter: r.innerDiameter.clamp(0.0, od - 1),
      );
    });
  }

  void resizeInner(int dir) {
    if (ring.type == RingType.disk) return;
    ctrl.updateRing(ring.id, (r) {
      final id = (r.innerDiameter + dir * step).clamp(0.0, r.outerDiameter - 1);
      return r.copyWith(innerDiameter: id);
    });
  }

  void resizeThickness(int dir) {
    ctrl.updateRing(
        ring.id, (r) => r.copyWith(thickness: (r.thickness + dir * step).clamp(1.0, 100000.0)));
  }

  void changeSegments(int dir) {
    ctrl.updateRing(ring.id, (r) {
      final n = (r.segmentCount + dir).clamp(1, 240);
      return r.copyWith(segmentCount: n);
    });
  }

  switch (key) {
    case LogicalKeyboardKey.arrowRight when shift:
      resizeInner(1);
    case LogicalKeyboardKey.arrowLeft when shift:
      resizeInner(-1);
    case LogicalKeyboardKey.arrowRight:
      resizeOuter(1);
    case LogicalKeyboardKey.arrowLeft:
      resizeOuter(-1);
    case LogicalKeyboardKey.arrowUp:
    case LogicalKeyboardKey.bracketRight:
      resizeThickness(1);
    case LogicalKeyboardKey.arrowDown:
    case LogicalKeyboardKey.bracketLeft:
      resizeThickness(-1);
    case LogicalKeyboardKey.equal:
    case LogicalKeyboardKey.add:
      changeSegments(1);
    case LogicalKeyboardKey.minus:
      changeSegments(-1);
    default:
      return KeyEventResult.ignored;
  }
  return KeyEventResult.handled;
}
