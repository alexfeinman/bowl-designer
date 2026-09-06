import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/units.dart';
import '../state/project_controller.dart';
import 'theme.dart';

/// A dedicated full-screen settings page. Grouped, extensible sections.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final aa = ref.watch(antialias3dProvider);
    final grain = ref.watch(woodGrainProvider);
    final unit = ref.watch(displayUnitProvider);
    final ctrl = ref.read(projectControllerProvider.notifier);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.ink,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: c.border)),
        title: Text('Settings',
            style: AppFonts.display(TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: c.ink))),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _label(context, '3D VIEW'),
              _card(c, [
                SwitchListTile(
                  value: aa,
                  onChanged: ctrl.setAntialias3d,
                  activeColor: c.accent,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text('Antialiasing',
                      style: AppFonts.ui(TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.ink))),
                  subtitle: Text(
                      'Smoother edges in the 3D view. Supersamples the render, '
                      'so it is a little slower.',
                      style:
                          AppFonts.ui(TextStyle(fontSize: 12, color: c.muted))),
                ),
                Divider(height: 1, color: c.border),
                SwitchListTile(
                  value: grain,
                  onChanged: ctrl.setWoodGrain,
                  activeColor: c.accent,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text('Wood grain',
                      style: AppFonts.ui(TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.ink))),
                  subtitle: Text(
                      'Overlay photographic per-species grain on the 3D bowl '
                      'instead of flat colours. Scaled to each segment.',
                      style:
                          AppFonts.ui(TextStyle(fontSize: 12, color: c.muted))),
                ),
              ]),
              const SizedBox(height: 24),
              _label(context, 'UNITS'),
              _card(c, [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Measurement units',
                            style: AppFonts.ui(TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: c.ink))),
                      ),
                      _UnitChoice(unit: unit, onChanged: ctrl.setDisplayUnit),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              Text(
                'More settings will live here as the app grows.',
                style: AppFonts.ui(TextStyle(fontSize: 12, color: c.faint)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text,
            style: AppFonts.ui(TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: context.colors.faint))),
      );

  Widget _card(BowlColors c, List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );
}

class _UnitChoice extends StatelessWidget {
  const _UnitChoice({required this.unit, required this.onChanged});
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
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
