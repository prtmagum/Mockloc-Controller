const mockGroups = ['Rumah', 'Kantor', 'Lainnya'];

class MockPoint {
  const MockPoint({
    required this.id,
    required this.name,
    required this.group,
    required this.lat,
    required this.lng,
    this.accuracy = 10,
  });

  final String id;
  final String name;
  final String group; // Rumah, Kantor, Lainnya
  final double lat, lng, accuracy;

  String get coordText => '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';

  MockPoint copyWith({String? name, String? group, double? lat, double? lng, double? accuracy}) => MockPoint(
        id: id,
        name: name ?? this.name,
        group: group ?? this.group,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        accuracy: accuracy ?? this.accuracy,
      );

  Map<String, Object> toJson() => {
        'id': id, 'name': name, 'group': group,
        'lat': lat, 'lng': lng, 'accuracy': accuracy,
      };

  factory MockPoint.fromJson(Map<String, Object?> m) => MockPoint(
        id: m['id'] as String? ?? newPointId(),
        name: m['name'] as String,
        group: m['group'] as String? ?? 'Lainnya',
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        accuracy: (m['accuracy'] as num?)?.toDouble() ?? 10,
      );
}

var _seq = 0;
String newPointId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_seq++).toRadixString(36)}';
