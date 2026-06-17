import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turistar_mobile/firebase_options.dart';
import 'package:turistar_mobile/firestore_schema.dart';
import 'package:turistar_mobile/main.dart';
import 'package:turistar_mobile/package_store.dart';
import 'package:turistar_mobile/travel_request_store.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') rethrow;
    }
  });

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    PackageStore.firestoreOverride = fakeFirestore;
    TuristarAuth.replaceSessionForTesting(
      const TuristarSession(
        uid: 'admin-uid',
        email: 'admin@turistar.com.br',
        name: 'Admin Turistar',
        role: TuristarRole.admin,
      ),
    );
  });

  tearDown(() {
    PackageStore.firestoreOverride = null;
    TuristarAuth.replaceSessionForTesting(null);
  });

  group('TravelPackage', () {
    test('priceLabel formats starting price', () {
      final package = TravelPackage.fromMap('aruba', {
        'title': 'Aruba Premium',
        'destinationName': 'Aruba',
        'country': 'Caribe',
        'imageUrl': 'https://example.com/aruba.jpg',
        'startingPrice': 4990,
        'slug': 'aruba',
        'createdAt': '2026-06-15T00:00:00.000Z',
        'updatedAt': '2026-06-15T00:00:00.000Z',
      });

      expect(package.priceLabel, 'A partir de R\$ 4.990');
      expect(package.packagePath, '/pacotes/aruba');
    });

    test('decodes gallery and inclusion lists from json', () {
      final package = TravelPackage.fromMap('gramado', {
        'title': 'Gramado',
        'destinationName': 'Gramado',
        'country': 'Brasil',
        'imageUrl': 'assets/images/packages/gramado.jpg',
        'galleryJson': '["https://example.com/1.jpg","https://example.com/2.jpg"]',
        'inclusionsJson': '["Hotel","Cafe da manha"]',
        'exclusionsJson': '["Ingressos"]',
        'slug': 'gramado',
        'featured': true,
        'active': true,
        'createdAt': '2026-06-15T00:00:00.000Z',
        'updatedAt': '2026-06-15T00:00:00.000Z',
      });

      expect(package.galleryImages, hasLength(2));
      expect(package.inclusions, contains('Hotel'));
      expect(package.exclusions, contains('Ingressos'));
    });
  });

  group('PackageStore', () {
    test('savePackage and getBySlug', () async {
      await PackageStore.savePackage(
        TravelPackage(
          id: '',
          title: 'Orlando Magic',
          destinationName: 'Orlando',
          country: 'EUA',
          imageUrl: 'https://example.com/orlando.jpg',
          startingPrice: 6290,
          description: 'Parques e diversao',
          inclusions: ['Passagem aerea', 'Hotel'],
          exclusions: ['Ingressos'],
          travelPeriod: 'Ano todo',
          duration: '10 dias',
          hotelCategory: '4 estrelas',
          featured: true,
          active: true,
          displayOrder: 1,
          slug: 'orlando',
          seoTitle: 'Pacote Orlando',
          seoDescription: 'Orlando com Turistar',
          createdAt: '2026-06-15T00:00:00.000Z',
          updatedAt: '2026-06-15T00:00:00.000Z',
        ),
      );

      final loaded = await PackageStore.getBySlug('orlando');
      expect(loaded, isNotNull);
      expect(loaded!.title, 'Orlando Magic');
      expect(loaded.startingPrice, 6290);
    });

    test('listPackages filters featured packages', () async {
      await fakeFirestore.collection(FirestoreCollections.packages).doc('aruba').set({
        'title': 'Aruba Premium',
        'destinationName': 'Aruba',
        'country': 'Caribe',
        'imageUrl': 'https://example.com/aruba.jpg',
        'startingPrice': 4990,
        'slug': 'aruba',
        'featured': true,
        'active': true,
        'displayOrder': 1,
        'createdAt': '2026-06-15T00:00:00.000Z',
        'updatedAt': '2026-06-15T00:00:00.000Z',
      });
      await fakeFirestore.collection(FirestoreCollections.packages).doc('hidden').set({
        'title': 'Oculto',
        'destinationName': 'Oculto',
        'country': 'Brasil',
        'imageUrl': 'https://example.com/hidden.jpg',
        'slug': 'oculto',
        'featured': false,
        'active': true,
        'displayOrder': 2,
        'createdAt': '2026-06-15T00:00:00.000Z',
        'updatedAt': '2026-06-15T00:00:00.000Z',
      });

      final featured = await PackageStore.listPackages(activeOnly: true, featuredOnly: true);
      expect(featured, hasLength(1));
      expect(featured.first.slug, 'aruba');
    });
  });

  group('TravelRequestSource', () {
    test('package page source constant', () {
      expect(TravelRequestSource.packagePage, 'PACKAGE_PAGE');
    });
  });
}
