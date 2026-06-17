import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:turistar_mobile/firebase_options.dart';
import 'package:turistar_mobile/firestore_schema.dart';

import 'admin_permissions.dart';
import 'main.dart' show AuthDiagnostics, AuthException, FirebaseBootstrap, LocalAuthStore;
import 'package_store.dart';

class FeaturedPackage {
  const FeaturedPackage({
    required this.id,
    required this.packageId,
    required this.title,
    required this.imageUrl,
    this.price = 0,
    this.promotionalText = '',
    this.active = true,
    this.displayOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String packageId;
  final String title;
  final String imageUrl;
  final double price;
  final String promotionalText;
  final bool active;
  final int displayOrder;
  final String createdAt;
  final String updatedAt;

  String get priceLabel {
    if (promotionalText.trim().isNotEmpty) return promotionalText.trim();
    if (price <= 0) return 'Consulte';
    final value = price % 1 == 0 ? price.toInt() : price;
    return 'A partir de R\$ ${_formatPrice(value)}';
  }

  Map<String, dynamic> toMap() => {
        'packageId': packageId,
        'title': title,
        'imageUrl': imageUrl,
        'price': price,
        'promotionalText': promotionalText,
        'active': active,
        'displayOrder': displayOrder,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory FeaturedPackage.fromMap(String id, Map<String, dynamic> data) {
    return FeaturedPackage(
      id: id,
      packageId: data['packageId']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ?? '',
      price: double.tryParse(data['price']?.toString() ?? '') ?? 0,
      promotionalText: data['promotionalText']?.toString() ?? '',
      active: data['active'] != false && data['active']?.toString() != 'false',
      displayOrder: int.tryParse(data['displayOrder']?.toString() ?? '') ?? 0,
      createdAt: data['createdAt']?.toString() ?? '',
      updatedAt: data['updatedAt']?.toString() ?? '',
    );
  }

  factory FeaturedPackage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return FeaturedPackage.fromMap(doc.id, doc.data() ?? {});
  }

  FeaturedPackage copyWith({
    String? packageId,
    String? title,
    String? imageUrl,
    double? price,
    String? promotionalText,
    bool? active,
    int? displayOrder,
    String? updatedAt,
  }) {
    return FeaturedPackage(
      id: id,
      packageId: packageId ?? this.packageId,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      promotionalText: promotionalText ?? this.promotionalText,
      active: active ?? this.active,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  TravelPackage toDisplayPackage({TravelPackage? linked}) {
    final base = linked;
    final slug = base?.slug ?? (packageId.isNotEmpty ? packageId : id);
    final now = DateTime.now().toUtc().toIso8601String();
    return TravelPackage(
      id: base?.id ?? packageId,
      title: title.isNotEmpty ? title : (base?.title ?? 'Pacote Turistar'),
      destinationName: base?.destinationName ?? title,
      country: base?.country ?? '',
      city: base?.city ?? '',
      shortDescription: base?.shortDescription ?? '',
      imageUrl: imageUrl.isNotEmpty ? imageUrl : (base?.imageUrl ?? ''),
      galleryImages: base?.galleryImages ?? const [],
      startingPrice: price > 0 ? price : (base?.startingPrice ?? 0),
      promotionalText: promotionalText,
      description: base?.description ?? '',
      inclusions: base?.inclusions ?? const [],
      exclusions: base?.exclusions ?? const [],
      travelPeriod: base?.travelPeriod ?? '',
      duration: base?.duration ?? '',
      nights: base?.nights ?? 0,
      hotelCategory: base?.hotelCategory ?? '',
      category: base?.category ?? '',
      featured: true,
      active: active,
      displayOrder: displayOrder,
      slug: slug,
      seoTitle: base?.seoTitle ?? '',
      seoDescription: base?.seoDescription ?? '',
      createdAt: base?.createdAt ?? (createdAt.isEmpty ? now : createdAt),
      updatedAt: updatedAt,
    );
  }

  static String _formatPrice(num value) {
    final raw = value.toStringAsFixed(value is int || value % 1 == 0 ? 0 : 2);
    final parts = raw.split('.');
    final integer = parts.first.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    if (parts.length == 1) return integer;
    return '$integer,${parts[1]}';
  }
}

class FeaturedPackagesStore {
  const FeaturedPackagesStore._();

  static FirebaseFirestore? _firestoreOverride;

  @visibleForTesting
  static set firestoreOverride(FirebaseFirestore? firestore) {
    _firestoreOverride = firestore;
  }

  static FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  static String get _projectId => DefaultFirebaseOptions.currentPlatform.projectId;

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
      if (value.containsKey('stringValue')) data[key] = value['stringValue'];
      if (value.containsKey('integerValue')) data[key] = int.tryParse(value['integerValue'].toString()) ?? value['integerValue'];
      if (value.containsKey('doubleValue')) data[key] = double.tryParse(value['doubleValue'].toString()) ?? value['doubleValue'];
      if (value.containsKey('booleanValue')) data[key] = value['booleanValue'];
    });
    return data;
  }

  static Map<String, dynamic> _toRestFields(Map<String, dynamic> data) {
    final fields = <String, dynamic>{};
    data.forEach((key, value) {
      if (value == null) return;
      if (value is String) fields[key] = {'stringValue': value};
      if (value is int) fields[key] = {'integerValue': value.toString()};
      if (value is double) fields[key] = {'doubleValue': value};
      if (value is bool) fields[key] = {'booleanValue': value};
    });
    return fields;
  }

  static String _docIdFromRestName(String? name) {
    if (name == null || name.isEmpty) return '';
    return name.split('/').last;
  }

  static Future<List<Map<String, dynamic>>> _listViaRest(String collection, String idToken) async {
    final uri = Uri.parse('https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents:runQuery');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $idToken'},
      body: jsonEncode({
        'structuredQuery': {
          'from': [
            {'collectionId': collection},
          ],
          'orderBy': [
            {'field': {'fieldPath': 'displayOrder'}, 'direction': 'ASCENDING'},
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
      results.add({'id': _docIdFromRestName(doc['name']?.toString()), ..._fromRestFields(fields)});
    }
    return results;
  }

  static List<FeaturedPackage> _sort(List<FeaturedPackage> items) {
    items.sort((a, b) {
      final order = a.displayOrder.compareTo(b.displayOrder);
      if (order != 0) return order;
      return a.title.compareTo(b.title);
    });
    return items;
  }

  static Future<List<FeaturedPackage>> listFeatured({bool activeOnly = false}) async {
    if (await _useFirestoreSdk()) {
      try {
        final snap = await _db.collection(FirestoreCollections.featuredPackages).orderBy('displayOrder').get();
        var items = _sort(snap.docs.map(FeaturedPackage.fromDoc).toList());
        if (activeOnly) items = items.where((item) => item.active).toList();
        return items;
      } catch (error, stackTrace) {
        AuthDiagnostics.step('FEATURED', 'list SDK falhou', error: error, stack: stackTrace);
      }
    }
    final idToken = await _idToken();
    if (idToken == null || idToken.isEmpty) return [];
    final rows = await _listViaRest(FirestoreCollections.featuredPackages, idToken);
    var items = rows.map((row) {
      final id = row.remove('id')?.toString() ?? '';
      return FeaturedPackage.fromMap(id, row);
    }).toList();
    if (activeOnly) items = items.where((item) => item.active).toList();
    return _sort(items);
  }

  static Stream<List<FeaturedPackage>> watchFeatured({bool activeOnly = false}) {
    AdminPermissions.requireConsultorOrAdmin();
    return Stream.fromFuture(_useFirestoreSdk()).asyncExpand((useSdk) async* {
      if (useSdk) {
        yield* _db.collection(FirestoreCollections.featuredPackages).orderBy('displayOrder').snapshots().map((snapshot) {
          var items = _sort(snapshot.docs.map(FeaturedPackage.fromDoc).toList());
          if (activeOnly) items = items.where((item) => item.active).toList();
          return items;
        });
        return;
      }
      yield await listFeatured(activeOnly: activeOnly);
      yield* Stream.periodic(const Duration(seconds: 20)).asyncMap((_) => listFeatured(activeOnly: activeOnly));
    });
  }

  static Stream<List<TravelPackage>> watchHomePackages() {
    return Stream.fromFuture(_useFirestoreSdk()).asyncExpand((useSdk) async* {
      Future<List<TravelPackage>> load() async {
        final featured = await listFeatured(activeOnly: true);
        if (featured.isNotEmpty) {
          final packages = await PackageStore.listPackages(activeOnly: true);
          final byId = {for (final item in packages) item.id: item};
          final bySlug = {for (final item in packages) item.slug: item};
          return featured.map((item) {
            final linked = byId[item.packageId] ?? bySlug[item.packageId];
            return item.toDisplayPackage(linked: linked);
          }).toList();
        }
        final fallback = await PackageStore.listPackages(activeOnly: true, featuredOnly: true);
        if (fallback.isNotEmpty) return fallback;
        return <TravelPackage>[];
      }

      if (useSdk) {
        yield* _db.collection(FirestoreCollections.featuredPackages).orderBy('displayOrder').snapshots().asyncMap((_) => load());
        return;
      }
      yield await load();
      yield* Stream.periodic(const Duration(seconds: 20)).asyncMap((_) => load());
    });
  }

  static Future<FeaturedPackage> saveFeatured(FeaturedPackage item) async {
    AdminPermissions.requireConsultorOrAdmin();
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = {
      ...item.toMap(),
      'updatedAt': now,
      if (item.createdAt.isEmpty) 'createdAt': now,
    };

    if (await _useFirestoreSdk()) {
      if (item.id.isEmpty) {
        final doc = await _db.collection(FirestoreCollections.featuredPackages).add(payload);
        return FeaturedPackage.fromMap(doc.id, payload);
      }
      await _db.collection(FirestoreCollections.featuredPackages).doc(item.id).set(payload, SetOptions(merge: true));
      return FeaturedPackage.fromMap(item.id, payload);
    }

    final idToken = await _idToken();
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('firestore-unavailable', 'Nao foi possivel salvar o destaque.');
    }
    throw const AuthException('firestore-unavailable', 'Salvar destaques requer conexao com Firestore.');
  }

  static Future<void> deleteFeatured(String id) async {
    AdminPermissions.requireConsultorOrAdmin();
    if (id.isEmpty) return;
    if (await _useFirestoreSdk()) {
      await _db.collection(FirestoreCollections.featuredPackages).doc(id).delete();
      return;
    }
    throw const AuthException('firestore-unavailable', 'Nao foi possivel excluir o destaque.');
  }

  static Future<void> reorderFeatured(List<FeaturedPackage> items) async {
    AdminPermissions.requireConsultorOrAdmin();
    final now = DateTime.now().toUtc().toIso8601String();
    for (var i = 0; i < items.length; i++) {
      await saveFeatured(items[i].copyWith(displayOrder: i, updatedAt: now));
    }
  }
}
