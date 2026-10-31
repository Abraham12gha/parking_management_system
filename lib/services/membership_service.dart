import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_model/parking_membership_model.dart';
import 'offline_ticket_store.dart';
import 'tenant_context.dart';

class MembershipService {
  MembershipService._();
  static final MembershipService instance = MembershipService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OfflineTicketStore _store = OfflineTicketStore.instance;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _locationSubscriptions = {};

  void preloadLocation(String locationId) {
    if (_locationSubscriptions.containsKey(locationId)) return;
    _locationSubscriptions[locationId] = TenantContext.instance
        .collection('memberships', firestore: _firestore)
        .where('locationId', isEqualTo: locationId)
        .snapshots()
        .listen(
          (snapshot) {
            for (final doc in snapshot.docs) {
              _store.cacheRemoteMembership(doc.id, locationId, doc.data());
            }
          },
          onError: (Object error) {
            // Keep the last SQLite membership snapshot for offline entry checks.
          },
        );
  }

  void stopLocationPreloads() {
    for (final subscription in _locationSubscriptions.values) {
      subscription.cancel();
    }
    _locationSubscriptions.clear();
  }

  Stream<List<ParkingMembership>> watchMemberships() {
    late StreamController<List<ParkingMembership>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? remoteSub;
    var cancelled = false;
    Future<void> publish() async {
      if (kIsWeb) return;
      final records = await _store.allMemberships();
      final memberships =
          records
              .map(
                (record) =>
                    ParkingMembership.fromMap(record['id'].toString(), record),
              )
              .toList()
            ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
      if (!controller.isClosed) controller.add(memberships);
    }

    void onLocalChange() => publish();
    controller = StreamController<List<ParkingMembership>>.broadcast(
      onListen: () {
        _store.membershipsRevision.addListener(onLocalChange);
        publish();
        unawaited(
          _attachRemoteListener(
            () => publish(),
            (memberships) => controller.add(memberships),
            (subscription) {
              if (cancelled) {
                subscription.cancel();
              } else {
                remoteSub = subscription;
              }
            },
          ),
        );
      },
      onCancel: () {
        cancelled = true;
        remoteSub?.cancel();
        _store.membershipsRevision.removeListener(onLocalChange);
      },
    );
    return controller.stream;
  }

  Future<void> _attachRemoteListener(
    Future<void> Function() publish,
    void Function(List<ParkingMembership>) emit,
    void Function(StreamSubscription<QuerySnapshot<Map<String, dynamic>>>)
    onReady,
  ) async {
    try {
      if (!TenantContext.instance.isReady) {
        await TenantContext.instance.loadForCurrentUser();
      }
      Query<Map<String, dynamic>> query = TenantContext.instance.collection(
        'memberships',
        firestore: _firestore,
      );
      if (TenantContext.instance.role == 'operator') {
        final locationId = TenantContext.instance.locationId;
        if (locationId == null || locationId.isEmpty) {
          await publish();
          return;
        }
        query = query.where('locationId', isEqualTo: locationId);
      }
      final subscription = query.snapshots().listen((snapshot) {
        if (kIsWeb) {
          emit(
            snapshot.docs
                .map((doc) => ParkingMembership.fromMap(doc.id, doc.data()))
                .toList(),
          );
          return;
        }
        for (final doc in snapshot.docs) {
          final locationId = doc.data()['locationId']?.toString() ?? '';
          _store.cacheRemoteMembership(doc.id, locationId, doc.data());
        }
        publish();
      }, onError: (_) => publish());
      onReady(subscription);
    } catch (_) {
      await publish();
    }
  }

  Future<ParkingMembership> createMembership({
    required String fullName,
    required String vehicleNumber,
    required String phoneNumber,
    required String email,
    required String locationId,
    required String locationName,
    required int durationMonths,
    required double amount,
  }) async {
    final cleanName = fullName.trim();
    final plate = vehicleNumber.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    final phone = phoneNumber.trim();
    if (cleanName.isEmpty || phone.isEmpty || locationId.isEmpty) {
      throw ArgumentError('Name, phone, and parking location are required.');
    }
    if (!RegExp(r'^[A-Z0-9-]{3,12}$').hasMatch(plate)) {
      throw ArgumentError(
        'Vehicle number must be 3–12 letters, numbers, or dashes.',
      );
    }
    if (durationMonths < 1 || durationMonths > 600) {
      throw ArgumentError('Duration must be between 1 and 600 months.');
    }
    if (!amount.isFinite || amount < 0) {
      throw ArgumentError('Enter a valid membership amount.');
    }

    Map<String, dynamic>? existingData;
    if (kIsWeb) {
      final existingSnapshot = await TenantContext.instance
          .collection('memberships', firestore: _firestore)
          .where('locationId', isEqualTo: locationId)
          .get();
      final matching = existingSnapshot.docs.where(
        (doc) =>
            (doc.data()['vehicleNumber'] ?? '').toString().toUpperCase() ==
                plate &&
            doc.data()['status'] == 'active',
      );
      if (matching.isNotEmpty) {
        existingData = {'id': matching.first.id, ...matching.first.data()};
      }
    } else {
      existingData = await _store.membershipByVehicle(locationId, plate);
    }
    if (existingData != null) {
      final existing = ParkingMembership.fromMap(
        existingData['id'].toString(),
        existingData,
      );
      if (existing.isValidAt(DateTime.now())) {
        throw StateError(
          'An unexpired membership already exists for this vehicle.',
        );
      }
    }

    if (!kIsWeb) {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.any((state) => state != ConnectivityResult.none)) {
        try {
          final remote = await TenantContext.instance
              .collection('memberships', firestore: _firestore)
              .where('locationId', isEqualTo: locationId)
              .get(const GetOptions(source: Source.server));
          final now = DateTime.now();
          final duplicate = remote.docs.any((doc) {
            final data = doc.data();
            final existingPlate = (data['vehicleNumber'] ?? '')
                .toString()
                .toUpperCase();
            final startsAt = data['startsAt'] is Timestamp
                ? (data['startsAt'] as Timestamp).toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);
            final expiresAt = data['expiresAt'] is Timestamp
                ? (data['expiresAt'] as Timestamp).toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);
            return existingPlate == plate &&
                data['status'] == 'active' &&
                !now.isBefore(startsAt) &&
                now.isBefore(expiresAt);
          });
          if (duplicate) {
            throw StateError(
              'An unexpired membership already exists for this vehicle.',
            );
          }
        } on StateError {
          rethrow;
        } catch (_) {
          // Firebase can be unreachable even when a network interface exists.
          // Keep the local SQLite write path available in that case.
        }
      }
    }

    final now = DateTime.now();
    final end = _addMonthsClamped(now, durationMonths);
    final id = 'member_${_store.newId()}';
    final user = FirebaseAuth.instance.currentUser;
    final membership = ParkingMembership(
      id: id,
      fullName: cleanName,
      vehicleNumber: plate,
      phoneNumber: phone,
      email: email.trim(),
      locationId: locationId,
      locationName: locationName,
      durationMonths: durationMonths,
      amount: amount,
      startsAt: now,
      expiresAt: end,
      status: 'active',
    );
    final data = membership.toMap()
      ..['createdAt'] = now.toIso8601String()
      ..['updatedAt'] = now.toIso8601String()
      ..['createdBy'] = user?.uid ?? ''
      ..['_tenantCompanyId'] = TenantContext.instance.companyId;
    if (kIsWeb) {
      final firestoreData = Map<String, dynamic>.from(data)
        ..remove('_tenantCompanyId')
        ..['startsAt'] = Timestamp.fromDate(now)
        ..['expiresAt'] = Timestamp.fromDate(end)
        ..['createdAt'] = Timestamp.fromDate(now)
        ..['updatedAt'] = FieldValue.serverTimestamp();
      await TenantContext.instance
          .collection('memberships', firestore: _firestore)
          .doc(id)
          .set(firestoreData);
    } else {
      await _store.saveMembership(id, data, locationId: locationId);
      unawaited(_store.syncPending());
    }
    return membership;
  }

  Future<ParkingMembership?> findValidMembershipForVehicle({
    required String locationId,
    required String vehicleNumber,
  }) async {
    Map<String, dynamic>? record;
    if (kIsWeb) {
      final plate = vehicleNumber.toUpperCase().replaceAll(RegExp(r'\s+'), '');
      final snapshot = await TenantContext.instance
          .collection('memberships', firestore: _firestore)
          .where('locationId', isEqualTo: locationId)
          .get();
      final matching = snapshot.docs.where(
        (doc) =>
            (doc.data()['vehicleNumber'] ?? '').toString().toUpperCase() ==
                plate &&
            doc.data()['status'] == 'active',
      );
      if (matching.isNotEmpty) {
        record = {'id': matching.first.id, ...matching.first.data()};
      }
    } else {
      record = await _store.membershipByVehicle(locationId, vehicleNumber);
    }
    if (record == null) return null;
    final membership = ParkingMembership.fromMap(
      record['id'].toString(),
      record,
    );
    return membership.isValidAt(DateTime.now()) ? membership : null;
  }

  Future<ParkingMembership?> getMembership(String id) async {
    Map<String, dynamic>? record;
    if (kIsWeb) {
      final doc = await TenantContext.instance
          .collection('memberships', firestore: _firestore)
          .doc(id)
          .get();
      if (doc.exists) record = {'id': doc.id, ...?doc.data()};
    } else {
      record = await _store.membershipById(id);
    }
    if (record == null) return null;
    return ParkingMembership.fromMap(id, record);
  }

  Future<void> setMembershipActive(
    ParkingMembership membership, {
    required bool active,
  }) async {
    final status = active ? 'active' : 'inactive';
    if (kIsWeb) {
      await TenantContext.instance
          .collection('memberships', firestore: _firestore)
          .doc(membership.id)
          .update({
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
            'deactivatedAt': active
                ? FieldValue.delete()
                : FieldValue.serverTimestamp(),
          });
      return;
    }
    await _store.setMembershipStatus(
      membership.id,
      status,
      locationId: membership.locationId,
    );
    unawaited(_store.syncPending());
  }

  DateTime _addMonthsClamped(DateTime start, int months) {
    final monthIndex = start.year * 12 + (start.month - 1) + months;
    final year = monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = start.day > lastDay ? lastDay : start.day;
    return DateTime(year, month, day, start.hour, start.minute, start.second);
  }
}

final membershipServiceProvider = Provider<MembershipService>(
  (ref) => MembershipService.instance,
);

final membershipsProvider = StreamProvider<List<ParkingMembership>>(
  (ref) => ref.watch(membershipServiceProvider).watchMemberships(),
);
