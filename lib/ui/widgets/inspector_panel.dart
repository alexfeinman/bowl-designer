import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../geometry/ring_geometry.dart';
import '../../models/material.dart';
import '../../models/ring.dart';
import '../../models/units.dart';
import '../../state/project_controller.dart';
import '../shortcuts.dart';
import '../theme.dart';

/// Right pane: edit the selected ring plus the Auto-fit walls tool.
class InspectorPanel extends ConsumerWidget {
  const InspectorPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final ring = ref.watch(selectedRingProvider);
    final unit = ref.watch(displayUnitProvider);

    return Container(
      decoration: BoxDecoration(
        color: c.panel,
        border: Border(left: BorderSide(color: c.border)),
      ),
      child: ring == null
          ? Center(
              child: Text('Select a ring',
                  style: AppFonts.ui(TextStyle(color: c.muted))))
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              children: [
                Text(
                  ring.name,
                  style: AppFonts.display(TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  )),
                ),
                const SizedBox(height: 14),
                _TypeSelector(ring: ring),
                const SizedBox(height: 14),
                _Dimensions(ring: ring, unit: unit),
                const SizedBox(height: 14),
                _Materials(ring: ring),
                const SizedBox(height: 14),
                _AutoFit(unit: unit),
                const SizedBox(height: 14),
                const _ShortcutCard(),
              ],
            ),
    );
  }
}

class _Fieldset extends StatelessWidget {
  const _Fieldset({required this.legend, required this.children, this.dashed = false});
  final String legend;
  final List<Widget> children;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dashed ? c.accentSoft : c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: dashed ? c.accent : c.border,
          style: dashed ? BorderStyle.solid : BorderStyle.solid,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Text(
              legend.toUpperCase(),
              style: AppFonts.ui(TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: c.accent,
              )),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _TypeSelector extends ConsumerWidget {
  const _TypeSelector({required this.ring});
  final Ring ring;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(projectControllerProvider.notifier);
    return _Fieldset(
      legend: 'Type',
      children: [
        Row(
          children: [
            for (final t in RingType.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: _TypeButton(
                    type: t,
                    selected: ring.type == t,
                    onTap: () => ctrl.updateRing(ring.id, (r) {
                      // Disks have no hole; give a new hole when leaving disk.
                      if (t == RingType.disk) {
                        return r.copyWith(type: t, innerDiameter: 0);
                      }
                      final id = r.innerDiameter <= 0
                          ? (r.outerDiameter - 40).clamp(0.0, r.outerDiameter - 1)
                          : r.innerDiameter;
                      return r.copyWith(type: t, innerDiameter: id);
                    }),
                  ),
                ),
              ),
          ],
        ),
        if (ring.type == RingType.compound || ring.type == RingType.stave) ...[
          const SizedBox(height: 10),
          _CompoundAngle(ring: ring),
        ],
      ],
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({required this.type, required this.selected, required this.onTap});
  final RingType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = selected ? c.accent : c.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: selected ? c.accentSoft : c.surface,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: selected ? c.accent : c.borderStrong),
        ),
        child: Column(
          children: [
            Icon(_icon(type), size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              type.label,
              style: AppFonts.ui(TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              )),
            ),
          ],
        ),
      ),
    );
  }

  IconData _icon(RingType t) => switch (t) {
        RingType.disk => Icons.circle,
        RingType.normal => Icons.circle_outlined,
        RingType.compound => Icons.change_history,
        RingType.stave => Icons.view_column_outlined,
      };
}

class _CompoundAngle extends ConsumerWidget {
  const _CompoundAngle({required this.ring});
  final Ring ring;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final ctrl = ref.read(projectControllerProvider.notifier);
    final label = ring.type == RingType.stave ? 'Stave taper' : 'Wall angle';
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: AppFonts.ui(TextStyle(fontSize: 11, color: c.muted))),
        ),
        SizedBox(
          width: 120,
          child: Slider(
            value: ring.wallAngle.clamp(0, 45),
            min: 0,
            max: 45,
            onChanged: (v) => ctrl.updateRing(ring.id, (r) => r.copyWith(wallAngle: v)),
          ),
        ),
        Text('${ring.wallAngle.toStringAsFixed(0)}°',
            style: AppFonts.mono(TextStyle(fontSize: 11, color: c.ink))),
      ],
    );
  }
}

class _Dimensions extends ConsumerWidget {
  const _Dimensions({required this.ring, required this.unit});
  final Ring ring;
  final LengthUnit unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final ctrl = ref.read(projectControllerProvider.notifier);
    final miter = ring.isSolid
        ? '—'
        : '${RingGeometry.miterForRing(ring).toStringAsFixed(2)}°';

    return _Fieldset(
      legend: 'Dimensions',
      children: [
        _DimRow(
          label: 'Outer diameter',
          hint: '← →',
          valueMm: ring.outerDiameter,
          unit: unit,
          onChanged: (mm) => ctrl.updateRing(ring.id, (r) {
            final od = mm.clamp(1.0, 100000.0);
            return r.copyWith(
              outerDiameter: od,
              innerDiameter: r.innerDiameter.clamp(0.0, od - 1),
            );
          }),
        ),
        if (ring.type != RingType.disk)
          _DimRow(
            label: 'Inner diameter',
            hint: '⇧← ⇧→',
            valueMm: ring.innerDiameter,
            unit: unit,
            onChanged: (mm) => ctrl.updateRing(
                ring.id,
                (r) => r.copyWith(
                    innerDiameter: mm.clamp(0.0, r.outerDiameter - 1))),
          ),
        _DimRow(
          label: 'Thickness (ring height)',
          hint: '[ ]',
          valueMm: ring.thickness,
          unit: unit,
          onChanged: (mm) => ctrl.updateRing(
              ring.id, (r) => r.copyWith(thickness: mm.clamp(1.0, 100000.0))),
        ),
        _IntRow(
          label: 'Segments',
          hint: '− +',
          value: ring.segmentCount,
          min: 1,
          onChanged: (n) =>
              ctrl.updateRing(ring.id, (r) => r.copyWith(segmentCount: n)),
        ),
        if (!ring.isSolid)
          _DimRow(
            label: 'Gap between segments',
            hint: '',
            valueMm: ring.gapMm,
            unit: unit,
            onChanged: (mm) => ctrl.updateRing(
                ring.id, (r) => r.copyWith(gapMm: mm.clamp(0.0, 100000.0))),
          ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            style: AppFonts.ui(TextStyle(fontSize: 11, color: c.muted)),
            children: [
              const TextSpan(text: 'Miter angle '),
              TextSpan(
                  text: miter,
                  style: TextStyle(color: c.accent, fontWeight: FontWeight.w700)),
              const TextSpan(text: '  ·  wall '),
              TextSpan(text: UnitFormat.withUnit(ring.width, unit)),
            ],
          ),
        ),
      ],
    );
  }
}

/// A length field: text entry (in the active unit) plus +/- steppers.
class _DimRow extends StatelessWidget {
  const _DimRow({
    required this.label,
    required this.hint,
    required this.valueMm,
    required this.unit,
    required this.onChanged,
  });
  final String label;
  final String hint;
  final double valueMm;
  final LengthUnit unit;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final step = UnitFormat.coarseStep(unit);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: label, hint: hint),
          const SizedBox(height: 5),
          _Stepper(
            child: _NumField(
              text: UnitFormat.value(valueMm, unit),
              suffix: unit.label,
              onSubmit: (v) {
                final parsed = double.tryParse(v);
                if (parsed != null) onChanged(unit.toMm(parsed));
              },
            ),
            onMinus: () => onChanged((valueMm - step).clamp(0.0, 1e9)),
            onPlus: () => onChanged(valueMm + step),
          ),
        ],
      ),
    );
  }
}

class _IntRow extends StatelessWidget {
  const _IntRow({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
    this.min = 0,
  });
  final String label;
  final String hint;
  final int value;
  final int min;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: label, hint: hint),
          const SizedBox(height: 5),
          _Stepper(
            child: _NumField(
              text: '$value',
              onSubmit: (v) {
                final parsed = int.tryParse(v);
                if (parsed != null && parsed >= min) onChanged(parsed);
              },
            ),
            onMinus: () => onChanged((value - 1).clamp(min, 100000)),
            onPlus: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.hint});
  final String label;
  final String? hint;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: AppFonts.ui(TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: c.faint,
            )),
          ),
        ),
        if (hint != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: c.borderStrong),
            ),
            child: Text(hint!,
                style: AppFonts.mono(TextStyle(fontSize: 9.5, color: c.muted))),
          ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.child, required this.onMinus, required this.onPlus});
  final Widget child;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget btn(IconData icon, VoidCallback onTap) => InkWell(
          onTap: onTap,
          child: Container(
            width: 28,
            alignment: Alignment.center,
            color: c.panel,
            child: Icon(icon, size: 15, color: c.muted),
          ),
        );
    return Container(
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: c.borderStrong),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          btn(Icons.remove, onMinus),
          Expanded(child: child),
          btn(Icons.add, onPlus),
        ],
      ),
    );
  }
}

/// A numeric text field that syncs to an external value when not focused.
class _NumField extends ConsumerStatefulWidget {
  const _NumField({required this.text, required this.onSubmit, this.suffix});
  final String text;
  final String? suffix;
  final ValueChanged<String> onSubmit;

  @override
  ConsumerState<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends ConsumerState<_NumField> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.text);
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    // Suspend global resize shortcuts while typing in a field.
    ref.read(editingTextProvider.notifier).state = _focus.hasFocus;
  }

  @override
  void didUpdateWidget(covariant _NumField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && widget.text != _ctrl.text) {
      _ctrl.text = widget.text;
    }
  }

  @override
  void dispose() {
    if (_focus.hasFocus) {
      ref.read(editingTextProvider.notifier).state = false;
    }
    _focus.removeListener(_onFocusChange);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextField(
      controller: _ctrl,
      focusNode: _focus,
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))],
      style: AppFonts.mono(TextStyle(fontSize: 12.5, color: c.ink)),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        suffixText: widget.suffix,
        suffixStyle: AppFonts.mono(TextStyle(fontSize: 10.5, color: c.faint)),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
      onSubmitted: widget.onSubmit,
      onTapOutside: (_) {
        widget.onSubmit(_ctrl.text);
        _focus.unfocus();
      },
    );
  }
}

class _Materials extends ConsumerWidget {
  const _Materials({required this.ring});
  final Ring ring;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final ctrl = ref.read(projectControllerProvider.notifier);
    final pattern = ring.pattern.isEmpty ? [WoodLibrary.maple] : ring.pattern;

    void setPattern(List<SegmentMaterial> p) =>
        ctrl.updateRing(ring.id, (r) => r.copyWith(pattern: p));

    return _Fieldset(
      legend: 'Material · pattern',
      children: [
        for (var i = 0; i < pattern.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: pattern[i].color,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: c.borderStrong),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: pattern[i].id,
                    isDense: true,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        isDense: true, border: OutlineInputBorder()),
                    style: AppFonts.ui(TextStyle(fontSize: 12, color: c.ink)),
                    items: [
                      for (final m in WoodLibrary.all)
                        DropdownMenuItem(value: m.id, child: Text(m.name)),
                    ],
                    onChanged: (id) {
                      if (id == null) return;
                      final next = [...pattern]..[i] = WoodLibrary.byId(id);
                      setPattern(next);
                    },
                  ),
                ),
                if (pattern.length > 1)
                  IconButton(
                    tooltip: 'Remove',
                    iconSize: 16,
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        setPattern([...pattern]..removeAt(i)),
                    icon: Icon(Icons.close, color: c.faint),
                  ),
              ],
            ),
          ),
        if (pattern.length < 6)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setPattern([...pattern, WoodLibrary.all[pattern.length % WoodLibrary.all.length]]),
              icon: const Icon(Icons.add, size: 15),
              label: const Text('Add wood to pattern'),
              style: TextButton.styleFrom(foregroundColor: c.accent),
            ),
          ),
      ],
    );
  }
}

class _AutoFit extends ConsumerStatefulWidget {
  const _AutoFit({required this.unit});
  final LengthUnit unit;
  @override
  ConsumerState<_AutoFit> createState() => _AutoFitState();
}

class _AutoFitState extends ConsumerState<_AutoFit> {
  WallFitMode _mode = WallFitMode.followProfile;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final project = ref.watch(projectProvider);
    final ctrl = ref.read(projectControllerProvider.notifier);

    return _Fieldset(
      legend: '⚟ Auto-fit walls',
      dashed: true,
      children: [
        Text("Set every ring's inner diameter for a uniform turned wall.",
            style: AppFonts.ui(TextStyle(fontSize: 11, color: c.muted))),
        const SizedBox(height: 10),
        _FieldLabel(label: 'Target wall thickness'),
        const SizedBox(height: 5),
        _Stepper(
          child: _NumField(
            text: UnitFormat.value(project.targetWallMm, widget.unit),
            suffix: widget.unit.label,
            onSubmit: (v) {
              final parsed = double.tryParse(v);
              if (parsed != null) {
                ctrl.setTargetWall(widget.unit.toMm(parsed).clamp(0.5, 1000.0));
              }
            },
          ),
          onMinus: () => _bump(-UnitFormat.coarseStep(widget.unit)),
          onPlus: () => _bump(UnitFormat.coarseStep(widget.unit)),
        ),
        const SizedBox(height: 10),
        _FieldLabel(label: 'Mode'),
        const SizedBox(height: 5),
        DropdownButtonFormField<WallFitMode>(
          value: _mode,
          isDense: true,
          isExpanded: true,
          decoration:
              const InputDecoration(isDense: true, border: OutlineInputBorder()),
          style: AppFonts.ui(TextStyle(fontSize: 12, color: c.ink)),
          items: const [
            DropdownMenuItem(
                value: WallFitMode.followProfile, child: Text('Follow outer profile')),
            DropdownMenuItem(
                value: WallFitMode.verticalWall, child: Text('Vertical wall (straight bore)')),
          ],
          onChanged: (m) => setState(() => _mode = m ?? _mode),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: c.accent, foregroundColor: c.accentInk),
            onPressed: () =>
                ctrl.autoFitWalls(project.targetWallMm, _mode),
            child: const Text('Apply to all rings'),
          ),
        ),
      ],
    );
  }

  void _bump(double deltaMm) {
    final project = ref.read(projectProvider);
    final next = (project.targetWallMm + deltaMm).clamp(0.5, 1000.0);
    ref.read(projectControllerProvider.notifier).setTargetWall(next);
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard();
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget row(String label, String keys) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: AppFonts.ui(TextStyle(fontSize: 11.5, color: c.muted))),
              Text(keys,
                  style: AppFonts.mono(TextStyle(fontSize: 10.5, color: c.ink))),
            ],
          ),
        );
    return _Fieldset(
      legend: 'Resize shortcuts',
      children: [
        row('Nudge OD', '← →'),
        row('Nudge ID', '⇧← ⇧→'),
        row('Thickness', '[ ]  ↑ ↓'),
        row('Segments', '− +'),
        row('Fine step', '⌥ + arrow'),
        row('Undo / Redo', '⌘Z  ⇧⌘Z'),
      ],
    );
  }
}
