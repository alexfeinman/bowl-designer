import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/bowl_project.dart';
import '../../models/ring.dart';
import '../../models/units.dart';
import '../../state/project_controller.dart';
import '../theme.dart';

/// Left pane: the stack of rings, shown top → bottom, reorderable.
class RingListPanel extends ConsumerWidget {
  const RingListPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final project = ref.watch(projectProvider);
    final unit = ref.watch(displayUnitProvider);
    final selId = ref.watch(selectedRingIdProvider);
    final ctrl = ref.read(projectControllerProvider.notifier);

    // Display order: top of the bowl first.
    final display = project.rings.reversed.toList();

    return Container(
      decoration: BoxDecoration(
        color: c.panel,
        border: Border(right: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            title: 'RING STACK · TOP → BOTTOM',
            trailing: TextButton.icon(
              onPressed: () => _addAndSelect(ref),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
              style: TextButton.styleFrom(foregroundColor: c.accent),
            ),
          ),
          Expanded(
            // Tiles must not take keyboard focus, or arrow keys would move
            // focus through the list instead of resizing the selected ring.
            child: ExcludeFocus(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                buildDefaultDragHandles: false,
                itemCount: display.length,
                onReorder: ctrl.reorderByDisplay,
                itemBuilder: (context, i) {
                  final ring = display[i];
                  return _RingTile(
                    key: ValueKey(ring.id),
                    ring: ring,
                    index: i,
                    unit: unit,
                    selected: ring.id == selId,
                    onTap: () => ref
                        .read(selectionControllerProvider.notifier)
                        .select(ring.id),
                    onDuplicate: () => ctrl.duplicateRing(ring.id),
                    onDelete: project.rings.length > 1
                        ? () => _delete(ref, ring.id)
                        : null,
                  );
                },
              ),
            ),
          ),
          _StackSummary(project: project, unit: unit),
        ],
      ),
    );
  }

  void _addAndSelect(WidgetRef ref) {
    final before = ref.read(projectProvider).rings.map((r) => r.id).toSet();
    ref.read(projectControllerProvider.notifier).addRing();
    final added = ref
        .read(projectProvider)
        .rings
        .firstWhere((r) => !before.contains(r.id), orElse: () => ref.read(projectProvider).rings.last);
    ref.read(selectionControllerProvider.notifier).select(added.id);
  }

  void _delete(WidgetRef ref, String id) {
    final rings = ref.read(projectProvider).rings;
    final wasSelected = ref.read(selectedRingIdProvider) == id;
    // Choose a neighbour to select before the ring disappears.
    final idx = rings.indexWhere((r) => r.id == id);
    ref.read(projectControllerProvider.notifier).removeRing(id);
    if (wasSelected) {
      final remaining = ref.read(projectProvider).rings;
      if (remaining.isNotEmpty) {
        final next = remaining[idx.clamp(0, remaining.length - 1)];
        ref.read(selectionControllerProvider.notifier).select(next.id);
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppFonts.ui(TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: c.faint,
              )),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _RingTile extends StatelessWidget {
  const _RingTile({
    super.key,
    required this.ring,
    required this.index,
    required this.unit,
    required this.selected,
    required this.onTap,
    required this.onDuplicate,
    this.onDelete,
  });

  final Ring ring;
  final int index;
  final LengthUnit unit;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final meta = StringBuffer('⌀${UnitFormat.value(ring.outerDiameter, unit)}');
    if (ring.effectiveInnerDiameter > 0) {
      meta.write(' · id ${UnitFormat.value(ring.effectiveInnerDiameter, unit)}');
    }
    meta.write(' · ${ring.isSolid ? "solid" : "${ring.segmentCount} seg"}');
    meta.write(' · ${UnitFormat.value(ring.thickness, unit)}');

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: selected ? c.accent : c.border,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Icon(Icons.drag_indicator, size: 16, color: c.faint),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              ring.name,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.ui(TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: c.ink,
                              )),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            ring.type.name,
                            style: AppFonts.mono(TextStyle(
                              fontSize: 9,
                              letterSpacing: 0.5,
                              color: c.faint,
                            )),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta.toString(),
                        style: AppFonts.mono(TextStyle(fontSize: 10.5, color: c.muted)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _Swatches(ring: ring),
                _TileMenu(onDuplicate: onDuplicate, onDelete: onDelete),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches({required this.ring});
  final Ring ring;

  @override
  Widget build(BuildContext context) {
    final count = ring.isSolid ? 1 : 6;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            Container(width: 8, height: 15, color: ring.materialAt(i).color),
        ],
      ),
    );
  }
}

class _TileMenu extends StatelessWidget {
  const _TileMenu({required this.onDuplicate, this.onDelete});
  final VoidCallback onDuplicate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PopupMenuButton<String>(
      tooltip: 'Ring actions',
      icon: Icon(Icons.more_vert, size: 16, color: c.faint),
      padding: EdgeInsets.zero,
      onSelected: (v) {
        if (v == 'dup') onDuplicate();
        if (v == 'del') onDelete?.call();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'dup', child: Text('Duplicate')),
        if (onDelete != null)
          const PopupMenuItem(value: 'del', child: Text('Delete')),
      ],
    );
  }
}

class _StackSummary extends StatelessWidget {
  const _StackSummary({required this.project, required this.unit});
  final BowlProject project;
  final LengthUnit unit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    TextStyle s(Color col, [FontWeight w = FontWeight.w400]) =>
        AppFonts.mono(TextStyle(fontSize: 11, color: col, fontWeight: w));
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(label, style: s(c.ink), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Text(value, style: s(c.accent, FontWeight.w700)),
            ],
          ),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        children: [
          row('Height', UnitFormat.withUnit(project.totalHeightMm, unit)),
          row('Max ⌀', UnitFormat.withUnit(project.maxOuterDiameterMm, unit)),
          row('Rings · segments', '${project.rings.length} · ${project.totalSegments}'),
        ],
      ),
    );
  }
}
