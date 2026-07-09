class WeightModel {
  final double value;
  final String unit;
  final DateTime timestamp;

  WeightModel({
    required this.value,
    required this.unit,
    required this.timestamp,
  });

  factory WeightModel.fromJson(Map<String, dynamic> json) {
    return WeightModel(
      value: (json['weight'] as num).toDouble(),
      unit: json['unit'] as String? ?? 'kg',
      timestamp: DateTime.now(),
    );
  }
}