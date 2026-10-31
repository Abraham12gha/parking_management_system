import 'dart:convert';
import 'dart:math';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'tenant_context.dart';

/// Durable local ticket cache and retry queue. Every operator write is stored
/// here before it is acknowledged to the screen; Firestore is the remote copy.
class OfflineTicketStore {
  OfflineTicketStore._();
  static final OfflineTicketStore instance = OfflineTicketStore._();

  Database? _database;
  Future<Database>? _openingDatabase;
  bool _syncing = false;
  Timer? _retryTimer;
  String? _databaseFilePath;
  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> ticketsRevision = ValueNotifier<int>(0);
  final ValueNotifier<int> membershipsRevision = ValueNotifier<int>(0);

  String? get databaseFilePath => _databaseFilePath;
  Future<String> getDatabaseFilePath() async {
    await _db;
    return _databaseFilePath!;
  }

  Future<Database> get _db {
    if (_database != null) return Future.value(_database!);
    return _openingDatabase ??= _openDatabase();
  }

  Future<Database> _openDatabase() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dir = await getApplicationSupportDirectory();
    _databaseFilePath = p.join(dir.path, 'parking_offline.db');
    _database = await openDatabase(
      _databaseFilePath!,
      version: 3,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE tickets (id TEXT PRIMARY KEY, location_id TEXT NOT NULL, status TEXT NOT NULL, data TEXT NOT NULL, pending INTEGER NOT NULL DEFAULT 1)',
        );
        await db.execute(
          'CREATE TABLE memberships (id TEXT PRIMARY KEY, location_id TEXT NOT NULL, vehicle_key TEXT NOT NULL, data TEXT NOT NULL, pending INTEGER NOT NULL DEFAULT 0)',
        );
        await db.execute(
          'CREATE INDEX memberships_vehicle_idx ON memberships(location_id, vehicle_key)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Older builds cleared this flag when Firestore only accepted a
          // local queued write. Requeue local-generated IDs for server ack.
          await db.rawUpdate(
            "UPDATE tickets SET pending = 1 WHERE id GLOB 'offline_*'",
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'CREATE TABLE memberships (id TEXT PRIMARY KEY, location_id TEXT NOT NULL, vehicle_key TEXT NOT NULL, data TEXT NOT NULL, pending INTEGER NOT NULL DEFAULT 0)',
          );
          await db.execute(
            'CREATE INDEX memberships_vehicle_idx ON memberships(location_id, vehicle_key)',
          );
        }
      },
    );
    return _database!;
  }

  String newId() =>
      'offline_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32).toRadixString(16)}';

  Future<void> save(
    Map<String, dynamic> data, {
    required String id,
    required String locationId,
    bool pending = true,
  }) async {
    final stored = Map<String, dynamic>.from(data);
    stored.putIfAbsent(
      '_tenantCompanyId',
      () => TenantContext.instance.companyId,
    );
    for (final key in ['startTime', 'endTime', 'createdAt', 'updatedAt']) {
      final value = stored[key];
      if (value is Timestamp) stored[key] = value.toDate().toIso8601String();
      if (value is DateTime) stored[key] = value.toIso8601String();
    }
    if (stored['startTime'] is String)
      stored['_startIso'] = stored['startTime'];
    await (await _db).insert('tickets', {
      'id': id,
      'location_id': locationId,
      'status': stored['status'] ?? 'in',
      'data': jsonEncode(stored),
      'pending': pending ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _refreshPendingCount();
    ticketsRevision.value++;
  }

  Future<List<Map<String, dynamic>>> active(String locationId) async {
    final rows = await (await _db).query(
      'tickets',
      where: 'location_id = ? AND status = ?',
      whereArgs: [locationId, 'in'],
    );
    return rows
        .map(
          (row) => {
            'id': row['id'],
            ...Map<String, dynamic>.from(jsonDecode(row['data'] as String)),
          },
        )
        .toList();
  }

  Future<Set<String>> localTicketIds(String locationId) async {
    final rows = await (await _db).query(
      'tickets',
      columns: ['id'],
      where: 'location_id = ?',
      whereArgs: [locationId],
    );
    return rows.map((row) => row['id'] as String).toSet();
  }

  Future<void> reconcileServerActive(
    String locationId,
    Set<String> serverIds,
  ) async {
    final db = await _db;
    final rows = await db.query(
      'tickets',
      columns: ['id'],
      where: 'location_id = ? AND status = ? AND pending = 0',
      whereArgs: [locationId, 'in'],
    );
    final stale = rows
        .map((row) => row['id'] as String)
        .where((id) => !serverIds.contains(id))
        .toList();
    for (final id in stale) {
      await db.delete('tickets', where: 'id = ?', whereArgs: [id]);
    }
    if (stale.isNotEmpty) ticketsRevision.value++;
  }

  Future<bool> isPlateActive(String locationId, String plate) async {
    final tickets = await active(locationId);
    return tickets.any(
      (t) =>
          (t['vehicleNumber'] ?? '').toString().toUpperCase() ==
          plate.toUpperCase(),
    );
  }

  Future<bool> ticketIsPending(String id) async {
    final rows = await (await _db).query(
      'tickets',
      columns: ['pending'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty && rows.first['pending'] == 1;
  }

  Future<void> markSynced(String id, String ticketNumber) async {
    final db = await _db;
    final rows = await db.query(
      'tickets',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final data = Map<String, dynamic>.from(
      jsonDecode(rows.first['data'] as String),
    );
    data['ticketNumber'] = ticketNumber;
    await db.update(
      'tickets',
      {'pending': 0, 'data': jsonEncode(data)},
      where: 'id = ?',
      whereArgs: [id],
    );
    _refreshPendingCount();
    ticketsRevision.value++;
  }

  Future<void> updateTicketNumber(String id, String ticketNumber) async {
    final db = await _db;
    final rows = await db.query(
      'tickets',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final data = Map<String, dynamic>.from(
      jsonDecode(rows.first['data'] as String),
    );
    data['ticketNumber'] = ticketNumber;
    await db.update(
      'tickets',
      {'data': jsonEncode(data)},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> _refreshPendingCount() async {
    try {
      final rows = await (await _db).rawQuery(
        'SELECT (SELECT COUNT(*) FROM tickets WHERE pending = 1) + (SELECT COUNT(*) FROM memberships WHERE pending = 1) AS count',
      );
      pendingCountNotifier.value = (rows.first['count'] as num).toInt();
    } catch (_) {}
  }

  Future<void> cacheRemote(
    String id,
    String locationId,
    Map<String, dynamic> data,
  ) async {
    final db = await _db;
    final local = await db.query(
      'tickets',
      columns: ['pending'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (local.isNotEmpty && local.first['pending'] == 1) return;
    await save(data, id: id, locationId: locationId, pending: false);
  }

  String _vehicleKey(String value) =>
      value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  Future<void> saveMembership(
    String id,
    Map<String, dynamic> data, {
    required String locationId,
    bool pending = true,
  }) async {
    final stored = Map<String, dynamic>.from(data);
    stored.putIfAbsent(
      '_tenantCompanyId',
      () => TenantContext.instance.companyId,
    );
    for (final field in [
      'startsAt',
      'expiresAt',
      'createdAt',
      'updatedAt',
      'deactivatedAt',
    ]) {
      final value = stored[field];
      if (value is Timestamp) stored[field] = value.toDate().toIso8601String();
      if (value is DateTime) stored[field] = value.toIso8601String();
    }
    await (await _db).insert('memberships', {
      'id': id,
      'location_id': locationId,
      'vehicle_key': _vehicleKey(stored['vehicleNumber']?.toString() ?? ''),
      'data': jsonEncode(stored),
      'pending': pending ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _refreshPendingCount();
    membershipsRevision.value++;
  }

  Future<List<Map<String, dynamic>>> allMemberships({
    String? locationId,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'memberships',
      where: locationId == null ? null : 'location_id = ?',
      whereArgs: locationId == null ? null : [locationId],
    );
    return rows
        .map(
          (row) => {
            'id': row['id'],
            ...Map<String, dynamic>.from(jsonDecode(row['data'] as String)),
            '_localPending': row['pending'] == 1,
          },
        )
        .toList();
  }

  Future<Map<String, dynamic>?> membershipById(String id) async {
    final rows = await (await _db).query(
      'memberships',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return {
      'id': rows.first['id'],
      ...Map<String, dynamic>.from(jsonDecode(rows.first['data'] as String)),
    };
  }

  Future<void> setMembershipStatus(
    String id,
    String status, {
    required String locationId,
  }) async {
    final membership = await membershipById(id);
    if (membership == null) {
      throw StateError('Membership record was not found on this device.');
    }
    membership.remove('id');
    membership['status'] = status;
    final changedAt = DateTime.now();
    membership['updatedAt'] = changedAt.toIso8601String();
    if (status == 'inactive') {
      membership['deactivatedAt'] = changedAt.toIso8601String();
    } else {
      membership.remove('deactivatedAt');
    }
    await saveMembership(id, membership, locationId: locationId);
  }

  Future<Map<String, dynamic>?> membershipByVehicle(
    String locationId,
    String vehicleNumber,
  ) async {
    final rows = await (await _db).query(
      'memberships',
      where: 'location_id = ? AND vehicle_key = ?',
      whereArgs: [locationId, _vehicleKey(vehicleNumber)],
      orderBy: 'rowid DESC',
    );
    for (final row in rows) {
      final data = Map<String, dynamic>.from(jsonDecode(row['data'] as String));
      if (data['status'] == 'active') return {'id': row['id'], ...data};
    }
    return null;
  }

  Future<void> cacheRemoteMembership(
    String id,
    String locationId,
    Map<String, dynamic> data,
  ) async {
    final db = await _db;
    final rows = await db.query(
      'memberships',
      columns: ['pending'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isNotEmpty && rows.first['pending'] == 1) return;
    await saveMembership(id, data, locationId: locationId, pending: false);
  }

  Future<void> markMembershipSynced(String id) async {
    await (await _db).update(
      'memberships',
      {'pending': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    _refreshPendingCount();
    membershipsRevision.value++;
  }

  /// Best-effort sync. Failures remain in SQLite and are retried on later
  /// connectivity events; the operator's completed action is never rolled back.
  Future<void> syncPending() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final connection = await Connectivity().checkConnectivity();
      if (connection.every((state) => state == ConnectivityResult.none)) return;
      final db = await _db;
      final membershipRows = await db.query(
        'memberships',
        where: 'pending = 1',
      );
      if (membershipRows.isNotEmpty && !TenantContext.instance.isReady) {
        await TenantContext.instance.loadForCurrentUser();
      }
      for (final row in membershipRows) {
        try {
          final data = Map<String, dynamic>.from(
            jsonDecode(row['data'] as String),
          );
          final queuedCompany = data.remove('_tenantCompanyId')?.toString();
          if (queuedCompany != null &&
              queuedCompany != TenantContext.instance.companyId)
            continue;
          for (final field in [
            'startsAt',
            'expiresAt',
            'createdAt',
            'updatedAt',
            'deactivatedAt',
          ]) {
            final value = data[field];
            if (value is String)
              data[field] = Timestamp.fromDate(DateTime.parse(value));
          }
          data['updatedAt'] = FieldValue.serverTimestamp();
          final ref = TenantContext.instance
              .collection('memberships')
              .doc(row['id'] as String);
          await ref.set(data);
          await ref.get(const GetOptions(source: Source.server));
          await markMembershipSynced(row['id'] as String);
        } catch (e) {
          debugPrint('Offline membership sync deferred: $e');
        }
      }
      final rows = await db.query('tickets', where: 'pending = 1');
      if (rows.isEmpty) return;
      if (!TenantContext.instance.isReady) {
        await TenantContext.instance.loadForCurrentUser();
      }
      for (final row in rows) {
        try {
          final data = Map<String, dynamic>.from(
            jsonDecode(row['data'] as String),
          );
          final queuedCompany = data.remove('_tenantCompanyId')?.toString();
          if (queuedCompany != null &&
              queuedCompany != TenantContext.instance.companyId) {
            throw StateError('Queued ticket belongs to a different company.');
          }
          final startIso =
              (data.remove('_startIso') ?? data['startTime']) as String;
          final start = DateTime.parse(startIso);
          data['startTime'] = Timestamp.fromDate(start);
          if (data['endTime'] is String)
            data['endTime'] = Timestamp.fromDate(
              DateTime.parse(data['endTime'] as String),
            );
          if (data['checkoutCompletedAt'] is String)
            data['checkoutCompletedAt'] = Timestamp.fromDate(
              DateTime.parse(data['checkoutCompletedAt'] as String),
            );
          data['createdAt'] = Timestamp.fromDate(start);
          data['updatedAt'] = FieldValue.serverTimestamp();
          if ((data['ticketNumber'] ?? '').toString().startsWith('PENDING-')) {
            final numericId = (data['locationNumericId'] as num?)?.toInt() ?? 0;
            final locationCode = numericId.toString().padLeft(2, '0');
            final day = DateFormat('dM').format(start);
            final dateKey = DateFormat('yyyy-MM-dd').format(start);
            final counter = TenantContext.instance
                .collection('counters')
                .doc('${locationCode}_$dateKey');
            final serial = await FirebaseFirestore.instance.runTransaction<int>(
              (tx) async {
                final snapshot = await tx.get(counter);
                final previous = snapshot.data()?['lastSerial'];
                final next =
                    (previous is num
                        ? previous.toInt()
                        : int.tryParse('$previous') ?? 0) +
                    1;
                tx.set(counter, {
                  'lastSerial': next,
                  'date': dateKey,
                  'locationCode': locationCode,
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
                return next;
              },
            );
            data['ticketNumber'] =
                'PVS#$locationCode$day${serial.toString().padLeft(4, '0')}';
            await updateTicketNumber(
              row['id'] as String,
              data['ticketNumber'] as String,
            );
          }
          final ticketRef = TenantContext.instance
              .collection('parking_tickets')
              .doc(row['id'] as String);
          await ticketRef.set(data);
          // A Firestore write may resolve after entering its local queue. Only
          // clear SQLite after a server sourced read confirms the document.
          await ticketRef.get(const GetOptions(source: Source.server));
          await markSynced(
            row['id'] as String,
            data['ticketNumber']?.toString() ?? '',
          );
        } catch (e) {
          debugPrint('Offline ticket sync deferred: $e');
        }
      }
    } catch (e) {
      debugPrint('Offline queue will retry: $e');
    } finally {
      _syncing = false;
    }
  }

  void startSyncListener() {
    if (kIsWeb) return;
    _refreshPendingCount();
    Connectivity().onConnectivityChanged.listen((states) {
      if (states.any((s) => s != ConnectivityResult.none)) syncPending();
    });
    _retryTimer ??= Timer.periodic(
      const Duration(seconds: 20),
      (_) => syncPending(),
    );
    syncPending();
  }
}
