import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:turistar_mobile/firebase_options.dart';
import 'package:turistar_mobile/firestore_schema.dart';

import 'main.dart' show AuthDiagnostics, AuthException, FirebaseBootstrap, LocalAuthStore, TuristarAuth, TuristarRole;

class TravelPackage {
  const TravelPackage({
    required this.id,
    required this.title,
    required this.destinationName,
    required this.country,
    required this.imageUrl,
    this.galleryImages = const [],
    this.startingPrice = 0,
    this.description = '',
    this.inclusions = const [],
    this.exclusions = const [],
    this.travelPeriod = '',
    this.duration = '',
    this.hotelCategory = '',
    this.featured = false,
    this.active = true,
    this.displayOrder = 0,
    required this.slug,
    this.seoTitle = '',
    this.seoDescription = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String destinationName;
  final String country;
  final String imageUrl;
  final List<String> galleryImages;
  final double startingPrice;
  final String description;
  final List<String> inclusions;
  final List<String> exclusions;
  final String travelPeriod;
  final String duration;
  final String hotelCategory;
  final bool featured;
  final bool active;
  final int displayOrder;
  final String slug;
  final String seoTitle;
  final String seoDescription;
  final String createdAt;
  final String updatedAt;

  String get priceLabel {
    if (startingPrice <= 0) return 'Consulte';
    final value = startingPrice % 1 == 0 ? startingPrice.toInt() : startingPrice;
    return 'A partir de R\$ ${_formatPrice(value)} por pessoa';
  }

  String get resolvedSeoTitle =>
      seoTitle.trim().isNotEmpty ? seoTitle.trim() : 'Pacote $title | Turistar Viagens';

  String get resolvedSeoDescription => seoDescription.trim().isNotEmpty
      ? seoDescription.trim()
      : (description.trim().isNotEmpty ? description.trim() : 'Pacote Turistar para $destinationName.');

  String get packagePath => '/pacotes/$slug';

  TravelPackage copyWith({
    String? title,
    String? destinationName,
    String? country,
    String? imageUrl,
    List<String>? galleryImages,
    double? startingPrice,
    String? description,
    List<String>? inclusions,
    List<String>? exclusions,
    String? travelPeriod,
    String? duration,
    String? hotelCategory,
    bool? featured,
    bool? active,
    int? displayOrder,
    String? slug,
    String? seoTitle,
    String? seoDescription,
    String? updatedAt,
  }) {
    return TravelPackage(
      id: id,
      title: title ?? this.title,
      destinationName: destinationName ?? this.destinationName,
      country: country ?? this.country,
      imageUrl: imageUrl ?? this.imageUrl,
      galleryImages: galleryImages ?? this.galleryImages,
      startingPrice: startingPrice ?? this.startingPrice,
      description: description ?? this.description,
      inclusions: inclusions ?? this.inclusions,
      exclusions: exclusions ?? this.exclusions,
      travelPeriod: travelPeriod ?? this.travelPeriod,
      duration: duration ?? this.duration,
      hotelCategory: hotelCategory ?? this.hotelCategory,
      featured: featured ?? this.featured,
      active: active ?? this.active,
      displayOrder: displayOrder ?? this.displayOrder,
      slug: slug ?? this.slug,
      seoTitle: seoTitle ?? this.seoTitle,
      seoDescription: seoDescription ?? this.seoDescription,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'destinationName': destinationName,
        'country': country,
        'imageUrl': imageUrl,
        'galleryJson': PackageJson.encodeStringList(galleryImages),
        'startingPrice': startingPrice,
        'description': description,
        'inclusionsJson': PackageJson.encodeStringList(inclusions),
        'exclusionsJson': PackageJson.encodeStringList(exclusions),
        'travelPeriod': travelPeriod,
        'duration': duration,
        'hotelCategory': hotelCategory,
        'featured': featured,
        'active': active,
        'displayOrder': displayOrder,
        'slug': slug,
        'seoTitle': seoTitle,
        'seoDescription': seoDescription,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory TravelPackage.fromMap(String id, Map<String, dynamic> data) {
    return TravelPackage(
      id: id,
      title: data['title']?.toString() ?? data['destinationName']?.toString() ?? '',
      destinationName: data['destinationName']?.toString() ?? '',
      country: data['country']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ?? '',
      galleryImages: PackageJson.decodeStringList(data['galleryJson'] ?? data['galleryImages']),
      startingPrice: double.tryParse(data['startingPrice']?.toString() ?? '') ?? 0,
      description: data['description']?.toString() ?? '',
      inclusions: PackageJson.decodeStringList(data['inclusionsJson'] ?? data['inclusions']),
      exclusions: PackageJson.decodeStringList(data['exclusionsJson'] ?? data['exclusions']),
      travelPeriod: data['travelPeriod']?.toString() ?? '',
      duration: data['duration']?.toString() ?? '',
      hotelCategory: data['hotelCategory']?.toString() ?? '',
      featured: data['featured'] == true || data['featured']?.toString() == 'true',
      active: data['active'] != false && data['active']?.toString() != 'false',
      displayOrder: int.tryParse(data['displayOrder']?.toString() ?? '') ?? 0,
      slug: data['slug']?.toString() ?? id,
      seoTitle: data['seoTitle']?.toString() ?? '',
      seoDescription: data['seoDescription']?.toString() ?? '',
      createdAt: data['createdAt']?.toString() ?? '',
      updatedAt: data['updatedAt']?.toString() ?? '',
    );
  }

  factory TravelPackage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return TravelPackage.fromMap(doc.id, doc.data() ?? {});
  }

  static String _formatPrice(num value) {
    final raw = value.toStringAsFixed(value is int || value % 1 == 0 ? 0 : 2);
    final parts = raw.split('.');
    final integer = parts.first.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    if (parts.length == 1) return integer;
    return '$integer,${parts[1]}';
  }
}

class PackageJson {
  const PackageJson._();

  static List<String> decodeStringList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  static String encodeStringList(List<String> values) => jsonEncode(values);
}

class PackageStore {
  const PackageStore._();

  static FirebaseFirestore? _firestoreOverride;
  static FirebaseStorage? _storageOverride;

  @visibleForTesting
  static set firestoreOverride(FirebaseFirestore? firestore) {
    _firestoreOverride = firestore;
  }

  @visibleForTesting
  static set storageOverride(FirebaseStorage? storage) {
    _storageOverride = storage;
  }

  static FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  static FirebaseStorage get _storage => _storageOverride ?? FirebaseStorage.instance;

  static String get _projectId => DefaultFirebaseOptions.currentPlatform.projectId;

  static String get _storageBucket => DefaultFirebaseOptions.currentPlatform.storageBucket ?? 'app-turistar.firebasestorage.app';

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

  static Future<Map<String, dynamic>?> _getDocumentViaRest({
    required String collection,
    required String docId,
    required String idToken,
  }) async {
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/$collection/$docId',
    );
    final response = await http.get(uri, headers: {'Authorization': 'Bearer $idToken'});
    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['fields'] is! Map) return null;
    return {
      'id': docId,
      ..._fromRestFields(Map<String, dynamic>.from(decoded['fields'] as Map)),
    };
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
      throw AuthException('firestore-denied', 'Nao foi possivel salvar o pacote.');
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
      throw AuthException('firestore-denied', 'Nao foi possivel salvar o pacote.');
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
      throw AuthException('firestore-denied', 'Nao foi possivel excluir o pacote.');
    }
  }

  static List<TravelPackage> _sortPackages(List<TravelPackage> packages) {
    packages.sort((a, b) {
      final order = a.displayOrder.compareTo(b.displayOrder);
      if (order != 0) return order;
      return a.title.compareTo(b.title);
    });
    return packages;
  }

  static Future<List<TravelPackage>> listPackages({bool activeOnly = false, bool featuredOnly = false}) async {
    if (await _useFirestoreSdk()) {
      try {
        final snap = await _db.collection(FirestoreCollections.packages).orderBy('displayOrder').get();
        var packages = _sortPackages(snap.docs.map(TravelPackage.fromDoc).toList());
        if (activeOnly) packages = packages.where((item) => item.active).toList();
        if (featuredOnly) packages = packages.where((item) => item.featured).toList();
        return packages;
      } catch (error, stackTrace) {
        AuthDiagnostics.step('PACKAGES', 'list SDK falhou', error: error, stack: stackTrace);
      }
    }

    final idToken = await _idToken();
    final rows = idToken == null || idToken.isEmpty
        ? <Map<String, dynamic>>[]
        : await _listCollectionViaRest(collection: FirestoreCollections.packages, idToken: idToken);

    var packages = rows.map((row) {
      final id = row.remove('id')?.toString() ?? '';
      return TravelPackage.fromMap(id, row);
    }).toList();

    if (activeOnly) packages = packages.where((item) => item.active).toList();
    if (featuredOnly) packages = packages.where((item) => item.featured).toList();
    return _sortPackages(packages);
  }

  static Stream<List<TravelPackage>> watchFeaturedPackages() {
    return Stream.fromFuture(_useFirestoreSdk()).asyncExpand((useSdk) async* {
      if (useSdk) {
        yield* _db
            .collection(FirestoreCollections.packages)
            .orderBy('displayOrder')
            .snapshots()
            .map((snapshot) {
              final packages = _sortPackages(snapshot.docs.map(TravelPackage.fromDoc).toList());
              return packages.where((item) => item.active && item.featured).toList();
            });
        return;
      }

      yield await listPackages(activeOnly: true, featuredOnly: true);
      yield* Stream.periodic(const Duration(seconds: 20)).asyncMap((_) => listPackages(activeOnly: true, featuredOnly: true));
    });
  }

  static Stream<List<TravelPackage>> watchAllPackages() {
    _ensureStaffAccess();
    return Stream.fromFuture(_useFirestoreSdk()).asyncExpand((useSdk) async* {
      if (useSdk) {
        yield* _db
            .collection(FirestoreCollections.packages)
            .orderBy('displayOrder')
            .snapshots()
            .map((snapshot) => _sortPackages(snapshot.docs.map(TravelPackage.fromDoc).toList()));
        return;
      }

      yield await listPackages();
      yield* Stream.periodic(const Duration(seconds: 20)).asyncMap((_) => listPackages());
    });
  }

  static Future<TravelPackage?> getBySlug(String slug) async {
    final normalized = slug.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    if (await _useFirestoreSdk()) {
      try {
        final snap = await _db.collection(FirestoreCollections.packages).where('slug', isEqualTo: normalized).limit(1).get();
        if (snap.docs.isEmpty) return null;
        return TravelPackage.fromDoc(snap.docs.first);
      } catch (error, stackTrace) {
        AuthDiagnostics.step('PACKAGES', 'getBySlug SDK falhou', error: error, stack: stackTrace);
      }
    }

    final packages = await listPackages();
    for (final item in packages) {
      if (item.slug.toLowerCase() == normalized) return item;
    }
    return null;
  }

  static Future<TravelPackage?> getById(String id) async {
    if (id.isEmpty) return null;

    if (await _useFirestoreSdk()) {
      final doc = await _db.collection(FirestoreCollections.packages).doc(id).get();
      if (!doc.exists) return null;
      return TravelPackage.fromDoc(doc);
    }

    final idToken = await _idToken();
    if (idToken == null || idToken.isEmpty) return null;
    final row = await _getDocumentViaRest(collection: FirestoreCollections.packages, docId: id, idToken: idToken);
    if (row == null) return null;
    final docId = row.remove('id')?.toString() ?? id;
    return TravelPackage.fromMap(docId, row);
  }

  static Future<TravelPackage> savePackage(TravelPackage package) async {
    _ensureStaffAccess();
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = {
      ...package.toMap(),
      'updatedAt': now,
      if (package.createdAt.isEmpty) 'createdAt': now,
    };

    if (await _useFirestoreSdk()) {
      if (package.id.isEmpty) {
        final doc = await _db.collection(FirestoreCollections.packages).add(payload);
        return TravelPackage.fromMap(doc.id, payload);
      }
      await _db.collection(FirestoreCollections.packages).doc(package.id).set(payload, SetOptions(merge: true));
      return TravelPackage.fromMap(package.id, payload);
    }

    final idToken = await _idToken();
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('firestore-unavailable', 'Nao foi possivel salvar o pacote.');
    }

    if (package.id.isEmpty) {
      final docId = await _createViaRest(
        collection: FirestoreCollections.packages,
        data: payload,
        idToken: idToken,
        docId: package.slug,
      );
      return TravelPackage.fromMap(docId, payload);
    }

    await _patchViaRest(
      collection: FirestoreCollections.packages,
      docId: package.id,
      data: payload,
      idToken: idToken,
    );
    return TravelPackage.fromMap(package.id, payload);
  }

  static Future<void> deletePackage(String id) async {
    _ensureStaffAccess();
    if (id.isEmpty) return;

    if (await _useFirestoreSdk()) {
      await _db.collection(FirestoreCollections.packages).doc(id).delete();
      return;
    }

    final idToken = await _idToken();
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('firestore-unavailable', 'Nao foi possivel excluir o pacote.');
    }
    await _deleteViaRest(collection: FirestoreCollections.packages, docId: id, idToken: idToken);
  }

  static Future<String> uploadPackageImage({
    required String slug,
    required Uint8List bytes,
    required String fileName,
    String? contentType,
  }) async {
    _ensureStaffAccess();
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = 'packages/$slug/$safeName';

    if (await _useFirestoreSdk()) {
      try {
        final ref = _storage.ref(path);
        await ref.putData(bytes, SettableMetadata(contentType: contentType ?? 'image/jpeg'));
        return await ref.getDownloadURL();
      } catch (error, stackTrace) {
        AuthDiagnostics.step('PACKAGES', 'upload SDK falhou', error: error, stack: stackTrace);
      }
    }

    final idToken = await _idToken();
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('storage-unavailable', 'Nao foi possivel enviar a imagem.');
    }

    final uri = Uri.parse(
      'https://firebasestorage.googleapis.com/v0/b/$_storageBucket/o?uploadType=media&name=${Uri.encodeComponent(path)}',
    );
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': contentType ?? 'image/jpeg',
      },
      body: bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException('storage-denied', 'Upload da imagem falhou (${response.statusCode}).');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['downloadTokens'] != null) {
      final token = decoded['downloadTokens'].toString().split(',').first;
      return 'https://firebasestorage.googleapis.com/v0/b/$_storageBucket/o/${Uri.encodeComponent(path)}?alt=media&token=$token';
    }
    return 'https://firebasestorage.googleapis.com/v0/b/$_storageBucket/o/${Uri.encodeComponent(path)}?alt=media';
  }

  static Future<void> seedDefaultPackagesIfEmpty() async {
    _ensureStaffAccess();
    final existing = await listPackages();
    if (existing.isNotEmpty) return;

    final now = DateTime.now().toUtc().toIso8601String();
    for (final seed in kDefaultTravelPackages) {
      await savePackage(
        TravelPackage(
          id: '',
          title: seed.title,
          destinationName: seed.destinationName,
          country: seed.country,
          imageUrl: seed.imageUrl,
          galleryImages: seed.galleryImages,
          startingPrice: seed.startingPrice,
          description: seed.description,
          inclusions: seed.inclusions,
          exclusions: seed.exclusions,
          travelPeriod: seed.travelPeriod,
          duration: seed.duration,
          hotelCategory: seed.hotelCategory,
          featured: seed.featured,
          active: true,
          displayOrder: seed.displayOrder,
          slug: seed.slug,
          seoTitle: seed.seoTitle,
          seoDescription: seed.seoDescription,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }
}

class _SeedPackage {
  const _SeedPackage({
    required this.title,
    required this.destinationName,
    required this.country,
    required this.imageUrl,
    required this.slug,
    required this.startingPrice,
    required this.description,
    required this.travelPeriod,
    required this.duration,
    required this.hotelCategory,
    required this.inclusions,
    required this.exclusions,
    required this.displayOrder,
    required this.featured,
    required this.seoTitle,
    required this.seoDescription,
    this.galleryImages = const [],
  });

  final String title;
  final String destinationName;
  final String country;
  final String imageUrl;
  final List<String> galleryImages;
  final String slug;
  final double startingPrice;
  final String description;
  final String travelPeriod;
  final String duration;
  final String hotelCategory;
  final List<String> inclusions;
  final List<String> exclusions;
  final int displayOrder;
  final bool featured;
  final String seoTitle;
  final String seoDescription;
}

const List<_SeedPackage> kDefaultTravelPackages = [
  _SeedPackage(
    title: 'Aruba Premium',
    destinationName: 'Aruba',
    country: 'Caribe',
    slug: 'aruba',
    imageUrl: 'assets/images/packages/porto-de-galinhas.jpg',
    startingPrice: 4990,
    description: 'Praias paradisiacas e mar cristalino no Caribe.',
    travelPeriod: 'Marco a Novembro',
    duration: '7 dias',
    hotelCategory: '4 estrelas',
    inclusions: ['Passagem aerea', 'Hotel', 'Cafe da manha', 'Seguro viagem', 'Transfer'],
    exclusions: ['Passeios opcionais', 'Taxas locais'],
    displayOrder: 1,
    featured: true,
    seoTitle: 'Pacote Aruba Premium | Turistar Viagens',
    seoDescription: 'Pacote para Aruba com passagem, hotel, cafe da manha, seguro e transfer.',
  ),
  _SeedPackage(
    title: 'Chile Encantador',
    destinationName: 'Chile',
    country: 'America do Sul',
    slug: 'chile',
    imageUrl: 'assets/images/packages/patagonia.jpg',
    startingPrice: 3890,
    description: 'Santiago, Valparaiso e paisagens dos Andes.',
    travelPeriod: 'Abril a Outubro',
    duration: '8 dias',
    hotelCategory: '3 estrelas',
    inclusions: ['Passagem aerea', 'Hotel', 'Cafe da manha', 'City tour'],
    exclusions: ['Passeios opcionais', 'Almoco e jantar'],
    displayOrder: 2,
    featured: true,
    seoTitle: 'Pacote Chile | Turistar Viagens',
    seoDescription: 'Conheca o Chile com roteiro completo e hospedagem inclusa.',
  ),
  _SeedPackage(
    title: 'Gramado & Serra Gaucha',
    destinationName: 'Gramado',
    country: 'Brasil',
    slug: 'gramado',
    imageUrl: 'assets/images/packages/gramado.jpg',
    startingPrice: 1890,
    description: 'Serra gaucha com passeios, gastronomia e clima europeu.',
    travelPeriod: 'Maio a Setembro',
    duration: '4 noites',
    hotelCategory: '3 estrelas',
    inclusions: ['Onibus', 'Hotel', 'Cafe da manha', 'City tour'],
    exclusions: ['Ingressos de parques', 'Refeicoes extras'],
    displayOrder: 3,
    featured: true,
    seoTitle: 'Pacote Gramado | Turistar Viagens',
    seoDescription: 'Pacote para Gramado com hotel, cafe da manha e city tour.',
  ),
  _SeedPackage(
    title: 'Orlando Magic',
    destinationName: 'Orlando',
    country: 'Estados Unidos',
    slug: 'orlando',
    imageUrl: 'assets/images/packages/maragogi.jpg',
    startingPrice: 6290,
    description: 'Parques tematicos, compras e diversao para toda a familia.',
    travelPeriod: 'Janeiro a Dezembro',
    duration: '10 dias',
    hotelCategory: '4 estrelas',
    inclusions: ['Passagem aerea', 'Hotel', 'Transfer aeroporto', 'Seguro viagem'],
    exclusions: ['Ingressos de parques', 'Alimentacao'],
    displayOrder: 4,
    featured: true,
    seoTitle: 'Pacote Orlando | Turistar Viagens',
    seoDescription: 'Viva a magia de Orlando com pacote completo Turistar.',
  ),
  _SeedPackage(
    title: 'Porto de Galinhas',
    destinationName: 'Porto de Galinhas',
    country: 'Brasil',
    slug: 'porto-de-galinhas',
    imageUrl: 'assets/images/packages/porto-de-galinhas.jpg',
    startingPrice: 2190,
    description: 'Aereo + hospedagem + traslados inclusos.',
    travelPeriod: 'Ano todo',
    duration: '7 noites',
    hotelCategory: '3 estrelas',
    inclusions: ['Passagem aerea', 'Hotel', 'Transfer', 'Cafe da manha'],
    exclusions: ['Passeios de buggy', 'Taxas locais'],
    displayOrder: 5,
    featured: true,
    seoTitle: 'Pacote Porto de Galinhas | Turistar Viagens',
    seoDescription: 'Férias em Porto de Galinhas com pacote completo.',
  ),
];
