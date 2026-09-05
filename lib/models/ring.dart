import 'material.dart';

/// The construction style of a ring (course) in the stack.
enum RingType {
  /// A solid layer with no inner hole (ID = 0), still cut from N pie wedges.
  /// Only truly solid (single board, no miter) when [Ring.segmentCount] == 1.
  disk,

  /// A standard flat-laid ring of N trapezoidal wedge segments with a hole.
  normal,

  /// Like [normal] but the wall is tilted by [Ring.wallAngle] (a cone frustum).
  compound,

  /// Vertical staves (barrel style): N staves stood on end, beveled on the
  /// long edges.
  stave;

  String get label => switch (this) {
        RingType.disk => 'Disk',
        RingType.normal => 'Ring',
        RingType.compound => 'Compound',
        RingType.stave => 'Stave',
      };
}

/// A single course in the bowl, immutable. Diameters and thickness are stored
/// in canonical millimetres.
class Ring {
  Ring({
    required this.id,
    required this.name,
    required this.type,
    required this.outerDiameter,
    required this.innerDiameter,
    required this.thickness,
    required this.segmentCount,
    this.gapMm = 0.0,
    this.wallAngle = 0.0,
    this.pattern = const [WoodLibrary.maple, WoodLibrary.walnut],
    this.overrides = const {},
  });

  /// Stable identity, used as a widget key and for selection.
  final String id;
  final String name;
  final RingType type;

  /// Outer diameter in mm.
  final double outerDiameter;

  /// Inner diameter in mm. Always 0 for [RingType.disk].
  final double innerDiameter;

  /// Course height (board thickness) in mm.
  final double thickness;

  /// Number of segments around the full circle.
  final int segmentCount;

  /// Gap left between each pair of adjacent segments (open-segment ring),
  /// measured along the outer edge in mm. 0 = a closed, tight ring.
  final double gapMm;

  /// Wall tilt in degrees for [RingType.compound]; 0 otherwise.
  final double wallAngle;

  /// Repeating material sequence applied around the ring.
  final List<SegmentMaterial> pattern;

  /// Per-position material overrides (win over [pattern]).
  final Map<int, SegmentMaterial> overrides;

  /// True inner diameter, forced to 0 for disks.
  double get effectiveInnerDiameter => type == RingType.disk ? 0.0 : innerDiameter;

  /// Radial wall width in mm.
  double get width => (outerDiameter - effectiveInnerDiameter) / 2.0;

  /// Whether this ring is a single solid board (no miters).
  bool get isSolid => type == RingType.disk && segmentCount <= 1;

  /// Number of physical segments to cut.
  int get physicalSegmentCount => isSolid ? 1 : segmentCount;

  /// Angular width (radians) of the gap between segments at the outer edge.
  double get gapAngle {
    final ro = outerDiameter / 2;
    if (ro <= 0 || gapMm <= 0) return 0.0;
    return (gapMm / ro).clamp(0.0, (2 * 3.141592653589793 / segmentCount) * 0.9);
  }

  /// Resolve the material at [position], honouring overrides then the pattern.
  SegmentMaterial materialAt(int position) {
    final o = overrides[position];
    if (o != null) return o;
    if (pattern.isEmpty) return WoodLibrary.maple;
    return pattern[position % pattern.length];
  }

  Ring copyWith({
    String? id,
    String? name,
    RingType? type,
    double? outerDiameter,
    double? innerDiameter,
    double? thickness,
    int? segmentCount,
    double? gapMm,
    double? wallAngle,
    List<SegmentMaterial>? pattern,
    Map<int, SegmentMaterial>? overrides,
  }) =>
      Ring(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        outerDiameter: outerDiameter ?? this.outerDiameter,
        innerDiameter: innerDiameter ?? this.innerDiameter,
        thickness: thickness ?? this.thickness,
        segmentCount: segmentCount ?? this.segmentCount,
        gapMm: gapMm ?? this.gapMm,
        wallAngle: wallAngle ?? this.wallAngle,
        pattern: pattern ?? this.pattern,
        overrides: overrides ?? this.overrides,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'outerDiameter': outerDiameter,
        'innerDiameter': innerDiameter,
        'thickness': thickness,
        'segmentCount': segmentCount,
        'gapMm': gapMm,
        'wallAngle': wallAngle,
        'pattern': pattern.map((m) => m.toJson()).toList(),
        'overrides':
            overrides.map((k, v) => MapEntry(k.toString(), v.toJson())),
      };

  factory Ring.fromJson(Map<String, dynamic> json) => Ring(
        id: json['id'] as String,
        name: json['name'] as String,
        type: RingType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => RingType.normal,
        ),
        outerDiameter: (json['outerDiameter'] as num).toDouble(),
        innerDiameter: (json['innerDiameter'] as num).toDouble(),
        thickness: (json['thickness'] as num).toDouble(),
        segmentCount: (json['segmentCount'] as num).toInt(),
        gapMm: (json['gapMm'] as num?)?.toDouble() ?? 0.0,
        wallAngle: (json['wallAngle'] as num?)?.toDouble() ?? 0.0,
        pattern: [
          for (final m in (json['pattern'] as List? ?? const []))
            SegmentMaterial.fromJson(m as Map<String, dynamic>)
        ],
        overrides: {
          for (final e in (json['overrides'] as Map? ?? const {}).entries)
            int.parse(e.key as String):
                SegmentMaterial.fromJson(e.value as Map<String, dynamic>)
        },
      );
}
