import 'dart:async';
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
    if (!FirebaseBootstrap.canUseFirebase) return false;
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
      } else if (value.containsKey('doubleValue')) {
        data[key] = double.tryParse(value['doubleValue'].toString()) ?? value['doubleValue'];
      }
    });
    return data;
  }

  static Map<String, dynamic> _toRestFields(Map<String, dynamic> data) {
    final fields = <String, dynamic>{};
    data.forEach((key, value) {
      if (value == null) return;
      if (value is String) {
        fields[key] = {'stringValue': value};
      } else if (value is int) {
        fields[key] = {'integerValue': value.toString()};
      } else if (value is double) {
        fields[key] = {'doubleValue': value};
      } else {
        fields[key] = {'stringValue': value.toString()};
      }
    });
    return fields;
  }

  static Future<Map<String, dynamic>?> _getDocumentViaRest({
    required String collection,
    required String docId,
    required String idToken,
  }) async {
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/$collection/$docId',
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $idToken'},
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['fields'] is! Map) return null;
    final fields = Map<String, dynamic>.from(decoded['fields'] as Map);
    return {
      'id': docId,
      ..._fromRestFields(fields),
    };
  }

  static Future<void> _deleteViaRest({
    required String collection,
    required String docId,
    required String idToken,
  }) async {
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/$collection/$docId',
    );
    final response = await http.delete(
      uri,
      headers: {'Authorization': 'Bearer $idToken'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException('firestore-denied', 'Nao foi possivel excluir. Faca login novamente.');
    }
  }

  static Future<void> _createViaRest({
    required String collection,
    required Map<String, dynamic> data,
    required String idToken,
  }) async {
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/$collection',
    );
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'fields': _toRestFields(data)}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException('firestore-denied', 'Nao foi possivel criar a solicitacao. Faca login novamente.');
    }
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
      if (value is String) {
        restFields[key] = {'stringValue': value};
      } else if (value is int) {
        restFields[key] = {'integerValue': value.toString()};
      } else if (value is double) {
        restFields[key] = {'doubleValue': value};
      } else {
        restFields[key] = {'stringValue': value.toString()};
      }
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

  static Stream<List<TravelRequest>> watchTravelRequests() {
    _ensureStaffAccess();
      return Stream.fromFuture(_useFirestoreSdk()).asyncExpand((useSdk) async* {
      if (useSdk) {
        yield* _db
            .collection(FirestoreCollections.travelRequests)
            .orderBy('createdAt', descending: true)
            .snapshots()
            .map((snapshot) => snapshot.docs.map(TravelRequest.fromDoc).toList());
        return;
      }

      yield await listTravelRequests();
      yield* Stream.periodic(const Duration(seconds: 15)).asyncMap((_) => listTravelRequests());
    });
  }

  static Future<TravelRequest?> getTravelRequest(String requestId) async {
    _ensureStaffAccess();
    if (requestId.isEmpty) return null;

    if (await _useFirestoreSdk()) {
      try {
        final doc = await _db.collection(FirestoreCollections.travelRequests).doc(requestId).get();
        if (!doc.exists) return null;
        return TravelRequest.fromDoc(doc);
      } catch (error, stackTrace) {
        AuthDiagnostics.step('ADMIN', 'getTravelRequest SDK falhou', error: error, stack: stackTrace);
      }
    }

    final idToken = await _idToken();
    if (idToken == null || idToken.isEmpty) return null;

    final row = await _getDocumentViaRest(
      collection: FirestoreCollections.travelRequests,
      docId: requestId,
      idToken: idToken,
    );
    if (row == null) return null;
    final id = row.remove('id')?.toString() ?? requestId;
    return TravelRequest.fromMap(id, row);
  }

  static List<TravelRequest> filterTravelRequests({
    required List<TravelRequest> requests,
    String query = '',
    String? statusFilter,
  }) {
    return requests.where((request) {
      return request.matchesSearch(query) && request.matchesStatus(statusFilter);
    }).toList();
  }

  static TravelRequestStats requestStatsFrom(List<TravelRequest> requests) {
    return TravelRequestStats.fromRequests(requests);
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
    String? timelineMessage,
  }) async {
    _ensureStaffAccess();

    if (!TravelRequestStatus.all.contains(status)) {
      throw AuthException('invalid-status', 'Status invalido: $status');
    }

    final current = await getTravelRequest(requestId);
    if (current == null) {
      throw const AuthException('not-found', 'Solicitacao nao encontrada.');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final timeline = [...current.timeline];
    if (TravelRequestStatus.normalize(current.status) != TravelRequestStatus.normalize(status)) {
      timeline.add(
        TravelRequestTimelineEntry(
          at: now,
          type: 'status_change',
          message: timelineMessage ?? TravelRequestStatus.timelineMessageForStatus(status),
          status: status,
          authorEmail: TuristarAuth.session?.email,
        ),
      );
    }

    final payload = {
      'status': status,
      'updatedAt': now,
      'timelineJson': TravelRequestTimeline.encode(timeline),
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

  static Future<void> updateTravelRequest(TravelRequest request) async {
    _ensureStaffAccess();

    final now = DateTime.now().toUtc().toIso8601String();
    final payload = {
      ...request.toMap(),
      'updatedAt': now,
      'timelineJson': TravelRequestTimeline.encode(request.timeline),
    };
    payload.remove('createdAt');

    if (await _useFirestoreSdk()) {
      try {
        await _db.collection(FirestoreCollections.travelRequests).doc(request.id).update(payload);
        return;
      } catch (error, stackTrace) {
        AuthDiagnostics.step('ADMIN', 'updateTravelRequest SDK falhou', error: error, stack: stackTrace);
      }
    }

    final idToken = await _idToken();
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('firestore-unavailable', 'Nao foi possivel salvar. Faca login novamente.');
    }

    await _patchViaRest(
      collection: FirestoreCollections.travelRequests,
      docId: request.id,
      data: payload,
      idToken: idToken,
    );
  }

  static Future<void> deleteTravelRequest(String requestId) async {
    _ensureStaffAccess();

    if (await _useFirestoreSdk()) {
      try {
        await _db.collection(FirestoreCollections.travelRequests).doc(requestId).delete();
        return;
      } catch (error, stackTrace) {
        AuthDiagnostics.step('ADMIN', 'deleteTravelRequest SDK falhou', error: error, stack: stackTrace);
      }
    }

    final idToken = await _idToken();
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('firestore-unavailable', 'Nao foi possivel excluir. Faca login novamente.');
    }

    await _deleteViaRest(
      collection: FirestoreCollections.travelRequests,
      docId: requestId,
      idToken: idToken,
    );
  }

  static Future<TravelRequest> createTravelRequestAsStaff({
    required String name,
    required String email,
    required String phone,
    required String origin,
    required String destination,
    required String departureDate,
    String? returnDate,
    int adults = 1,
    int children = 0,
    double budget = 0,
    String notes = '',
  }) async {
    _ensureStaffAccess();

    final now = DateTime.now().toUtc().toIso8601String();
    final passengers = adults + children;
    final timeline = TravelRequestTimeline.encode([
      TravelRequestTimelineEntry(
        at: now,
        type: 'created',
        message: 'Solicitacao criada pela equipe',
        authorEmail: TuristarAuth.session?.email,
      ),
    ]);

    final data = {
      'userId': email.trim().toLowerCase(),
      'userEmail': email.trim().toLowerCase(),
      'name': name.trim(),
      'phone': phone.trim(),
      'origin': origin.trim(),
      'destination': destination.trim(),
      'departureDate': departureDate,
      if (returnDate != null && returnDate.isNotEmpty) 'returnDate': returnDate,
      'passengers': passengers,
      'adults': adults,
      'children': children,
      if (budget > 0) 'budget': budget,
      'notes': notes.trim(),
      'status': TravelRequestStatus.newRequest,
      'createdAt': now,
      'updatedAt': now,
      'timelineJson': timeline,
    };

    if (await _useFirestoreSdk()) {
      final doc = await _db.collection(FirestoreCollections.travelRequests).add(data);
      return TravelRequest.fromMap(doc.id, data);
    }

    final idToken = await _idToken();
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('firestore-unavailable', 'Nao foi possivel criar. Faca login novamente.');
    }

    await _createViaRest(
      collection: FirestoreCollections.travelRequests,
      data: data,
      idToken: idToken,
    );

    final requests = await listTravelRequests();
    return requests.firstWhere(
      (request) => request.userEmail == email.trim().toLowerCase() && request.createdAt == now,
      orElse: () => TravelRequest.fromMap('', data),
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
