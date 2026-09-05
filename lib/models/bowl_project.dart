import 'material.dart';
import 'ring.dart';
import 'units.dart';

/// The full design document: an ordered stack of rings (index 0 = bottom) plus
/// project-level settings. Immutable; mutations produce a new instance so the
/// controller can keep an undo/redo history cheaply.
class BowlProject {
  const BowlProject({
    required this.name,
    required this.rings,
    this.displayUnit = LengthUnit.mm,
    this.kerfAllowanceMm = 6.0,
    this.targetWallMm = 8.0,
    this.antialias3d = false,
    this.formatVersion = 1,
  });

  final String name;

  /// Rings from bottom (index 0) to top.
  final List<Ring> rings;

  /// Unit used for on-screen display (data is always stored in mm).
  final LengthUnit displayUnit;

  /// Per-segment handling/kerf allowance added to board lengths.
  final double kerfAllowanceMm;

  /// Default target wall thickness for the Auto-fit tool.
  final double targetWallMm;

  /// Whether the 3D view is antialiased (supersampled). A view preference that
  /// travels with the document so it persists across sessions and saves.
  final bool antialias3d;

  final int formatVersion;

  double get totalHeightMm => rings.fold(0.0, (a, r) => a + r.thickness);
  double get maxOuterDiameterMm =>
      rings.isEmpty ? 0.0 : rings.map((r) => r.outerDiameter).reduce((a, b) => a > b ? a : b);
  int get totalSegments => rings.fold(0, (a, r) => a + r.physicalSegmentCount);

  BowlProject copyWith({
    String? name,
    List<Ring>? rings,
    LengthUnit? displayUnit,
    double? kerfAllowanceMm,
    double? targetWallMm,
    bool? antialias3d,
  }) =>
      BowlProject(
        name: name ?? this.name,
        rings: rings ?? this.rings,
        displayUnit: displayUnit ?? this.displayUnit,
        kerfAllowanceMm: kerfAllowanceMm ?? this.kerfAllowanceMm,
        targetWallMm: targetWallMm ?? this.targetWallMm,
        antialias3d: antialias3d ?? this.antialias3d,
        formatVersion: formatVersion,
      );

  Map<String, dynamic> toJson() => {
        'formatVersion': formatVersion,
        'name': name,
        'displayUnit': displayUnit.name,
        'kerfAllowanceMm': kerfAllowanceMm,
        'targetWallMm': targetWallMm,
        'antialias3d': antialias3d,
        'rings': rings.map((r) => r.toJson()).toList(),
      };

  factory BowlProject.fromJson(Map<String, dynamic> json) => BowlProject(
        name: json['name'] as String? ?? 'Untitled',
        displayUnit: LengthUnit.values.firstWhere(
          (u) => u.name == json['displayUnit'],
          orElse: () => LengthUnit.mm,
        ),
        kerfAllowanceMm: (json['kerfAllowanceMm'] as num?)?.toDouble() ?? 6.0,
        targetWallMm: (json['targetWallMm'] as num?)?.toDouble() ?? 8.0,
        antialias3d: json['antialias3d'] as bool? ?? false,
        rings: [
          for (final r in (json['rings'] as List? ?? const []))
            Ring.fromJson(r as Map<String, dynamic>)
        ],
        formatVersion: (json['formatVersion'] as num?)?.toInt() ?? 1,
      );

  /// A ready-to-explore sample vessel (the one shown in the design mockup).
  factory BowlProject.sample() {
    const mapleWalnut = [WoodLibrary.maple, WoodLibrary.walnut];
    const walnutMaple = [WoodLibrary.walnut, WoodLibrary.maple];
    return BowlProject(
      name: 'Maple & Walnut Vessel',
      rings: [
        Ring(
          id: 'r-base',
          name: 'Base disk',
          type: RingType.disk,
          outerDiameter: 130,
          innerDiameter: 0,
          thickness: 19,
          segmentCount: 12,
          pattern: mapleWalnut,
        ),
        Ring(
          id: 'r-c1',
          name: 'Ring 1',
          type: RingType.normal,
          outerDiameter: 186,
          innerDiameter: 130,
          thickness: 25,
          segmentCount: 12,
          pattern: walnutMaple,
        ),
        Ring(
          id: 'r-c2',
          name: 'Ring 2',
          type: RingType.normal,
          outerDiameter: 220,
          innerDiameter: 170,
          thickness: 25,
          segmentCount: 16,
          pattern: mapleWalnut,
        ),
        Ring(
          id: 'r-c3',
          name: 'Ring 3',
          type: RingType.normal,
          outerDiameter: 238,
          innerDiameter: 190,
          thickness: 25,
          segmentCount: 16,
          pattern: walnutMaple,
        ),
        Ring(
          id: 'r-rim',
          name: 'Rim',
          type: RingType.stave,
          outerDiameter: 234,
          innerDiameter: 202,
          thickness: 20,
          segmentCount: 16,
          pattern: mapleWalnut,
        ),
      ],
    );
  }
}
