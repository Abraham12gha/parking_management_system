import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_model/parking_ticket_model.dart';

/// Central high-performance cache and real-time synchronization service.
/// Eliminates redundant Firestore reads and ensures instant propagation of
/// admin updates (such as grace time and charges) to all active operators.
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
  final ValueNotifier<int> graceTimeNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> parkingChargesNotifier = ValueNotifier<int>(0);

  // Cached Tickets
  List<ParkingTicketModel> _cachedActiveTickets = [];
  final Set<String> _activePlatesSet = <String>{};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _activeTicketsSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _locationSub;

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

  /// Fast in-memory duplicate plate check for high-traffic entry barriers.
  bool isVehicleAlreadyIn(String vehicleNumber) {
    final clean = vehicleNumber.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    return _activePlatesSet.contains(clean);
  }

  /// Pre-warms operator profile, location settings, and active tickets stream.
  /// Subscribes to real-time location changes so admin grace time changes
  /// immediately reflect across all active operators without reloading.
  Future<void> preloadForCurrentUser({bool force = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      clear();
      return;
    }

    // If a different user logged in, clear stale data first
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

        // 2. Fetch & attach real-time listener to location doc
        await _attachLocationListener(locId);

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

  /// Attaches a real-time listener to the location document.
  /// When admin updates grace time or charges, all operators receive it instantly.
  Future<void> _attachLocationListener(String locId) async {
    _locationSub?.cancel();

    // Initial read
    try {
      final locDoc = await _firestore.collection('locations').doc(locId).get();
      if (locDoc.exists) {
        _applyLocationData(locDoc.data() ?? {});
      }
    } catch (e) {
      debugPrint('Initial location fetch error: $e');
    }

    // Real-time updates subscription
    _locationSub = _firestore
        .collection('locations')
        .doc(locId)
        .snapshots()
        .listen(
      (snapshot) {
        if (!snapshot.exists) return;
        final data = snapshot.data() ?? {};
        _applyLocationData(data);
      },
      onError: (err) {
        debugPrint('Location settings stream error: $err');
      },
    );
  }

  void _applyLocationData(Map<String, dynamic> locData) {
    _locationName = locData['locationName']?.toString() ?? _locationName ?? '';

    final dynamic numId = locData['id'];
    _locationNumericId = numId is int
        ? numId
        : int.tryParse(numId?.toString() ?? '') ?? 0;

    final dynamic charges = locData['parkingCharges'];
    final newCharges = charges is num
        ? charges.toInt()
        : int.tryParse(charges?.toString() ?? '') ?? 0;

    final dynamic grace = locData['graceTimeSeconds'];
    final newGrace = grace is num
        ? grace.toInt()
        : int.tryParse(grace?.toString() ?? '') ?? 0;

    final bool chargesChanged = _parkingCharges != newCharges;
    final bool graceChanged = _graceTimeSeconds != newGrace;

    _parkingCharges = newCharges;
    _graceTimeSeconds = newGrace;

    if (chargesChanged) parkingChargesNotifier.value = newCharges;
    if (graceChanged) graceTimeNotifier.value = newGrace;

    // Cache into local preferences asynchronously so offline mode is consistent
    _persistPreferences(newCharges, newGrace);
  }

  Future<void> _persistPreferences(int charges, int grace) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('parking_charges', charges);
      await prefs.setInt('grace_time_seconds', grace);
    } catch (_) {}
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

        // Update in-memory plate index for instantaneous duplicate checks
        _activePlatesSet.clear();
        for (final ticket in list) {
          final clean = ticket.vehicleNumber.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
          if (clean.isNotEmpty) {
            _activePlatesSet.add(clean);
          }
        }

        activeTicketsNotifier.value = list;
      },
      onError: (err) {
        debugPrint('Active tickets stream error: $err');
      },
    );
  }

  /// System-wide active tickets stream (used by Admin Dashboard)
  Stream<List<ParkingTicketModel>> systemWideActiveTicketsStream({String? locationId}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('parking_tickets')
        .where('status', isEqualTo: 'in');

    if (locationId != null && locationId.isNotEmpty && locationId != 'ALL') {
      query = query.where('locationId', isEqualTo: locationId);
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => ParkingTicketModel.fromFirestore(doc))
          .toList(),
    );
  }

  /// Stream of all tickets for the assigned location
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
      } catch (_) {
        // Optional archive access
      }

      var list = [
        ...activeSnapshot.docs,
        ...?completedSnapshot?.docs,
      ]
          .map((doc) => ParkingTicketModel.fromFirestore(doc))
          .toList();

      // Precision date filtering
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
    _activePlatesSet.clear();
    _activeTicketsSub?.cancel();
    _activeTicketsSub = null;
    _locationSub?.cancel();
    _locationSub = null;
    isReadyNotifier.value = false;
    graceTimeNotifier.value = 0;
    parkingChargesNotifier.value = 0;
    activeTicketsNotifier.value = [];
  }
}
