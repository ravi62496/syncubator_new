class OxygenModel {
  final int level;
  final bool moving;

  OxygenModel({
    required this.level,
    required this.moving,
  });

  factory OxygenModel.fromJson(Map<String, dynamic> json) {
    return OxygenModel(
      level: json['level'] as int? ?? 0,
      moving: json['moving'] as bool? ?? false,
    );
  }

  OxygenModel copyWith({
    int? level,
    bool? moving,
  }) {
    return OxygenModel(
      level: level ?? this.level,
      moving: moving ?? this.moving,
    );
  }
}
