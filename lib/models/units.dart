/// Measurement units. All lengths are stored canonically in millimetres and
/// converted to the active display unit only at the presentation edge.
enum LengthUnit {
  mm('mm', 1.0),
  inch('in', 25.4);

  const LengthUnit(this.label, this.mmPerUnit);

  /// Short suffix shown in the UI (e.g. `mm`, `in`).
  final String label;

  /// How many millimetres one of these units represents.
  final double mmPerUnit;

  /// Convert a canonical millimetre value into this unit.
  double fromMm(double mm) => mm / mmPerUnit;

  /// Convert a value expressed in this unit back into canonical millimetres.
  double toMm(double value) => value * mmPerUnit;
}

/// Formatting helpers for showing millimetre values in the active unit.
class UnitFormat {
  const UnitFormat._();

  /// Format [mm] in [unit] for compact display (no trailing suffix).
  ///
  /// Millimetres round to whole numbers; inches use two decimals.
  static String value(double mm, LengthUnit unit) {
    final v = unit.fromMm(mm);
    switch (unit) {
      case LengthUnit.mm:
        return v.roundToDouble() == v ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
      case LengthUnit.inch:
        return v.toStringAsFixed(2);
    }
  }

  /// Format [mm] in [unit] including the unit suffix (e.g. `220 mm`, `8.66 in`).
  static String withUnit(double mm, LengthUnit unit) =>
      '${value(mm, unit)} ${unit.label}';

  /// Sensible keyboard-nudge step in millimetres for the active unit.
  /// Coarse is the default arrow-key step; fine is used with a modifier.
  static double coarseStep(LengthUnit unit) => unit == LengthUnit.mm ? 2.0 : 25.4 / 16; // 1/16"
  static double fineStep(LengthUnit unit) => unit == LengthUnit.mm ? 0.5 : 25.4 / 64; // 1/64"
}
