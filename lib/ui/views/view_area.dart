import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/units.dart';
import '../../rendering/cross_section_painter.dart';
import '../../rendering/elevation_painter.dart';
import '../../state/project_controller.dart';
import '../theme.dart';
import 'bowl_3d_view.dart';
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
    final wallMm = xray ? ref.watch(xrayWallProvider) : null;
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
                wireframeWallMm: wallMm,
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
              if (xray)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: _XrayWallControl(value: wallMm, unit: unit),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _threeD() {
    final antialias = ref.watch(antialias3dProvider);
    final maximized = ref.watch(viewMaximizedProvider);
    // Recreate the GPU view when AA changes (a renderer-construction flag) or
    // when the pane is maximized/restored — that's a layout-only size change,
    // which three_js's resize path (driven by window metrics) would otherwise
    // miss, leaving the camera aspect stale.
    return Bowl3DView(
      key: ValueKey('$antialias-$maximized'),
      antialias: antialias,
    );
  }
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
  const _ViewLabel({required this.text});
  final String text;

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
          color: c.faint,
        )),
      ),
    );
  }
}

/// X-ray control: toggle and set a uniform finished-wall thickness to preview
/// the turned wall. Off shows the wall implied by each ring's actual bore.
class _XrayWallControl extends ConsumerWidget {
  const _XrayWallControl({required this.value, required this.unit});
  final double? value;
  final LengthUnit unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final on = value != null;
    final step = UnitFormat.coarseStep(unit);
    void set(double? mm) => ref.read(xrayWallProvider.notifier).state = mm;

    Widget iconBtn(IconData icon, VoidCallback onTap, String tip) => Tooltip(
          message: tip,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Icon(icon, size: 15, color: c.accent),
            ),
          ),
        );

    return Material(
      color: on ? c.accentSoft : c.surface,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: on ? c.accent : c.borderStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.straighten, size: 15, color: on ? c.accent : c.muted),
            const SizedBox(width: 6),
            Text('Wall',
                style: AppFonts.ui(TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: on ? c.accent : c.muted))),
            if (!on)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: iconBtn(Icons.visibility_outlined,
                    () => set(ref.read(projectProvider).targetWallMm), 'Preview a uniform finished wall'),
              )
            else ...[
              const SizedBox(width: 8),
              iconBtn(Icons.remove, () => set((value! - step).clamp(0.5, 1e6)),
                  'Thinner'),
              SizedBox(
                width: 42,
                child: Text(
                  UnitFormat.withUnit(value!, unit),
                  textAlign: TextAlign.center,
                  style: AppFonts.mono(TextStyle(fontSize: 11.5, color: c.ink)),
                ),
              ),
              iconBtn(Icons.add, () => set(value! + step), 'Thicker'),
              const SizedBox(width: 2),
              iconBtn(Icons.close, () => set(null), 'Show actual bore'),
            ],
          ],
        ),
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

