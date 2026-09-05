import 'package:flutter/painting.dart';

/// A wood (or other) species used for a segment, carrying a representative
/// render colour and optional cost for board-foot estimates.
class SegmentMaterial {
  const SegmentMaterial({
    required this.id,
    required this.name,
    required this.colorValue,
    this.costPerBoardFoot,
  });

  /// Stable identifier (also used as a JSON key).
  final String id;

  /// Human-readable species name.
  final String name;

  /// ARGB colour value used when rendering segments.
  final int colorValue;

  /// Optional cost per board-foot in the project's currency.
  final double? costPerBoardFoot;

  Color get color => Color(colorValue);

  SegmentMaterial copyWith({
    String? id,
    String? name,
    int? colorValue,
    double? costPerBoardFoot,
  }) =>
      SegmentMaterial(
        id: id ?? this.id,
        name: name ?? this.name,
        colorValue: colorValue ?? this.colorValue,
        costPerBoardFoot: costPerBoardFoot ?? this.costPerBoardFoot,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': colorValue,
        if (costPerBoardFoot != null) 'costPerBoardFoot': costPerBoardFoot,
      };

  factory SegmentMaterial.fromJson(Map<String, dynamic> json) => SegmentMaterial(
        id: json['id'] as String,
        name: json['name'] as String,
        colorValue: json['color'] as int,
        costPerBoardFoot: (json['costPerBoardFoot'] as num?)?.toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      other is SegmentMaterial &&
      other.id == id &&
      other.name == name &&
      other.colorValue == colorValue &&
      other.costPerBoardFoot == costPerBoardFoot;

  @override
  int get hashCode => Object.hash(id, name, colorValue, costPerBoardFoot);
}

/// A small default library of common turning woods with representative colours.
class WoodLibrary {
  const WoodLibrary._();

  static const maple = SegmentMaterial(id: 'maple', name: 'Hard maple', colorValue: 0xFFE8D5A8);
  static const walnut = SegmentMaterial(id: 'walnut', name: 'Black walnut', colorValue: 0xFF5A3E2B);
  static const cherry = SegmentMaterial(id: 'cherry', name: 'Cherry', colorValue: 0xFFA9603C);
  static const padauk = SegmentMaterial(id: 'padauk', name: 'Padauk', colorValue: 0xFFB5431F);
  static const wenge = SegmentMaterial(id: 'wenge', name: 'Wenge', colorValue: 0xFF3B2F2A);
  static const purpleheart =
      SegmentMaterial(id: 'purpleheart', name: 'Purpleheart', colorValue: 0xFF5C3B6E);
  static const oak = SegmentMaterial(id: 'oak', name: 'White oak', colorValue: 0xFFC7A76A);
  static const ash = SegmentMaterial(id: 'ash', name: 'Ash', colorValue: 0xFFD8C5A0);

  /// The full palette offered in dropdowns.
  static const List<SegmentMaterial> all = [
    maple,
    walnut,
    cherry,
    padauk,
    wenge,
    purpleheart,
    oak,
    ash,
  ];

  /// Look up a library material by id, falling back to maple.
  static SegmentMaterial byId(String id) =>
      all.firstWhere((m) => m.id == id, orElse: () => maple);
}
