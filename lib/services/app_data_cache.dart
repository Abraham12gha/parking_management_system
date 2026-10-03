import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../app_model/parking_ticket_model.dart';

/// Central high-performance cache and pre-warming service.
/// Eliminates redundant Firestore reads and eliminates loading spinners during working hours.
class AppDataCache {
  AppDataCache._();
  static final AppDataCache instance = AppDataCache._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cached User & Location State
  String? _operatorId;
  String? _operatorName;
  String? _locationId;
  String? _locationName;
  int _locationNumericId = 0;
  int _parkingCharges = 0;
  int _graceTimeSeconds = 0;
  String? _userRole;

  bool _isLoaded = false;
  bool _isLoading = false;

  final ValueNotifier<bool> isReadyNotifier = ValueNotifier<bool>(false);

  // Cached Tickets
  List<ParkingTicketModel> _cachedActiveTickets = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _activeTicketsSub;
  final ValueNotifier<List<ParkingTicketModel>> activeTicketsNotifier =
      ValueNotifier<List<ParkingTicketModel>>([]);

  // Getters
  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;
  String? get operatorId => _operatorId;
  String? get operatorName => _operatorName;
  String? get locationId => _locationId;
  String? get locationName => _locationName;
  int get locationNumericId => _locationNumericId;
  int get parkingCharges => _parkingCharges;
  int get graceTimeSeconds => _graceTimeSeconds;
  String? get userRole => _userRole;

  List<ParkingTicketModel> get cachedActiveTickets => _cachedActiveTickets;

  /// Pre-warms operator profile, location settings, and active tickets stream.
  /// Call this on app startup or immediately when dashboard mounts.
  Future<void> preloadForCurrentUser({bool force = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      clear();
      return;
    }

    // If a different operator logged in, clear all stale data first
    if (_operatorId != null && _operatorId != user.uid) {
      clear();
    }

    if (!force && _isLoaded && _operatorId == user.uid && _locationId != null) {
      return;
    }

    _isLoading = true;
    _operatorId = user.uid;

    try {
      // 1. Fetch user doc
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        _isLoading = false;
        return;
      }

      final userData = userDoc.data() ?? {};
      _userRole = userData['role']?.toString();
      _operatorName = (userData['firstName'] ?? userData['name'] ?? '').toString();
      final locId = userData['location']?.toString().trim();

      if (locId != null && locId.isNotEmpty) {
        _locationId = locId;

        // 2. Fetch location doc
        final locDoc =
            await _firestore.collection('locations').doc(locId).get();
        if (locDoc.exists) {
          final locData = locDoc.data() ?? {};
          _locationName = locData['locationName']?.toString() ?? '';

          final dynamic numId = locData['id'];
          _locationNumericId = numId is int
              ? numId
              : int.tryParse(numId?.toString() ?? '') ?? 0;

          final dynamic charges = locData['parkingCharges'];
          _parkingCharges = charges is num
              ? charges.toInt()
              : int.tryParse(charges?.toString() ?? '') ?? 0;

          final dynamic grace = locData['graceTimeSeconds'];
          _graceTimeSeconds = grace is num
              ? grace.toInt()
              : int.tryParse(grace?.toString() ?? '') ?? 0;
        }

        // 3. Pre-warm active tickets stream
        _listenToActiveTickets(locId);
      }

      _isLoaded = true;
      isReadyNotifier.value = true;
    } catch (e) {
      debugPrint('AppDataCache preload error: $e');
    } finally {
      _isLoading = false;
    }
  }

  void _listenToActiveTickets(String locId) {
    _activeTicketsSub?.cancel();
    _activeTicketsSub = _firestore
        .collection('parking_tickets')
        .where('locationId', isEqualTo: locId)
        .where('status', isEqualTo: 'in')
        .snapshots()
        .listen(
      (snapshot) {
        final list = snapshot.docs
            .map((doc) => ParkingTicketModel.fromFirestore(doc))
            .toList();
        _cachedActiveTickets = list;
        activeTicketsNotifier.value = list;
      },
      onError: (err) {
        debugPrint('Active tickets stream error: $err');
      },
    );
  }

  /// Stream of all tickets for the assigned location (for real-time dashboard stats & updates)
  Stream<List<ParkingTicketModel>> ticketsStream({String? specificLocationId}) {
    final locId = specificLocationId ?? _locationId;
    if (locId == null || locId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection('parking_tickets')
        .where('locationId', isEqualTo: locId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ParkingTicketModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Fetch tickets within a date range for reports and analytics with local cache speed
  Future<List<ParkingTicketModel>> getTickets({
    String? specificLocationId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    final locId = specificLocationId ?? _locationId;
    Query<Map<String, dynamic>> query =
        _firestore.collection('parking_tickets');

    if (locId != null && locId.isNotEmpty && locId != 'ALL') {
      query = query.where('locationId', isEqualTo: locId);
    }

    if (limit != null && limit > 0) {
      query = query.limit(limit);
    }

    try {
      final activeSnapshot = await query.get(
        const GetOptions(source: Source.serverAndCache),
      );
      // Older checkouts were moved to `backup`. Some deployments permit
      // writes there but deny reads, so an archive denial must not discard
      // readable active/history tickets from parking_tickets.
      QuerySnapshot<Map<String, dynamic>>? completedSnapshot;
      try {
          Query<Map<String, dynamic>> completedQuery =
              _firestore.collection('backup');
          if (locId != null && locId.isNotEmpty && locId != 'ALL') {
            completedQuery = completedQuery.where('locationId', isEqualTo: locId);
          }
          if (limit != null && limit > 0) completedQuery = completedQuery.limit(limit);
          completedSnapshot = await completedQuery.get(
            const GetOptions(source: Source.serverAndCache),
          );
      } catch (error) {
          // Legacy archive access is optional; primary ticket history remains
          // usable when rules deny reads from `backup`.
      }
      var list = [
        ...activeSnapshot.docs,
        ...?completedSnapshot?.docs,
      ]
          .map((doc) => ParkingTicketModel.fromFirestore(doc))
          .toList();

      // Local date filtering for precision and avoiding complex composite index requirement
      if (startDate != null) {
        list = list.where((t) {
          final time = (t.status.toLowerCase() == 'in' ? t.startTime : t.endTime)?.toDate() ?? t.startTime?.toDate();
          if (time == null) return false;
          return !time.isBefore(startDate);
        }).toList();
      }

      if (endDate != null) {
        list = list.where((t) {
          final time = (t.status.toLowerCase() == 'in' ? t.startTime : t.endTime)?.toDate() ?? t.startTime?.toDate();
          if (time == null) return false;
          return !time.isAfter(endDate);
        }).toList();
      }

      // Sort newest first
      list.sort((a, b) {
        final aTime = a.startTime?.toDate() ?? DateTime(2000);
        final bTime = b.startTime?.toDate() ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });

      return list;
    } catch (e) {
      debugPrint('Error fetching tickets in AppDataCache: $e');
      return [];
    }
  }

  void clear() {
    _operatorId = null;
    _operatorName = null;
    _locationId = null;
    _locationName = null;
    _locationNumericId = 0;
    _parkingCharges = 0;
    _graceTimeSeconds = 0;
    _userRole = null;
    _isLoaded = false;
    _isLoading = false;
    _cachedActiveTickets.clear();
    _activeTicketsSub?.cancel();
    _activeTicketsSub = null;
    isReadyNotifier.value = false;
    activeTicketsNotifier.value = [];
  }
}
