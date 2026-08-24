class LocationModel {
  const LocationModel({
    required this.id,
    required this.locationName,
    required this.address,
  });

  final String id;
  final String locationName;
  final String address;

  factory LocationModel.fromFirestore(
      String id,
      Map<String, dynamic> data,
      ) {
    return LocationModel(
      id: id,
      locationName: data['locationName'] as String? ?? '',
      address: data['address'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LocationModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}