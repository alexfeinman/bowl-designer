import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../geometry/ring_geometry.dart';
import '../models/bowl_project.dart';
import '../models/ring.dart';
import '../models/units.dart';
import 'local_store.dart';

/// Initial project the controller starts from. Overridden in `main()` with the
/// autosaved design when one is restored; otherwise the sample.
final initialProjectProvider = Provider<BowlProject>((ref) => BowlProject.sample());

/// An undo/redo history of immutable project snapshots.
class ProjectHistory {
  const ProjectHistory({required this.stack, required this.index});

  final List<BowlProject> stack;
  final int index;

  BowlProject get current => stack[index];
  bool get canUndo => index > 0;
  bool get canRedo => index < stack.length - 1;

  static const int _maxDepth = 100;

  /// Push [next] as a new snapshot, discarding any redo entries.
  ProjectHistory push(BowlProject next) {
    final trimmed = stack.sublist(0, index + 1)..add(next);
    final overflow = trimmed.length - _maxDepth;
    final kept = overflow > 0 ? trimmed.sublist(overflow) : trimmed;
    return ProjectHistory(stack: kept, index: kept.length - 1);
  }

  /// Replace the current snapshot without adding a history step (settings).
  ProjectHistory replaceCurrent(BowlProject next) {
    final copy = [...stack];
    copy[index] = next;
    return ProjectHistory(stack: copy, index: index);
  }

  ProjectHistory undo() =>
      canUndo ? ProjectHistory(stack: stack, index: index - 1) : this;
  ProjectHistory redo() =>
      canRedo ? ProjectHistory(stack: stack, index: index + 1) : this;
}

class ProjectController extends Notifier<ProjectHistory> {
  @override
  ProjectHistory build() =>
      ProjectHistory(stack: [ref.read(initialProjectProvider)], index: 0);

  BowlProject get project => state.current;

  Timer? _saveDebounce;

  /// Best-effort autosave of the current document (debounced).
  void _persist() {
    _saveDebounce?.cancel();
    final snapshot = project;
    _saveDebounce = Timer(const Duration(milliseconds: 400), () {
      LocalStore.write(jsonEncode(snapshot.toJson()));
    });
  }

  // ---- history-recording mutations ----------------------------------------

  void _commit(BowlProject next) {
    state = state.push(next);
    _persist();
  }

  /// Update a single ring by id and record the change.
  void updateRing(String id, Ring Function(Ring ring) update) {
    final rings = [
      for (final r in project.rings) r.id == id ? update(r) : r,
    ];
    _commit(project.copyWith(rings: rings));
  }

  void addRing({String? afterId}) {
    final ref = afterId == null
        ? (project.rings.isEmpty ? null : project.rings.last)
        : project.rings.firstWhere((r) => r.id == afterId);
    final base = ref ??
        Ring(
          id: '',
          name: '',
          type: RingType.normal,
          outerDiameter: 180,
          innerDiameter: 130,
          thickness: 25,
          segmentCount: 12,
        );
    final newRing = base.copyWith(
      id: 'r-${DateTime.now().microsecondsSinceEpoch}',
      name: 'Ring ${project.rings.length + 1}',
    );
    final rings = [...project.rings];
    final at = ref == null ? rings.length : rings.indexOf(ref) + 1;
    rings.insert(at, newRing);
    _commit(project.copyWith(rings: rings));
  }

  void duplicateRing(String id) {
    final idx = project.rings.indexWhere((r) => r.id == id);
    if (idx < 0) return;
    final src = project.rings[idx];
    final copy = src.copyWith(
      id: 'r-${DateTime.now().microsecondsSinceEpoch}',
      name: '${src.name} copy',
    );
    final rings = [...project.rings]..insert(idx + 1, copy);
    _commit(project.copyWith(rings: rings));
  }

  void removeRing(String id) {
    if (project.rings.length <= 1) return;
    final rings = project.rings.where((r) => r.id != id).toList();
    _commit(project.copyWith(rings: rings));
  }

  /// Reorder within the *display* (top→bottom) list; [oldIndex]/[newIndex] are
  /// display indices which we translate to storage (bottom→top) order.
  void reorderByDisplay(int oldDisplay, int newDisplay) {
    final n = project.rings.length;
    final storageOld = n - 1 - oldDisplay;
    var storageNew = n - 1 - newDisplay;
    final rings = [...project.rings];
    final moved = rings.removeAt(storageOld);
    if (storageNew > storageOld) storageNew -= 1;
    rings.insert(storageNew.clamp(0, rings.length), moved);
    _commit(project.copyWith(rings: rings));
  }

  void autoFitWalls(double targetMm, WallFitMode mode) =>
      _commit(RingGeometry.autoAdjustWalls(project, targetMm, mode));

  void rename(String name) => _commit(project.copyWith(name: name));

  /// Replace the whole project (e.g. on open / import), fresh history.
  void loadProject(BowlProject next) {
    state = ProjectHistory(stack: [next], index: 0);
    _persist();
  }

  // ---- non-history settings ------------------------------------------------

  void setDisplayUnit(LengthUnit unit) {
    state = state.replaceCurrent(project.copyWith(displayUnit: unit));
    _persist();
  }

  void setAntialias3d(bool on) {
    state = state.replaceCurrent(project.copyWith(antialias3d: on));
    _persist();
  }

  void setKerfAllowance(double mm) {
    state = state.replaceCurrent(project.copyWith(kerfAllowanceMm: mm));
    _persist();
  }

  /// Update the default Auto-fit target wall (a setting, not a history step).
  void setTargetWall(double mm) {
    state = state.replaceCurrent(project.copyWith(targetWallMm: mm));
    _persist();
  }

  // ---- undo / redo ---------------------------------------------------------

  void undo() {
    state = state.undo();
    _persist();
  }

  void redo() {
    state = state.redo();
    _persist();
  }
}

final projectControllerProvider =
    NotifierProvider<ProjectController, ProjectHistory>(ProjectController.new);

/// Convenience: the current project document.
final projectProvider =
    Provider<BowlProject>((ref) => ref.watch(projectControllerProvider).current);

/// Active display unit (lives on the project).
final displayUnitProvider =
    Provider<LengthUnit>((ref) => ref.watch(projectProvider).displayUnit);

/// Whether the 3D view is antialiased (lives on the project, so it persists).
final antialias3dProvider =
    Provider<bool>((ref) => ref.watch(projectProvider).antialias3d);

/// Holds the currently selected ring id. Deliberately does NOT watch the
/// project, so editing a ring never snaps the selection back to another ring.
class SelectionController extends Notifier<String?> {
  @override
  String? build() {
    final rings = ref.read(projectProvider).rings;
    return rings.isEmpty ? null : rings.last.id;
  }

  void select(String? id) => state = id;
}

final selectionControllerProvider =
    NotifierProvider<SelectionController, String?>(SelectionController.new);

/// Currently selected ring id (null = none).
final selectedRingIdProvider = Provider<String?>((ref) {
  final id = ref.watch(selectionControllerProvider);
  final rings = ref.watch(projectProvider).rings;
  // Fall back to the top ring if the selection no longer exists.
  if (id != null && rings.any((r) => r.id == id)) return id;
  return rings.isEmpty ? null : rings.last.id;
});

/// The selected ring object, or null.
final selectedRingProvider = Provider<Ring?>((ref) {
  final id = ref.watch(selectedRingIdProvider);
  final rings = ref.watch(projectProvider).rings;
  for (final r in rings) {
    if (r.id == id) return r;
  }
  return null;
});
