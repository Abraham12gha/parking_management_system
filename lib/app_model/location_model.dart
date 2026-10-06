class LocationModel {
  const LocationModel({
    required this.id,
    this.numericId = 0,
    required this.locationName,
    required this.address,
    required this.parkingCharges,
    this.graceTimeSeconds = 0,
  });

  final String id;
  final int numericId;
  final String locationName;
  final String address;
  final int parkingCharges;
  final int graceTimeSeconds;

  factory LocationModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final dynamic numId = data['id'];
    final dynamic charges = data['parkingCharges'];
    final dynamic grace = data['graceTimeSeconds'];

    return LocationModel(
      id: id,
      numericId: numId is int ? numId : int.tryParse(numId?.toString() ?? '') ?? 0,
      locationName: data['locationName'] as String? ?? '',
      address: data['address'] as String? ?? '',
      parkingCharges: charges is num ? charges.toInt() : int.tryParse(charges?.toString() ?? '') ?? 0,
      graceTimeSeconds: grace is num ? grace.toInt() : int.tryParse(grace?.toString() ?? '') ?? 0,
    );
  }

  LocationModel copyWith({
    String? id,
    int? numericId,
    String? locationName,
    String? address,
    int? parkingCharges,
    int? graceTimeSeconds,
  }) {
    return LocationModel(
      id: id ?? this.id,
      numericId: numericId ?? this.numericId,
      locationName: locationName ?? this.locationName,
      address: address ?? this.address,
      parkingCharges: parkingCharges ?? this.parkingCharges,
      graceTimeSeconds: graceTimeSeconds ?? this.graceTimeSeconds,
    );
  }

  String get formattedGraceTime {
    if (graceTimeSeconds <= 0) return 'No grace';
    final hours = graceTimeSeconds ~/ 3600;
    final minutes = (graceTimeSeconds % 3600) ~/ 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LocationModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}