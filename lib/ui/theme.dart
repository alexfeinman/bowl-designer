import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Extra design tokens beyond Material's ColorScheme, mirroring the approved
/// mockup (workshop-CAD chrome, oak/amber accent).
@immutable
class BowlColors extends ThemeExtension<BowlColors> {
  const BowlColors({
    required this.bg,
    required this.panel,
    required this.surface,
    required this.viewBg,
    required this.viewDark,
    required this.grid,
    required this.border,
    required this.borderStrong,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.accentSoft,
    required this.accentInk,
    required this.danger,
    required this.ok,
  });

  final Color bg, panel, surface, viewBg, viewDark, grid, border, borderStrong;
  final Color ink, muted, faint, accent, accentSoft, accentInk, danger, ok;

  static const light = BowlColors(
    bg: Color(0xFFE9E6E0),
    panel: Color(0xFFF6F4EF),
    surface: Color(0xFFFFFFFF),
    viewBg: Color(0xFFFBFAF6),
    viewDark: Color(0xFF211D18),
    grid: Color(0xFFE4DFD5),
    border: Color(0xFFD7D1C6),
    borderStrong: Color(0xFFC3BBAC),
    ink: Color(0xFF2B2823),
    muted: Color(0xFF726B5E),
    faint: Color(0xFF9A9284),
    accent: Color(0xFFB0741B),
    accentSoft: Color(0xFFF0E3CC),
    accentInk: Color(0xFFFFFFFF),
    danger: Color(0xFFA63D2E),
    ok: Color(0xFF4C7A3F),
  );

  static const dark = BowlColors(
    bg: Color(0xFF16130F),
    panel: Color(0xFF201C16),
    surface: Color(0xFF262119),
    viewBg: Color(0xFF1B1712),
    viewDark: Color(0xFF120F0B),
    grid: Color(0xFF2C2720),
    border: Color(0xFF37312A),
    borderStrong: Color(0xFF4A4238),
    ink: Color(0xFFECE6DB),
    muted: Color(0xFFA0978A),
    faint: Color(0xFF6F675B),
    accent: Color(0xFFD9A441),
    accentSoft: Color(0xFF38301F),
    accentInk: Color(0xFF1B1712),
    danger: Color(0xFFE08A75),
    ok: Color(0xFF8CBE7B),
  );

  @override
  BowlColors copyWith({
    Color? bg,
    Color? panel,
    Color? surface,
    Color? viewBg,
    Color? viewDark,
    Color? grid,
    Color? border,
    Color? borderStrong,
    Color? ink,
    Color? muted,
    Color? faint,
    Color? accent,
    Color? accentSoft,
    Color? accentInk,
    Color? danger,
    Color? ok,
  }) =>
      BowlColors(
        bg: bg ?? this.bg,
        panel: panel ?? this.panel,
        surface: surface ?? this.surface,
        viewBg: viewBg ?? this.viewBg,
        viewDark: viewDark ?? this.viewDark,
        grid: grid ?? this.grid,
        border: border ?? this.border,
        borderStrong: borderStrong ?? this.borderStrong,
        ink: ink ?? this.ink,
        muted: muted ?? this.muted,
        faint: faint ?? this.faint,
        accent: accent ?? this.accent,
        accentSoft: accentSoft ?? this.accentSoft,
        accentInk: accentInk ?? this.accentInk,
        danger: danger ?? this.danger,
        ok: ok ?? this.ok,
      );

  @override
  BowlColors lerp(ThemeExtension<BowlColors>? other, double t) {
    if (other is! BowlColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return BowlColors(
      bg: c(bg, other.bg),
      panel: c(panel, other.panel),
      surface: c(surface, other.surface),
      viewBg: c(viewBg, other.viewBg),
      viewDark: c(viewDark, other.viewDark),
      grid: c(grid, other.grid),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      ink: c(ink, other.ink),
      muted: c(muted, other.muted),
      faint: c(faint, other.faint),
      accent: c(accent, other.accent),
      accentSoft: c(accentSoft, other.accentSoft),
      accentInk: c(accentInk, other.accentInk),
      danger: c(danger, other.danger),
      ok: c(ok, other.ok),
    );
  }
}

/// Typeface helpers: Fraunces (display/title), Archivo (UI), JetBrains Mono
/// (measurements & data).
class AppFonts {
  const AppFonts._();
  static TextStyle display(TextStyle base) => GoogleFonts.fraunces(textStyle: base);
  static TextStyle ui(TextStyle base) => GoogleFonts.archivo(textStyle: base);
  static TextStyle mono(TextStyle base) => GoogleFonts.jetBrainsMono(textStyle: base);
}

ThemeData buildBowlTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final c = isDark ? BowlColors.dark : BowlColors.light;

  final scheme = ColorScheme.fromSeed(
    seedColor: c.accent,
    brightness: brightness,
  ).copyWith(
    surface: c.surface,
    onSurface: c.ink,
    primary: c.accent,
    onPrimary: c.accentInk,
    error: c.danger,
  );

  final baseText = GoogleFonts.archivoTextTheme(
    ThemeData(brightness: brightness).textTheme,
  ).apply(bodyColor: c.ink, displayColor: c.ink);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    textTheme: baseText,
    dividerColor: c.border,
    extensions: [c],
    tooltipTheme: TooltipThemeData(
      textStyle: AppFonts.ui(TextStyle(color: c.surface, fontSize: 11)),
      decoration: BoxDecoration(
        color: c.ink,
        borderRadius: BorderRadius.circular(6),
      ),
    ),
  );
}

/// Shortcut to read the custom palette from a context.
extension BowlColorsX on BuildContext {
  BowlColors get colors => Theme.of(this).extension<BowlColors>()!;
}
