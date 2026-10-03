import 'package:cloud_firestore/cloud_firestore.dart';

class ParkingTicketModel {
  final String id;

  final String ticketNumber;

  final String vehicleCategory;
  final String vehicleNumber;

  final String driverName;
  final String phoneNumber;
  final String notes;

  final String locationId;
  final int locationNumericId;
  final String locationName;

  final String operatorId;
  final String entryOperatorId;
  final String entryOperatorName;
  final String exitOperatorId;
  final String exitOperatorName;

  final Timestamp? startTime;
  final Timestamp? endTime;

  final int graceTimeSeconds;
  final double parkingCharges;

  final double charges;

  final String status;
  final String date;

  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  const ParkingTicketModel({
    required this.id,
    required this.ticketNumber,
    required this.vehicleCategory,
    required this.vehicleNumber,
    required this.driverName,
    required this.phoneNumber,
    required this.notes,
    required this.locationId,
    required this.locationNumericId,
    required this.locationName,
    required this.operatorId,
    this.entryOperatorId = '',
    this.entryOperatorName = '',
    this.exitOperatorId = '',
    this.exitOperatorName = '',
    required this.startTime,
    required this.endTime,
    required this.graceTimeSeconds,
    required this.parkingCharges,
    required this.charges,
    required this.status,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ParkingTicketModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? {};

    return ParkingTicketModel(
      id: doc.id,
      ticketNumber: data['ticketNumber'] as String? ?? '',
      vehicleCategory: data['vehicleCategory'] as String? ?? '',
      vehicleNumber: data['vehicleNumber'] as String? ?? '',
      driverName: data['driverName'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
      notes: data['notes'] as String? ?? 'clear',

      locationId: data['locationId'] as String? ?? '',
      locationNumericId:
      (data['locationNumericId'] as num?)?.toInt() ?? 0,
      locationName: data['locationName'] as String? ?? '',

      operatorId: data['operatorId'] as String? ?? '',
      entryOperatorId: data['entryOperatorId'] as String? ??
          data['operatorId'] as String? ?? '',
      entryOperatorName: data['entryOperatorName'] as String? ?? '',
      exitOperatorId: data['exitOperatorId'] as String? ?? '',
      exitOperatorName: data['exitOperatorName'] as String? ?? '',

      startTime: data['startTime'] as Timestamp?,
      endTime: data['endTime'] as Timestamp?,

      graceTimeSeconds:
      (data['graceTimeSeconds'] as num?)?.toInt() ?? 0,

      parkingCharges:
      (data['parkingCharges'] as num?)?.toDouble() ?? 0,

      charges:
          ((data['checkoutAmount'] ??
                      data['finalParkingCharges'] ??
                      data['charges'])
                  as num?)
              ?.toDouble() ??
          0,

      status: data['status'] as String? ?? 'in',
      date: data['date'] as String? ?? '',

      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ticketNumber': ticketNumber,

      'vehicleCategory': vehicleCategory,
      'vehicleNumber': vehicleNumber,

      'driverName': driverName,
      'phoneNumber': phoneNumber,
      'notes': notes,

      'locationId': locationId,
      'locationNumericId': locationNumericId,
      'locationName': locationName,

      'operatorId': operatorId,
      'entryOperatorId': entryOperatorId.isEmpty ? operatorId : entryOperatorId,
      'entryOperatorName': entryOperatorName,
      'exitOperatorId': exitOperatorId,
      'exitOperatorName': exitOperatorName,

      'startTime': startTime,
      'endTime': endTime,

      'graceTimeSeconds': graceTimeSeconds,
      'parkingCharges': parkingCharges,

      'charges': charges,

      'status': status,
      'date': date,

      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  ParkingTicketModel copyWith({
    String? id,
    String? ticketNumber,
    String? vehicleCategory,
    String? vehicleNumber,
    String? driverName,
    String? phoneNumber,
    String? notes,
    String? locationId,
    int? locationNumericId,
    String? locationName,
    String? operatorId,
    String? entryOperatorId,
    String? entryOperatorName,
    String? exitOperatorId,
    String? exitOperatorName,
    Timestamp? startTime,
    Timestamp? endTime,
    int? graceTimeSeconds,
    double? parkingCharges,
    double? charges,
    String? status,
    String? date,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return ParkingTicketModel(
      id: id ?? this.id,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      vehicleCategory: vehicleCategory ?? this.vehicleCategory,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      driverName: driverName ?? this.driverName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      notes: notes ?? this.notes,
      locationId: locationId ?? this.locationId,
      locationNumericId: locationNumericId ?? this.locationNumericId,
      locationName: locationName ?? this.locationName,
      operatorId: operatorId ?? this.operatorId,
      entryOperatorId: entryOperatorId ?? this.entryOperatorId,
      entryOperatorName: entryOperatorName ?? this.entryOperatorName,
      exitOperatorId: exitOperatorId ?? this.exitOperatorId,
      exitOperatorName: exitOperatorName ?? this.exitOperatorName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      graceTimeSeconds:
      graceTimeSeconds ?? this.graceTimeSeconds,
      parkingCharges:
      parkingCharges ?? this.parkingCharges,
      charges: charges ?? this.charges,
      status: status ?? this.status,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
