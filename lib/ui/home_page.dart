import 'dart:convert';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bowl_project.dart';
import '../models/units.dart';
import '../state/project_controller.dart';
import '../state/project_io.dart';
import 'settings_page.dart';
import 'shortcuts.dart';
import 'theme.dart';
import 'views/view_area.dart';
import 'widgets/inspector_panel.dart';
import 'widgets/ring_list_panel.dart';

/// App-wide theme mode toggle.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) => handleBowlKey(ref, event),
        child: DropTarget(
          onDragEntered: (_) => setState(() => _dragging = true),
          onDragExited: (_) => setState(() => _dragging = false),
          onDragDone: (detail) => _onDrop(detail),
          child: Stack(
            children: [
              Column(
                children: [
                  const _TopBar(),
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, _) {
                        final maximized = ref.watch(viewMaximizedProvider);
                        if (maximized) return const ViewArea();
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: const [
                            SizedBox(width: 250, child: RingListPanel()),
                            Expanded(child: ViewArea()),
                            SizedBox(width: 300, child: InspectorPanel()),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (_dragging) _DropOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onDrop(DropDoneDetails detail) async {
    setState(() => _dragging = false);
    if (detail.files.isEmpty) return;
    try {
      final content = await detail.files.first.readAsString();
      final project = BowlProject.fromJson(jsonDecode(content) as Map<String, dynamic>);
      ref.read(projectControllerProvider.notifier).loadProject(project);
      _selectTop();
      _toast('Imported “${project.name}”.');
    } catch (_) {
      _toast('Could not read that file — expected a .sbowl / JSON design.');
    }
  }

  void _selectTop() {
    final rings = ref.read(projectProvider).rings;
    if (rings.isNotEmpty) {
      ref.read(selectionControllerProvider.notifier).select(rings.last.id);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final history = ref.watch(projectControllerProvider);
    final ctrl = ref.read(projectControllerProvider.notifier);
    final unit = ref.watch(displayUnitProvider);
    final mode = ref.watch(themeModeProvider);

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          const _BrandMark(),
          const SizedBox(width: 10),
          Text('Segmented Bowl Designer',
              style: AppFonts.display(TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600, color: c.ink))),
          const SizedBox(width: 9),
          const Flexible(child: _EditableProjectName()),
          const Spacer(),
          _IconBtn(
            icon: Icons.undo,
            tooltip: 'Undo (⌘Z)',
            enabled: history.canUndo,
            onTap: ctrl.undo,
          ),
          _IconBtn(
            icon: Icons.redo,
            tooltip: 'Redo (⇧⌘Z)',
            enabled: history.canRedo,
            onTap: ctrl.redo,
          ),
          _divider(c),
          _UnitToggle(unit: unit, onChanged: ctrl.setDisplayUnit),
          _divider(c),
          _IconBtn(
            icon: mode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
            tooltip: 'Toggle theme',
            enabled: true,
            onTap: () => ref.read(themeModeProvider.notifier).state =
                mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
          ),
          _IconBtn(
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            enabled: true,
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _open(context, ref),
            icon: const Icon(Icons.folder_open, size: 16),
            label: const Text('Open'),
            style: OutlinedButton.styleFrom(
                foregroundColor: c.ink, side: BorderSide(color: c.borderStrong)),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _save(context, ref),
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Save'),
            style: FilledButton.styleFrom(
                backgroundColor: c.accent, foregroundColor: c.accentInk),
          ),
        ],
      ),
    );
  }

  Widget _divider(BowlColors c) => Container(
        width: 1,
        height: 22,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: c.border,
      );

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    try {
      final ctrl = ref.read(projectControllerProvider.notifier);
      final saved =
          await ProjectIo.save(ref.read(projectProvider), ctrl.suggestedExportBase());
      ctrl.noteExportFilename('', saved);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(saved != null ? 'Design saved.' : 'Save cancelled.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    try {
      final project = await ProjectIo.open();
      if (project == null) return;
      ref.read(projectControllerProvider.notifier).loadProject(project);
      final rings = ref.read(projectProvider).rings;
      if (rings.isNotEmpty) {
        ref.read(selectionControllerProvider.notifier).select(rings.last.id);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Opened “${project.name}”.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Open failed: $e')));
      }
    }
  }
}

/// The design name shown in the top bar. Click to rename in place; the name
/// seeds the suggested filename when saving/exporting.
class _EditableProjectName extends ConsumerStatefulWidget {
  const _EditableProjectName();
  @override
  ConsumerState<_EditableProjectName> createState() =>
      _EditableProjectNameState();
}

class _EditableProjectNameState extends ConsumerState<_EditableProjectName> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    // Suspend global resize shortcuts while typing, and commit on focus loss.
    ref.read(editingTextProvider.notifier).state = _focus.hasFocus;
    if (!_focus.hasFocus && _editing) _commit();
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

  void _start(String current) {
    _ctrl.text = current;
    _ctrl.selection =
        TextSelection(baseOffset: 0, extentOffset: current.length);
    setState(() => _editing = true);
    _focus.requestFocus();
  }

  void _commit() {
    final name = _ctrl.text.trim();
    final current = ref.read(projectProvider).name;
    if (name.isNotEmpty && name != current) {
      ref.read(projectControllerProvider.notifier).rename(name);
    }
    if (mounted) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final name = ref.watch(projectProvider).name;
    if (_editing) {
      return SizedBox(
        width: 240,
        child: TextField(
          controller: _ctrl,
          focusNode: _focus,
          autofocus: true,
          style: AppFonts.ui(TextStyle(fontSize: 12, color: c.ink)),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: c.borderStrong),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: c.accent),
            ),
          ),
          onSubmitted: (_) => _commit(),
          onTapOutside: (_) => _commit(),
        ),
      );
    }
    return Tooltip(
      message: 'Rename design',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _start(name),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text('· $name',
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppFonts.ui(TextStyle(fontSize: 12, color: c.muted))),
              ),
              const SizedBox(width: 5),
              Icon(Icons.edit_outlined, size: 12, color: c.faint),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  const _UnitToggle({required this.unit, required this.onChanged});
  final LengthUnit unit;
  final ValueChanged<LengthUnit> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget seg(LengthUnit u, String label) {
      final on = unit == u;
      return InkWell(
        onTap: () => onChanged(u),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: on ? c.accent : c.surface,
          child: Text(label,
              style: AppFonts.mono(TextStyle(
                fontSize: 12,
                fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                color: on ? c.accentInk : c.muted,
              ))),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: c.borderStrong)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          seg(LengthUnit.mm, 'mm'),
          Container(width: 1, color: c.borderStrong),
          seg(LengthUnit.inch, 'inch'),
        ]),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return IconButton(
      tooltip: tooltip,
      onPressed: enabled ? onTap : null,
      iconSize: 18,
      color: c.muted,
      disabledColor: c.faint.withValues(alpha: 0.4),
      icon: Icon(icon),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _MarkPainter(c.accent, c.accentSoft)),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.accent, this.soft);
  final Color accent;
  final Color soft;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    canvas.drawCircle(center, size.width / 2, Paint()..color = soft);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = accent;
    canvas.drawCircle(center, size.width / 2 - 0.8, ring);
    canvas.drawCircle(center, size.width / 2 - 5, ring);
    canvas.drawCircle(center, 1.6, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) =>
      old.accent != accent || old.soft != soft;
}

class _DropOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Positioned.fill(
      child: Container(
        color: c.accent.withValues(alpha: 0.12),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.accent, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.file_download_outlined, color: c.accent, size: 34),
                const SizedBox(height: 10),
                Text('Drop a .sbowl design to import',
                    style: AppFonts.ui(TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: c.ink))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
