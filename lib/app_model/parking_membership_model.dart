import 'package:cloud_firestore/cloud_firestore.dart';

class ParkingMembership {
  const ParkingMembership({
    required this.id,
    required this.fullName,
    required this.vehicleNumber,
    required this.phoneNumber,
    required this.email,
    required this.locationId,
    required this.locationName,
    required this.durationMonths,
    required this.amount,
    required this.startsAt,
    required this.expiresAt,
    required this.status,
  });

  final String id;
  final String fullName;
  final String vehicleNumber;
  final String phoneNumber;
  final String email;
  final String locationId;
  final String locationName;
  final int durationMonths;
  final double amount;
  final DateTime startsAt;
  final DateTime expiresAt;
  final String status;

  bool isValidAt(DateTime time) =>
      status == 'active' && !time.isBefore(startsAt) && time.isBefore(expiresAt);

  String get qrPayload => 'PARK-MEMBER:$id';

  factory ParkingMembership.fromMap(String id, Map<String, dynamic> data) {
    DateTime dateValue(dynamic value, {DateTime? fallback}) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? fallback ?? DateTime.now();
      return fallback ?? DateTime.now();
    }

    return ParkingMembership(
      id: id,
      fullName: data['fullName']?.toString() ?? '',
      vehicleNumber: data['vehicleNumber']?.toString() ?? '',
      phoneNumber: data['phoneNumber']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      locationId: data['locationId']?.toString() ?? '',
      locationName: data['locationName']?.toString() ?? '',
      durationMonths: (data['durationMonths'] as num?)?.toInt() ?? 0,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      startsAt: dateValue(data['startsAt']),
      expiresAt: dateValue(data['expiresAt']),
      status: data['status']?.toString() ?? 'active',
    );
  }

  Map<String, dynamic> toMap() => {
    'fullName': fullName,
    'vehicleNumber': vehicleNumber,
    'phoneNumber': phoneNumber,
    'email': email,
    'locationId': locationId,
    'locationName': locationName,
    'durationMonths': durationMonths,
    'amount': amount,
    'startsAt': startsAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'status': status,
  };
}
