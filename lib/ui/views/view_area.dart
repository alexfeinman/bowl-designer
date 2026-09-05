import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../rendering/cross_section_painter.dart';
import '../../rendering/elevation_painter.dart';
import '../../rendering/scene_3d.dart';
import '../../state/project_controller.dart';
import '../theme.dart';
import 'cut_list_view.dart';

enum BowlView { side, xray, threeD, cutList }

/// When true the view area fills the whole window (side panels hidden), so the
/// 3D render can grow to the full app size instead of the centre pane.
final viewMaximizedProvider = StateProvider<bool>((ref) => false);

/// Whether the reference grid is drawn behind the 2D (Side / X-ray) views.
/// Off by default.
final gridVisibleProvider = StateProvider<bool>((ref) => false);

class ViewArea extends ConsumerStatefulWidget {
  const ViewArea({super.key});
  @override
  ConsumerState<ViewArea> createState() => _ViewAreaState();
}

class _ViewAreaState extends ConsumerState<ViewArea> {
  BowlView _view = BowlView.side; // Opens on Side elevation.
  Camera3D _camera = const Camera3D();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        _TabBar(
          current: _view,
          onChanged: (v) => setState(() => _view = v),
        ),
        Expanded(
          // Clip so painters (esp. the 3D scene when zoomed) never draw
          // outside the pane onto the tab bar or other panels.
          child: ClipRect(
            child: Container(
              color: _view == BowlView.threeD ? c.viewDark : c.viewBg,
              child: switch (_view) {
                BowlView.side => _crossSection(false),
                BowlView.xray => _crossSection(true),
                BowlView.threeD => _threeD(),
                BowlView.cutList => const CutListView(),
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _crossSection(bool xray) {
    final c = context.colors;
    final project = ref.watch(projectProvider);
    final unit = ref.watch(displayUnitProvider);
    final selId = ref.watch(selectedRingIdProvider);
    // Grid is a Side-elevation aid only; the X-ray never draws one.
    final gridAllowed = !xray;
    final showGrid = gridAllowed && ref.watch(gridVisibleProvider);
    return LayoutBuilder(
      builder: (context, cons) {
        final size = Size(cons.maxWidth, cons.maxHeight);
        final painter = xray
            ? CrossSectionPainter(
                project: project,
                xray: true,
                colors: c,
                unit: unit,
                highlightRingId: selId,
              )
            : ElevationPainter(
                project: project,
                colors: c,
                unit: unit,
                highlightRingId: selId,
              );
        final Widget canvas = CustomPaint(painter: painter);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final id = xray
                ? CrossSectionPainter.ringIdAt(project, size, d.localPosition)
                : ElevationPainter.ringIdAt(project, size, d.localPosition);
            if (id != null) {
              ref.read(selectionControllerProvider.notifier).select(id);
            }
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: showGrid
                    ? GridPaper(
                        color: c.grid,
                        interval: 44,
                        divisions: 2,
                        subdivisions: 1,
                        child: canvas,
                      )
                    : canvas,
              ),
              _ViewLabel(
                  text: xray
                      ? 'X-RAY · FINISHED WALL PROFILE · CLICK TO SELECT'
                      : 'SIDE ELEVATION · SEGMENTS · CLICK TO SELECT'),
              if (gridAllowed)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: _GridToggle(
                    on: showGrid,
                    onTap: () =>
                        ref.read(gridVisibleProvider.notifier).state = !showGrid,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _threeD() {
    final project = ref.watch(projectProvider);
    final selId = ref.watch(selectedRingIdProvider);
    final hiIndex = project.rings.indexWhere((r) => r.id == selId);
    return LayoutBuilder(
      builder: (context, cons) {
        final size = Size(cons.maxWidth, cons.maxHeight);
        return Stack(
          children: [
            Positioned.fill(
              child: Listener(
                onPointerSignal: (e) {
                  if (e is PointerScrollEvent) {
                    setState(() => _camera =
                        _camera.zoomed(e.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1));
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) {
                    final id = pickRingId(project, _camera, size, d.localPosition);
                    if (id != null) {
                      ref.read(selectionControllerProvider.notifier).select(id);
                    }
                  },
                  onScaleStart: (_) {},
                  onScaleUpdate: (d) {
                    setState(() {
                      _camera = _camera.rotated(
                        d.focalPointDelta.dx * 0.01,
                        -d.focalPointDelta.dy * 0.01,
                      );
                      if (d.scale != 1.0) {
                        _camera = _camera.zoomed(d.scale > 1 ? 1.03 : 1 / 1.03);
                      }
                    });
                  },
                  child: CustomPaint(
                    painter: BowlScenePainter(
                      project: project,
                      camera: _camera,
                      edgeColor: const Color(0xFF000000),
                      highlightRingIndex: hiIndex < 0 ? null : hiIndex,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            const _ViewLabel(
                text: '3D · DRAG TO ORBIT · SCROLL OR ± TO ZOOM · CLICK TO SELECT',
                light: true),
            Positioned(
              right: 12,
              bottom: 12,
              child: Row(
                children: [
                  _RoundBtn(icon: Icons.remove, onTap: () => _zoom(1 / 1.2)),
                  const SizedBox(width: 6),
                  _RoundBtn(icon: Icons.add, onTap: () => _zoom(1.2)),
                  const SizedBox(width: 10),
                  _GhostButton(
                    label: 'Reset view',
                    onTap: () => setState(() => _camera = const Camera3D()),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _zoom(double factor) => setState(() => _camera = _camera.zoomed(factor));
}

class _TabBar extends ConsumerWidget {
  const _TabBar({required this.current, required this.onChanged});
  final BowlView current;
  final ValueChanged<BowlView> onChanged;

  static const _labels = {
    BowlView.side: 'Side',
    BowlView.xray: 'X-ray',
    BowlView.threeD: '3D',
    BowlView.cutList: 'Cut list',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final maximized = ref.watch(viewMaximizedProvider);
    return Container(
      color: c.surface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          for (final v in BowlView.values)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: _Tab(
                label: _labels[v]!,
                selected: current == v,
                bg: current == v ? (v == BowlView.threeD ? c.viewDark : c.viewBg) : null,
                onTap: () => onChanged(v),
              ),
            ),
          const Spacer(),
          IconButton(
            tooltip: maximized ? 'Restore panels' : 'Expand view to window',
            iconSize: 18,
            color: maximized ? c.accent : c.muted,
            onPressed: () =>
                ref.read(viewMaximizedProvider.notifier).state = !maximized,
            icon: Icon(maximized ? Icons.fullscreen_exit : Icons.fullscreen),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.selected, required this.onTap, this.bg});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? bg;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? bg : Colors.transparent,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          border: selected
              ? Border(
                  top: BorderSide(color: c.border),
                  left: BorderSide(color: c.border),
                  right: BorderSide(color: c.border),
                )
              : null,
        ),
        child: Text(
          label,
          style: AppFonts.ui(TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? c.ink : c.muted,
          )),
        ),
      ),
    );
  }
}

class _ViewLabel extends StatelessWidget {
  const _ViewLabel({required this.text, this.light = false});
  final String text;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Positioned(
      left: 14,
      bottom: 12,
      child: Text(
        text,
        style: AppFonts.mono(TextStyle(
          fontSize: 10.5,
          letterSpacing: 0.6,
          color: light ? Colors.white.withValues(alpha: 0.55) : c.faint,
        )),
      ),
    );
  }
}

class _GridToggle extends StatelessWidget {
  const _GridToggle({required this.on, required this.onTap});
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: on ? c.accentSoft : c.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: on ? c.accent : c.borderStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.grid_4x4, size: 15, color: on ? c.accent : c.muted),
              const SizedBox(width: 6),
              Text('Grid',
                  style: AppFonts.ui(TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: on ? c.accent : c.muted,
                  ))),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.85)),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white.withValues(alpha: 0.8),
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      child: Text(label,
          style: AppFonts.ui(const TextStyle(fontSize: 11.5, color: Colors.white))),
    );
  }
}
