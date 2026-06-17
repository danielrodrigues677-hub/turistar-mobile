import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turistar_mobile/featured_packages_store.dart';
import 'package:turistar_mobile/firebase_options.dart';
import 'package:turistar_mobile/firestore_schema.dart';
import 'package:turistar_mobile/main.dart';
import 'package:turistar_mobile/site_media_store.dart';

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
    SiteMediaStore.firestoreOverride = fakeFirestore;
    FeaturedPackagesStore.firestoreOverride = fakeFirestore;
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
    SiteMediaStore.firestoreOverride = null;
    FeaturedPackagesStore.firestoreOverride = null;
    TuristarAuth.replaceSessionForTesting(null);
  });

  group('SiteMediaStore banners', () {
    test('saveBanner persists imageUrl in Firestore', () async {
      final saved = await SiteMediaStore.saveBanner(
        SiteBanner(
          id: '',
          title: 'Promo Verao',
          subtitle: 'Ofertas especiais',
          imageUrl: 'https://cdn.example.com/banners/promo.jpg',
          ctaText: 'Ver pacotes',
          ctaLink: '/pacotes/aruba',
          active: true,
          displayOrder: 1,
          createdAt: '',
          updatedAt: '',
        ),
      );

      expect(saved.id, isNotEmpty);
      final banners = await SiteMediaStore.listBanners();
      expect(banners, hasLength(1));
      expect(banners.first.title, 'Promo Verao');
      expect(banners.first.imageUrl, contains('banners'));
    });

    test('seedDefaultBannersIfEmpty creates starter banners', () async {
      await SiteMediaStore.seedDefaultBannersIfEmpty();
      final banners = await SiteMediaStore.listBanners();
      expect(banners, hasLength(3));
      expect(banners.first.imageUrl, contains('gramado.jpg'));
    });
  });

  group('FeaturedPackagesStore', () {
    test('saveFeatured persists display data', () async {
      final saved = await FeaturedPackagesStore.saveFeatured(
        FeaturedPackage(
          id: '',
          packageId: 'aruba',
          title: 'Aruba Premium',
          imageUrl: 'https://cdn.example.com/aruba.jpg',
          price: 4990,
          promotionalText: 'A partir de R\$ 4.990',
          active: true,
          displayOrder: 1,
          createdAt: '',
          updatedAt: '',
        ),
      );
      expect(saved.id, isNotEmpty);
      final items = await FeaturedPackagesStore.listFeatured();
      expect(items.first.promotionalText, 'A partir de R\$ 4.990');
    });
  });
}
