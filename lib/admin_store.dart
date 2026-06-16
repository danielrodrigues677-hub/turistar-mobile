import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:turistar_mobile/firebase_options.dart';
import 'package:turistar_mobile/firestore_schema.dart';
import 'package:turistar_mobile/travel_request_store.dart';

import 'main.dart' show AuthDiagnostics, AuthException, FirebaseBootstrap, FirestoreAuthStore, LocalAuthStore, TuristarAuth, TuristarRole, TuristarSession;

class AdminDashboardStats {
  const AdminDashboardStats({
    required this.totalClients,
    required this.totalRequests,
    required this.totalBookings,
    required this.totalPackages,
  });

  final int totalClients;
  final int totalRequests;
  final int totalBookings;
  final int totalPackages;
}

class AdminClient {
  const AdminClient({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String name;
  final String phone;
  final String role;
  final String createdAt;

  factory AdminClient.fromMap(String id, Map<String, dynamic> data) {
    return AdminClient(
      id: id,
      email: data['email']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      role: data['role']?.toString() ?? TuristarRole.customer,
      createdAt: data['createdAt']?.toString() ?? '',
    );
  }

  factory AdminClient.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return AdminClient.fromMap(doc.id, doc.data() ?? {});
  }

  TuristarSession toSession() {
    return TuristarSession(
      uid: id.contains('@') ? null : id,
      email: email,
      name: name,
      phone: phone,
      role: role,
    );
  }
}

class AdminStore {
  const AdminStore._();

  static FirebaseFirestore? _firestoreOverride;

  @visibleForTesting
  static set firestoreOverride(FirebaseFirestore? firestore) {
    _firestoreOverride = firestore;
  }

  static FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  static String get _projectId => DefaultFirebaseOptions.currentPlatform.projectId;

  static void _ensureStaffAccess() {
    if (!TuristarAuth.hasAnyRole([TuristarRole.admin, TuristarRole.agent])) {
      throw const AuthException('permission-denied', 'Acesso restrito a equipe Turistar.');
    }
  }

  static Future<bool> _useFirestoreSdk() async {
    if (_firestoreOverride != null) return true;
    await FirebaseBootstrap.ensureInitialized();
    return FirebaseAuth.instance.currentUser != null;
  }

  static Future<String?> _idToken() => LocalAuthStore.authIdToken();

  static Map<String, dynamic> _fromRestFields(Map<String, dynamic> fields) {
    final data = <String, dynamic>{};
    fields.forEach((key, value) {
      if (value is! Map) return;
      if (value.containsKey('stringValue')) {
        data[key] = value['stringValue'];
      } else if (value.containsKey('integerValue')) {
        data[key] = int.tryParse(value['integerValue'].toString()) ?? value['integerValue'];
      }
    });
    return data;
  }

  static String _docIdFromRestName(String? name) {
    if (name == null || name.isEmpty) return '';
    return name.split('/').last;
  }

  static Future<List<Map<String, dynamic>>> _listCollectionViaRest({
    required String collection,
    required String idToken,
    String? statusEquals,
  }) async {
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents:runQuery',
    );

    final structuredQuery = <String, dynamic>{
      'from': [
        {'collectionId': collection},
      ],
      'orderBy': [
        {
          'field': {'fieldPath': 'createdAt'},
          'direction': 'DESCENDING',
        },
      ],
    };

    if (statusEquals != null && statusEquals.isNotEmpty) {
      structuredQuery['where'] = {
        'fieldFilter': {
          'field': {'fieldPath': 'status'},
          'op': 'EQUAL',
          'value': {'stringValue': statusEquals},
        },
      };
    }

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'structuredQuery': structuredQuery}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      AuthDiagnostics.step('ADMIN', 'REST list falhou collection=$collection status=${response.statusCode}');
      return [];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return [];

    final results = <Map<String, dynamic>>[];
    for (final item in decoded) {
      if (item is! Map || item['document'] is! Map) continue;
      final doc = item['document'] as Map;
      final fields = doc['fields'] is Map ? Map<String, dynamic>.from(doc['fields'] as Map) : <String, dynamic>{};
      results.add({
        'id': _docIdFromRestName(doc['name']?.toString()),
        ..._fromRestFields(fields),
      });
    }
    return results;
  }

  static Future<void> _patchViaRest({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
    required String idToken,
  }) async {
    final fields = <String>[];
    for (final key in data.keys) {
      fields.add('updateMask.fieldPaths=$key');
    }
    final query = fields.join('&');
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/$collection/$docId?$query',
    );

    final restFields = <String, dynamic>{};
    data.forEach((key, value) {
      restFields[key] = {'stringValue': value.toString()};
    });

    final response = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'fields': restFields}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException('firestore-denied', 'Nao foi possivel atualizar. Faca login novamente.');
    }
  }

  static Future<int> _countCollection(String collection, {String? roleEquals}) async {
    Query<Map<String, dynamic>> query = _db.collection(collection);
    if (roleEquals != null) {
      query = query.where('role', isEqualTo: roleEquals);
    }
    final snapshot = await query.count().get();
    return snapshot.count ?? 0;
  }

  static Future<AdminDashboardStats> fetchDashboardStats() async {
    _ensureStaffAccess();

    if (await _useFirestoreSdk()) {
      try {
        final clients = await _countCollection(FirestoreCollections.users, roleEquals: TuristarRole.customer);
        final requests = await _countCollection(FirestoreCollections.travelRequests);
        final bookings = await _countCollection(FirestoreCollections.bookings);
        final packages = await _countCollection(FirestoreCollections.packages);
        return AdminDashboardStats(
          totalClients: clients,
          totalRequests: requests,
          totalBookings: bookings,
          totalPackages: packages,
        );
      } catch (error, stackTrace) {
        AuthDiagnostics.step('ADMIN', 'dashboard SDK falhou', error: error, stack: stackTrace);
      }
    }

    final clients = (await listClients()).where((client) => client.role == TuristarRole.customer).length;
    final requests = (await listTravelRequests()).length;
    final bookings = (await _listBookingsRaw()).length;
    return AdminDashboardStats(
      totalClients: clients,
      totalRequests: requests,
      totalBookings: bookings,
      totalPackages: 0,
    );
  }

  static Future<List<AdminClient>> listClients() async {
    _ensureStaffAccess();

    if (await _useFirestoreSdk()) {
      try {
        final snap = await _db.collection(FirestoreCollections.users).get();
        final clients = snap.docs.map(AdminClient.fromDoc).toList();
        clients.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return clients;
      } catch (error, stackTrace) {
        AuthDiagnostics.step('ADMIN', 'listClients SDK falhou', error: error, stack: stackTrace);
      }
    }

    final idToken = await _idToken();
    if (idToken == null || idToken.isEmpty) return [];

    final rows = await _listCollectionViaRest(collection: FirestoreCollections.users, idToken: idToken);
    return rows.map((row) {
      final id = row.remove('id')?.toString() ?? '';
      return AdminClient.fromMap(id, row);
    }).toList();
  }

  static Future<List<AdminClient>> searchClients(String query) async {
    final normalized = query.trim().toLowerCase();
    final clients = await listClients();
    if (normalized.isEmpty) return clients;

    return clients.where((client) {
      return client.email.toLowerCase().contains(normalized) ||
          client.name.toLowerCase().contains(normalized) ||
          client.phone.toLowerCase().contains(normalized);
    }).toList();
  }

  static Future<AdminClient?> getClient(String clientId) async {
    _ensureStaffAccess();

    if (await _useFirestoreSdk()) {
      final doc = await _db.collection(FirestoreCollections.users).doc(clientId).get();
      if (!doc.exists) return null;
      return AdminClient.fromDoc(doc);
    }

    final clients = await listClients();
    for (final client in clients) {
      if (client.id == clientId) return client;
    }
    return null;
  }

  static Future<List<TravelRequest>> listTravelRequests({String? statusFilter}) async {
    _ensureStaffAccess();

    if (await _useFirestoreSdk()) {
      try {
        Query<Map<String, dynamic>> query = _db.collection(FirestoreCollections.travelRequests);
        if (statusFilter != null && statusFilter.isNotEmpty) {
          query = query.where('status', isEqualTo: statusFilter);
        }
        final snap = await query.orderBy('createdAt', descending: true).get();
        return snap.docs.map(TravelRequest.fromDoc).toList();
      } catch (error, stackTrace) {
        AuthDiagnostics.step('ADMIN', 'listTravelRequests SDK falhou', error: error, stack: stackTrace);
      }
    }

    final idToken = await _idToken();
    if (idToken == null || idToken.isEmpty) return [];

    final rows = await _listCollectionViaRest(
      collection: FirestoreCollections.travelRequests,
      idToken: idToken,
      statusEquals: statusFilter,
    );
    return rows.map((row) {
      final id = row.remove('id')?.toString() ?? '';
      return TravelRequest.fromMap(id, row);
    }).toList();
  }

  static Future<List<TravelRequest>> listTravelRequestsForClient(String clientId, {String? email}) async {
    final all = await listTravelRequests();
    return all.where((request) {
      if (request.userId == clientId) return true;
      if (email != null && request.userEmail.toLowerCase() == email.toLowerCase()) return true;
      return false;
    }).toList();
  }

  static Future<void> updateTravelRequestStatus({
    required String requestId,
    required String status,
  }) async {
    _ensureStaffAccess();

    if (!TravelRequestStatus.all.contains(status)) {
      throw AuthException('invalid-status', 'Status invalido: $status');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final payload = {
      'status': status,
      'updatedAt': now,
    };

    AuthDiagnostics.step('ADMIN', 'update request=$requestId status=$status');

    if (await _useFirestoreSdk()) {
      try {
        await _db.collection(FirestoreCollections.travelRequests).doc(requestId).update(payload);
        return;
      } catch (error, stackTrace) {
        AuthDiagnostics.step('ADMIN', 'updateTravelRequestStatus SDK falhou', error: error, stack: stackTrace);
      }
    }

    final idToken = await _idToken();
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('firestore-unavailable', 'Nao foi possivel atualizar. Faca login novamente.');
    }

    await _patchViaRest(
      collection: FirestoreCollections.travelRequests,
      docId: requestId,
      data: payload,
      idToken: idToken,
    );
  }

  static Future<List<Map<String, dynamic>>> _listBookingsRaw() async {
    if (await _useFirestoreSdk()) {
      final snap = await _db.collection(FirestoreCollections.bookings).get();
      return snap.docs.map((doc) => {'id': doc.id, ...?doc.data()}).toList();
    }
    return [];
  }
}
