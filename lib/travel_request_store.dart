import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:turistar_mobile/firebase_options.dart';
import 'package:turistar_mobile/firestore_schema.dart';

import 'main.dart' show AuthDiagnostics, AuthException, FirebaseBootstrap, LocalAuthStore, TuristarAuth;

class TravelRequestStatus {
  const TravelRequestStatus._();

  static const newRequest = 'NEW';
  static const inAnalysis = 'IN_ANALYSIS';
  static const quoting = 'QUOTING';
  static const waitingClient = 'WAITING_CLIENT';
  static const confirmed = 'CONFIRMED';
  static const cancelled = 'CANCELLED';

  static const all = [
    newRequest,
    inAnalysis,
    quoting,
    waitingClient,
    confirmed,
    cancelled,
  ];

  static String label(String status) {
    switch (normalize(status)) {
      case newRequest:
        return 'Nova';
      case inAnalysis:
        return 'Em analise';
      case quoting:
        return 'Orcamentando';
      case waitingClient:
        return 'Aguardando cliente';
      case confirmed:
        return 'Confirmada';
      case cancelled:
        return 'Cancelada';
      default:
        return 'Nova';
    }
  }

  static String normalize(String status) {
    switch (status) {
      case newRequest:
      case inAnalysis:
      case quoting:
      case waitingClient:
      case confirmed:
      case cancelled:
        return status;
      case 'pending':
        return newRequest;
      case 'in_review':
        return inAnalysis;
      case 'quoted':
        return quoting;
      case 'booked':
        return confirmed;
      case 'cancelled':
        return cancelled;
      default:
        return newRequest;
    }
  }
}

class CustomerQuoteStatus {
  const CustomerQuoteStatus._();

  static const pending = 'pending';
  static const sent = 'sent';
  static const accepted = 'accepted';
  static const expired = 'expired';
  static const rejected = 'rejected';

  static String label(String status) {
    switch (status) {
      case sent:
        return 'Orcamento enviado';
      case accepted:
        return 'Aceito';
      case expired:
        return 'Expirado';
      case rejected:
        return 'Recusado';
      case pending:
      default:
        return 'Em preparacao';
    }
  }
}

class TravelRequest {
  const TravelRequest({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.origin,
    required this.destination,
    required this.departureDate,
    this.returnDate,
    required this.passengers,
    this.notes = '',
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String userEmail;
  final String origin;
  final String destination;
  final String departureDate;
  final String? returnDate;
  final int passengers;
  final String notes;
  final String status;
  final String createdAt;
  final String updatedAt;

  String get routeLabel => '$origin → $destination';

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userEmail': userEmail,
        'origin': origin,
        'destination': destination,
        'departureDate': departureDate,
        if (returnDate != null && returnDate!.isNotEmpty) 'returnDate': returnDate,
        'passengers': passengers,
        'notes': notes,
        'status': status,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory TravelRequest.fromMap(String id, Map<String, dynamic> data) {
    return TravelRequest(
      id: id,
      userId: data['userId']?.toString() ?? '',
      userEmail: data['userEmail']?.toString() ?? '',
      origin: data['origin']?.toString() ?? '',
      destination: data['destination']?.toString() ?? '',
      departureDate: data['departureDate']?.toString() ?? '',
      returnDate: data['returnDate']?.toString(),
      passengers: int.tryParse(data['passengers']?.toString() ?? '') ?? 1,
      notes: data['notes']?.toString() ?? '',
      status: TravelRequestStatus.normalize(data['status']?.toString() ?? TravelRequestStatus.newRequest),
      createdAt: data['createdAt']?.toString() ?? '',
      updatedAt: data['updatedAt']?.toString() ?? '',
    );
  }

  factory TravelRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return TravelRequest.fromMap(doc.id, doc.data() ?? {});
  }
}

class CustomerQuote {
  const CustomerQuote({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.route,
    required this.status,
    this.totalPrice,
    this.currency = 'BRL',
    this.travelRequestId,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String userEmail;
  final String route;
  final String status;
  final String? totalPrice;
  final String currency;
  final String? travelRequestId;
  final String createdAt;

  factory CustomerQuote.fromMap(String id, Map<String, dynamic> data) {
    final origin = data['origin']?.toString() ?? '';
    final destination = data['destination']?.toString() ?? '';
    final route = data['route']?.toString() ??
        (origin.isNotEmpty || destination.isNotEmpty ? '$origin → $destination' : 'Orcamento Turistar');

    return CustomerQuote(
      id: id,
      userId: data['userId']?.toString() ?? '',
      userEmail: data['userEmail']?.toString() ?? '',
      route: route,
      status: data['status']?.toString() ?? CustomerQuoteStatus.pending,
      totalPrice: data['totalPrice']?.toString(),
      currency: data['currency']?.toString() ?? 'BRL',
      travelRequestId: data['travelRequestId']?.toString(),
      createdAt: data['createdAt']?.toString() ?? '',
    );
  }

  factory CustomerQuote.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return CustomerQuote.fromMap(doc.id, doc.data() ?? {});
  }
}

class CustomerBooking {
  const CustomerBooking({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.locator,
    required this.route,
    required this.passenger,
    required this.status,
    required this.price,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String userEmail;
  final String locator;
  final String route;
  final String passenger;
  final String status;
  final String price;
  final String createdAt;

  factory CustomerBooking.fromMap(String id, Map<String, dynamic> data) {
    return CustomerBooking(
      id: id,
      userId: data['userId']?.toString() ?? '',
      userEmail: data['userEmail']?.toString() ?? '',
      locator: data['locator']?.toString() ?? '—',
      route: data['route']?.toString() ?? '',
      passenger: data['passenger']?.toString() ?? data['passengers']?.toString() ?? '',
      status: data['status']?.toString() ?? 'confirmada',
      price: data['price']?.toString() ?? data['totalPrice']?.toString() ?? '',
      createdAt: data['createdAt']?.toString() ?? '',
    );
  }

  factory CustomerBooking.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return CustomerBooking.fromMap(doc.id, doc.data() ?? {});
  }
}

class CustomerAreaStore {
  const CustomerAreaStore._();

  static FirebaseFirestore? _firestoreOverride;

  @visibleForTesting
  static set firestoreOverride(FirebaseFirestore? firestore) {
    _firestoreOverride = firestore;
  }

  static FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  static String get _projectId => DefaultFirebaseOptions.currentPlatform.projectId;

  static Future<bool> _hasFirebaseAuthUser() async {
    if (_firestoreOverride != null) return true;
    await FirebaseBootstrap.ensureInitialized();
    return FirebaseAuth.instance.currentUser != null;
  }

  static Future<bool> _useFirestoreSdk() async {
    if (_firestoreOverride != null) return true;
    return _hasFirebaseAuthUser();
  }

  static Future<String?> _idToken() => LocalAuthStore.authIdToken();

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
      } else if (value is bool) {
        fields[key] = {'booleanValue': value};
      } else {
        fields[key] = {'stringValue': value.toString()};
      }
    });
    return fields;
  }

  static Map<String, dynamic> _fromRestFields(Map<String, dynamic> fields) {
    final data = <String, dynamic>{};
    fields.forEach((key, value) {
      if (value is! Map) return;
      if (value.containsKey('stringValue')) {
        data[key] = value['stringValue'];
      } else if (value.containsKey('integerValue')) {
        data[key] = int.tryParse(value['integerValue'].toString()) ?? value['integerValue'];
      } else if (value.containsKey('doubleValue')) {
        data[key] = value['doubleValue'];
      } else if (value.containsKey('booleanValue')) {
        data[key] = value['booleanValue'];
      }
    });
    return data;
  }

  static String _docIdFromRestName(String? name) {
    if (name == null || name.isEmpty) return '';
    return name.split('/').last;
  }

  static Future<String> _createViaRest({
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
      debugPrint('[CustomerAreaStore] REST create falhou status=${response.statusCode} body=${response.body}');
      throw AuthException('firestore-denied', 'Nao foi possivel salvar sua solicitacao. Faca login novamente.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map) {
      return _docIdFromRestName(decoded['name']?.toString());
    }
    return '';
  }

  static Future<List<Map<String, dynamic>>> _queryViaRest({
    required String collection,
    required String userId,
    required String idToken,
  }) async {
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents:runQuery',
    );
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'structuredQuery': {
          'from': [
            {'collectionId': collection},
          ],
          'where': {
            'fieldFilter': {
              'field': {'fieldPath': 'userId'},
              'op': 'EQUAL',
              'value': {'stringValue': userId},
            },
          },
          'orderBy': [
            {
              'field': {'fieldPath': 'createdAt'},
              'direction': 'DESCENDING',
            },
          ],
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('[CustomerAreaStore] REST query falhou status=${response.statusCode} body=${response.body}');
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

  static Future<TravelRequest> createTravelRequest({
    required String origin,
    required String destination,
    required String departureDate,
    String? returnDate,
    required int passengers,
    String notes = '',
  }) async {
    final session = TuristarAuth.session;
    final userId = session?.uid;
    if (session == null || userId == null || userId.isEmpty) {
      throw const AuthException('auth-required', 'Faca login para solicitar um orcamento.');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final data = {
      'userId': userId,
      'userEmail': session.email,
      'origin': origin.trim(),
      'destination': destination.trim(),
      'departureDate': departureDate,
      if (returnDate != null && returnDate.isNotEmpty) 'returnDate': returnDate,
      'passengers': passengers,
      'notes': notes.trim(),
      'status': TravelRequestStatus.newRequest,
      'createdAt': now,
      'updatedAt': now,
    };

    AuthDiagnostics.step('TRAVEL_REQUEST', 'create userId=$userId $origin->$destination');

    if (await _useFirestoreSdk()) {
      final doc = await _db.collection(FirestoreCollections.travelRequests).add(data);
      AuthDiagnostics.step('TRAVEL_REQUEST', 'create OK doc=${doc.id}');
      return TravelRequest.fromMap(doc.id, data);
    }

    final idToken = await _idToken();
    if (idToken != null && idToken.isNotEmpty) {
      final docId = await _createViaRest(
        collection: FirestoreCollections.travelRequests,
        data: data,
        idToken: idToken,
      );
      AuthDiagnostics.step('TRAVEL_REQUEST', 'create OK via REST doc=$docId');
      return TravelRequest.fromMap(docId, data);
    }

    throw const AuthException(
      'firestore-unavailable',
      'Nao foi possivel salvar sua solicitacao. Faca login novamente.',
    );
  }

  static Future<List<TravelRequest>> listTravelRequests() async {
    final session = TuristarAuth.session;
    final userId = session?.uid;
    if (userId == null || userId.isEmpty) return [];

    if (await _useFirestoreSdk()) {
      try {
        final snap = await _db
            .collection(FirestoreCollections.travelRequests)
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .get();
        return snap.docs.map(TravelRequest.fromDoc).toList();
      } catch (error, stackTrace) {
        AuthDiagnostics.step('TRAVEL_REQUEST', 'list SDK falhou', error: error, stack: stackTrace);
      }
    }

    final idToken = await _idToken();
    if (idToken == null || idToken.isEmpty) return [];

    final rows = await _queryViaRest(
      collection: FirestoreCollections.travelRequests,
      userId: userId,
      idToken: idToken,
    );
    return rows.map((row) {
      final id = row.remove('id')?.toString() ?? '';
      return TravelRequest.fromMap(id, row);
    }).toList();
  }

  static Future<List<CustomerQuote>> listQuotes() async {
    final session = TuristarAuth.session;
    final userId = session?.uid;
    if (userId == null || userId.isEmpty) return [];

    if (await _useFirestoreSdk()) {
      try {
        final snap = await _db
            .collection(FirestoreCollections.quotes)
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .get();
        return snap.docs.map(CustomerQuote.fromDoc).toList();
      } catch (error, stackTrace) {
        AuthDiagnostics.step('QUOTES', 'list SDK falhou', error: error, stack: stackTrace);
      }
    }

    final idToken = await _idToken();
    if (idToken == null || idToken.isEmpty) return [];

    final rows = await _queryViaRest(
      collection: FirestoreCollections.quotes,
      userId: userId,
      idToken: idToken,
    );
    return rows.map((row) {
      final id = row.remove('id')?.toString() ?? '';
      return CustomerQuote.fromMap(id, row);
    }).toList();
  }

  static Future<List<CustomerBooking>> listBookings() async {
    final session = TuristarAuth.session;
    final userId = session?.uid;
    if (userId == null || userId.isEmpty) return [];

    if (await _useFirestoreSdk()) {
      try {
        final snap = await _db
            .collection(FirestoreCollections.bookings)
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .get();
        return snap.docs.map(CustomerBooking.fromDoc).toList();
      } catch (error, stackTrace) {
        AuthDiagnostics.step('BOOKINGS', 'list SDK falhou', error: error, stack: stackTrace);
      }
    }

    final idToken = await _idToken();
    if (idToken == null || idToken.isEmpty) return [];

    final rows = await _queryViaRest(
      collection: FirestoreCollections.bookings,
      userId: userId,
      idToken: idToken,
    );
    return rows.map((row) {
      final id = row.remove('id')?.toString() ?? '';
      return CustomerBooking.fromMap(id, row);
    }).toList();
  }
}
