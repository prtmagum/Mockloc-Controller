class LocationFix {
  const LocationFix({
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.time,
    this.altitude,
    this.speed,
    this.bearing,
    this.isMock = false,
  });

  final double lat, lng, accuracy;
  final double? altitude, speed, bearing;
  final DateTime time;
  final bool isMock;

  /// Payload untuk backend. `isMock` selalu dikirim (FR-09) supaya backend
  /// produksi bisa menolak fix palsu.
  Map<String, Object?> toJson() => {
        'lat': lat,
        'lng': lng,
        'accuracy': accuracy,
        'altitude': altitude,
        'speed': speed,
        'bearing': bearing,
        'time': time.toUtc().toIso8601String(),
        'isMock': isMock,
      };

  factory LocationFix.fromJson(Map<String, Object?> m) => LocationFix(
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        accuracy: (m['accuracy'] as num).toDouble(),
        altitude: (m['altitude'] as num?)?.toDouble(),
        speed: (m['speed'] as num?)?.toDouble(),
        bearing: (m['bearing'] as num?)?.toDouble(),
        time: DateTime.parse(m['time'] as String),
        isMock: m['isMock'] as bool? ?? false,
      );

  @override
  String toString() =>
      'LocationFix(${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}, '
      '±${accuracy.toStringAsFixed(0)} m${isMock ? ', mock' : ''})';
}
