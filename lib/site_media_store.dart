import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:turistar_mobile/firebase_options.dart';
import 'package:turistar_mobile/firestore_schema.dart';

import 'admin_permissions.dart';
import 'main.dart' show AuthDiagnostics, AuthException, FirebaseBootstrap, LocalAuthStore;

class SiteBanner {
  const SiteBanner({
    required this.id,
    required this.title,
    this.subtitle = '',
    required this.imageUrl,
    this.ctaText = '',
    this.ctaLink = '',
    this.linkUrl = '',
    this.active = true,
    this.displayOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String ctaText;
  final String ctaLink;
  final String linkUrl;
  final bool active;
  final int displayOrder;
  final String createdAt;
  final String updatedAt;

  Map<String, dynamic> toMap() => {
        'title': title,
        'subtitle': subtitle,
        'imageUrl': imageUrl,
        'ctaText': ctaText,
        'ctaLink': ctaLink.isNotEmpty ? ctaLink : linkUrl,
        'linkUrl': ctaLink.isNotEmpty ? ctaLink : linkUrl,
        'active': active,
        'displayOrder': displayOrder,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory SiteBanner.fromMap(String id, Map<String, dynamic> data) {
    final ctaLink = data['ctaLink']?.toString() ?? data['linkUrl']?.toString() ?? '';
    return SiteBanner(
      id: id,
      title: data['title']?.toString() ?? '',
      subtitle: data['subtitle']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ?? '',
      ctaText: data['ctaText']?.toString() ?? '',
      ctaLink: ctaLink,
      linkUrl: ctaLink,
      active: data['active'] != false && data['active']?.toString() != 'false',
      displayOrder: int.tryParse(data['displayOrder']?.toString() ?? '') ?? 0,
      createdAt: data['createdAt']?.toString() ?? '',
      updatedAt: data['updatedAt']?.toString() ?? '',
    );
  }

  factory SiteBanner.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return SiteBanner.fromMap(doc.id, doc.data() ?? {});
  }
}

class SiteDestination {
  const SiteDestination({
    required this.id,
    required this.name,
    required this.country,
    required this.imageUrl,
    this.description = '',
    this.active = true,
    this.displayOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String country;
  final String imageUrl;
  final String description;
  final bool active;
  final int displayOrder;
  final String createdAt;
  final String updatedAt;

  Map<String, dynamic> toMap() => {
        'name': name,
        'country': country,
        'imageUrl': imageUrl,
        'description': description,
        'active': active,
        'displayOrder': displayOrder,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory SiteDestination.fromMap(String id, Map<String, dynamic> data) {
    return SiteDestination(
      id: id,
      name: data['name']?.toString() ?? '',
      country: data['country']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      active: data['active'] != false && data['active']?.toString() != 'false',
      displayOrder: int.tryParse(data['displayOrder']?.toString() ?? '') ?? 0,
      createdAt: data['createdAt']?.toString() ?? '',
      updatedAt: data['updatedAt']?.toString() ?? '',
    );
  }

  factory SiteDestination.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return SiteDestination.fromMap(doc.id, doc.data() ?? {});
  }
}

class SiteTestimonial {
  const SiteTestimonial({
    required this.id,
    required this.authorName,
    required this.quote,
    required this.imageUrl,
    this.rating = 5,
    this.active = true,
    this.displayOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String authorName;
  final String quote;
  final String imageUrl;
  final int rating;
  final bool active;
  final int displayOrder;
  final String createdAt;
  final String updatedAt;

  Map<String, dynamic> toMap() => {
        'authorName': authorName,
        'quote': quote,
        'imageUrl': imageUrl,
        'rating': rating,
        'active': active,
        'displayOrder': displayOrder,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory SiteTestimonial.fromMap(String id, Map<String, dynamic> data) {
    return SiteTestimonial(
      id: id,
      authorName: data['authorName']?.toString() ?? '',
      quote: data['quote']?.toString() ?? data['text']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ?? '',
      rating: int.tryParse(data['rating']?.toString() ?? '') ?? 5,
      active: data['active'] != false && data['active']?.toString() != 'false',
      displayOrder: int.tryParse(data['displayOrder']?.toString() ?? '') ?? 0,
      createdAt: data['createdAt']?.toString() ?? '',
      updatedAt: data['updatedAt']?.toString() ?? '',
    );
  }

  factory SiteTestimonial.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return SiteTestimonial.fromMap(doc.id, doc.data() ?? {});
  }
}

class SiteMediaStore {
  const SiteMediaStore._();

  static FirebaseFirestore? _firestoreOverride;

  @visibleForTesting
  static set firestoreOverride(FirebaseFirestore? firestore) {
    _firestoreOverride = firestore;
  }

  static FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  static String get _projectId => DefaultFirebaseOptions.currentPlatform.projectId;

  static void _ensureStaffAccess() {
    AdminPermissions.requireConsultorOrAdmin();
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
      } else if (value.containsKey('booleanValue')) {
        data[key] = value['booleanValue'];
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
      } else if (value is bool) {
        fields[key] = {'booleanValue': value};
      } else {
        fields[key] = {'stringValue': value.toString()};
      }
    });
    return fields;
  }

  static String _docIdFromRestName(String? name) {
    if (name == null || name.isEmpty) return '';
    return name.split('/').last;
  }

  static Future<List<Map<String, dynamic>>> _listCollectionViaRest({
    required String collection,
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
          'orderBy': [
            {
              'field': {'fieldPath': 'displayOrder'},
              'direction': 'ASCENDING',
            },
          ],
        },
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return [];
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

  static Future<String> _createViaRest({
    required String collection,
    required Map<String, dynamic> data,
    required String idToken,
    String? docId,
  }) async {
    final base = 'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/$collection';
    final uri = docId == null || docId.isEmpty ? Uri.parse(base) : Uri.parse('$base?documentId=$docId');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'fields': _toRestFields(data)}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException('firestore-denied', 'Nao foi possivel salvar o conteudo.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map) return _docIdFromRestName(decoded['name']?.toString());
    return docId ?? '';
  }

  static Future<void> _patchViaRest({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
    required String idToken,
  }) async {
    final fields = data.keys.map((key) => 'updateMask.fieldPaths=$key').join('&');
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/$collection/$docId?$fields',
    );
    final response = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'fields': _toRestFields(data)}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException('firestore-denied', 'Nao foi possivel salvar o conteudo.');
    }
  }

  static Future<void> _deleteViaRest({
    required String collection,
    required String docId,
    required String idToken,
  }) async {
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/$collection/$docId',
    );
    final response = await http.delete(uri, headers: {'Authorization': 'Bearer $idToken'});
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException('firestore-denied', 'Nao foi possivel excluir o conteudo.');
    }
  }

  static Future<Map<String, dynamic>> _saveDocument({
    required String collection,
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    if (await _useFirestoreSdk()) {
      if (id.isEmpty) {
        final doc = await _db.collection(collection).add(payload);
        return {...payload, 'id': doc.id};
      }
      await _db.collection(collection).doc(id).set(payload, SetOptions(merge: true));
      return {...payload, 'id': id};
    }

    final idToken = await _idToken();
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('firestore-unavailable', 'Nao foi possivel salvar o conteudo.');
    }

    if (id.isEmpty) {
      final docId = await _createViaRest(collection: collection, data: payload, idToken: idToken);
      return {...payload, 'id': docId};
    }

    await _patchViaRest(collection: collection, docId: id, data: payload, idToken: idToken);
    return {...payload, 'id': id};
  }

  static Future<void> _deleteDocument({
    required String collection,
    required String id,
  }) async {
    if (id.isEmpty) return;
    if (await _useFirestoreSdk()) {
      await _db.collection(collection).doc(id).delete();
      return;
    }
    final idToken = await _idToken();
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('firestore-unavailable', 'Nao foi possivel excluir o conteudo.');
    }
    await _deleteViaRest(collection: collection, docId: id, idToken: idToken);
  }

  static Future<List<Map<String, dynamic>>> _listDocuments(String collection) async {
    if (await _useFirestoreSdk()) {
      try {
        final snap = await _db.collection(collection).orderBy('displayOrder').get();
        return snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      } catch (error, stackTrace) {
        AuthDiagnostics.step('SITE_MEDIA', 'list SDK falhou', error: error, stack: stackTrace);
      }
    }
    final idToken = await _idToken();
    if (idToken == null || idToken.isEmpty) return [];
    return _listCollectionViaRest(collection: collection, idToken: idToken);
  }

  static Stream<List<T>> _watchCollection<T>({
    required String collection,
    required T Function(String id, Map<String, dynamic> data) mapper,
  }) {
    _ensureStaffAccess();
    return Stream.fromFuture(_useFirestoreSdk()).asyncExpand((useSdk) async* {
      if (useSdk) {
        yield* _db.collection(collection).orderBy('displayOrder').snapshots().map((snapshot) {
          return snapshot.docs.map((doc) => mapper(doc.id, doc.data())).toList();
        });
        return;
      }
      yield (await _listDocuments(collection)).map((row) {
        final id = row.remove('id')?.toString() ?? '';
        return mapper(id, row);
      }).toList();
      yield* Stream.periodic(const Duration(seconds: 20)).asyncMap((_) async {
        final rows = await _listDocuments(collection);
        return rows.map((row) {
          final id = row.remove('id')?.toString() ?? '';
          return mapper(id, row);
        }).toList();
      });
    });
  }

  static Future<List<SiteBanner>> listBanners() async {
    final rows = await _listDocuments(FirestoreCollections.banners);
    return rows.map((row) {
      final id = row.remove('id')?.toString() ?? '';
      return SiteBanner.fromMap(id, row);
    }).toList();
  }

  static Stream<List<SiteBanner>> watchBanners() {
    return _watchCollection(
      collection: FirestoreCollections.banners,
      mapper: SiteBanner.fromMap,
    );
  }

  static Future<SiteBanner> saveBanner(SiteBanner banner) async {
    _ensureStaffAccess();
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = {
      ...banner.toMap(),
      'updatedAt': now,
      if (banner.createdAt.isEmpty) 'createdAt': now,
    };
    final saved = await _saveDocument(collection: FirestoreCollections.banners, id: banner.id, payload: payload);
    return SiteBanner.fromMap(saved['id']?.toString() ?? banner.id, saved);
  }

  static Future<void> deleteBanner(String id) async {
    _ensureStaffAccess();
    await _deleteDocument(collection: FirestoreCollections.banners, id: id);
  }

  static Future<void> reorderBanners(List<SiteBanner> banners) async {
    _ensureStaffAccess();
    final now = DateTime.now().toUtc().toIso8601String();
    for (var i = 0; i < banners.length; i++) {
      await saveBanner(
        SiteBanner(
          id: banners[i].id,
          title: banners[i].title,
          subtitle: banners[i].subtitle,
          imageUrl: banners[i].imageUrl,
          ctaText: banners[i].ctaText,
          ctaLink: banners[i].ctaLink,
          active: banners[i].active,
          displayOrder: i,
          createdAt: banners[i].createdAt,
          updatedAt: now,
        ),
      );
    }
  }

  static const String kSiteAssetBaseUrl = 'https://agenciaturistar.com.br/assets/assets/images/packages';

  static Future<void> seedDefaultBannersIfEmpty() async {
    _ensureStaffAccess();
    final existing = await listBanners();
    if (existing.isNotEmpty) return;

    final now = DateTime.now().toUtc().toIso8601String();
    for (final seed in kDefaultSiteBanners) {
      await saveBanner(
        SiteBanner(
          id: '',
          title: seed.title,
          subtitle: seed.subtitle,
          imageUrl: seed.imageUrl,
          ctaText: seed.ctaText,
          ctaLink: seed.ctaLink,
          active: true,
          displayOrder: seed.displayOrder,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  static Future<List<SiteDestination>> listDestinations() async {
    final rows = await _listDocuments(FirestoreCollections.destinations);
    return rows.map((row) {
      final id = row.remove('id')?.toString() ?? '';
      return SiteDestination.fromMap(id, row);
    }).toList();
  }

  static Stream<List<SiteDestination>> watchDestinations() {
    return _watchCollection(
      collection: FirestoreCollections.destinations,
      mapper: SiteDestination.fromMap,
    );
  }

  static Future<SiteDestination> saveDestination(SiteDestination destination) async {
    _ensureStaffAccess();
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = {
      ...destination.toMap(),
      'updatedAt': now,
      if (destination.createdAt.isEmpty) 'createdAt': now,
    };
    final saved = await _saveDocument(collection: FirestoreCollections.destinations, id: destination.id, payload: payload);
    return SiteDestination.fromMap(saved['id']?.toString() ?? destination.id, saved);
  }

  static Future<void> deleteDestination(String id) async {
    _ensureStaffAccess();
    await _deleteDocument(collection: FirestoreCollections.destinations, id: id);
  }

  static Future<List<SiteTestimonial>> listTestimonials() async {
    final rows = await _listDocuments(FirestoreCollections.testimonials);
    return rows.map((row) {
      final id = row.remove('id')?.toString() ?? '';
      return SiteTestimonial.fromMap(id, row);
    }).toList();
  }

  static Stream<List<SiteTestimonial>> watchTestimonials() {
    return _watchCollection(
      collection: FirestoreCollections.testimonials,
      mapper: SiteTestimonial.fromMap,
    );
  }

  static Future<SiteTestimonial> saveTestimonial(SiteTestimonial testimonial) async {
    _ensureStaffAccess();
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = {
      ...testimonial.toMap(),
      'updatedAt': now,
      if (testimonial.createdAt.isEmpty) 'createdAt': now,
    };
    final saved = await _saveDocument(collection: FirestoreCollections.testimonials, id: testimonial.id, payload: payload);
    return SiteTestimonial.fromMap(saved['id']?.toString() ?? testimonial.id, saved);
  }

  static Future<void> deleteTestimonial(String id) async {
    _ensureStaffAccess();
    await _deleteDocument(collection: FirestoreCollections.testimonials, id: id);
  }
}

class _SeedBanner {
  const _SeedBanner({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.ctaText,
    required this.ctaLink,
    required this.displayOrder,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
  final String ctaText;
  final String ctaLink;
  final int displayOrder;
}

const List<_SeedBanner> kDefaultSiteBanners = [
  _SeedBanner(
    title: 'Explore o Mundo com a Turistar',
    subtitle: 'Voos, hoteis, carros e pacotes com atendimento completo.',
    imageUrl: '${SiteMediaStore.kSiteAssetBaseUrl}/gramado.jpg',
    ctaText: 'Solicitar orcamento',
    ctaLink: 'https://wa.me/5511978916580',
    displayOrder: 0,
  ),
  _SeedBanner(
    title: 'Porto de Galinhas',
    subtitle: 'Aereo + hospedagem + traslados inclusos.',
    imageUrl: '${SiteMediaStore.kSiteAssetBaseUrl}/porto-de-galinhas.jpg',
    ctaText: 'Ver pacote',
    ctaLink: '/pacotes/porto-de-galinhas',
    displayOrder: 1,
  ),
  _SeedBanner(
    title: 'Patagonia Completa',
    subtitle: 'Roteiro entre Argentina e Chile com suporte Turistar.',
    imageUrl: '${SiteMediaStore.kSiteAssetBaseUrl}/patagonia.jpg',
    ctaText: 'Falar no WhatsApp',
    ctaLink: 'https://wa.me/5511978916580',
    displayOrder: 2,
  ),
];
