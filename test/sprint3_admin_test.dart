import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turistar_mobile/admin_store.dart';
import 'package:turistar_mobile/firebase_options.dart';
import 'package:turistar_mobile/firestore_schema.dart';
import 'package:turistar_mobile/main.dart';
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
    AdminStore.firestoreOverride = fakeFirestore;
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
    AdminStore.firestoreOverride = null;
    TuristarAuth.replaceSessionForTesting(null);
  });

  group('TravelRequestStatus', () {
    test('labels sprint 3 statuses', () {
      expect(TravelRequestStatus.label(TravelRequestStatus.newRequest), 'Nova');
      expect(TravelRequestStatus.label(TravelRequestStatus.inAnalysis), 'Em analise');
      expect(TravelRequestStatus.label(TravelRequestStatus.quoting), 'Orcamentando');
      expect(TravelRequestStatus.label(TravelRequestStatus.waitingClient), 'Aguardando cliente');
      expect(TravelRequestStatus.label(TravelRequestStatus.confirmed), 'Confirmada');
      expect(TravelRequestStatus.label(TravelRequestStatus.cancelled), 'Cancelada');
    });

    test('normalizes legacy pending status', () {
      expect(TravelRequestStatus.normalize('pending'), TravelRequestStatus.newRequest);
      expect(TravelRequestStatus.normalize('in_review'), TravelRequestStatus.inAnalysis);
    });
  });

  group('AdminStore', () {
    test('fetchDashboardStats counts clients requests and bookings', () async {
      await fakeFirestore.collection(FirestoreCollections.users).doc('client-1').set({
        'email': 'cliente@turistar.com.br',
        'name': 'Cliente',
        'phone': '11999990000',
        'role': TuristarRole.customer,
        'createdAt': '2026-06-15T00:00:00.000Z',
        'updatedAt': '2026-06-15T00:00:00.000Z',
      });
      await fakeFirestore.collection(FirestoreCollections.travelRequests).add({
        'userId': 'client-1',
        'userEmail': 'cliente@turistar.com.br',
        'origin': 'GRU',
        'destination': 'LIS',
        'departureDate': '2026-08-01',
        'passengers': 2,
        'status': TravelRequestStatus.newRequest,
        'createdAt': '2026-06-15T00:00:00.000Z',
        'updatedAt': '2026-06-15T00:00:00.000Z',
      });
      await fakeFirestore.collection(FirestoreCollections.bookings).add({
        'userId': 'client-1',
        'status': 'confirmada',
        'createdAt': '2026-06-15T00:00:00.000Z',
        'updatedAt': '2026-06-15T00:00:00.000Z',
      });

      final stats = await AdminStore.fetchDashboardStats();
      expect(stats.totalClients, 1);
      expect(stats.totalRequests, 1);
      expect(stats.totalBookings, 1);
    });

    test('searchClients filters by email', () async {
      await fakeFirestore.collection(FirestoreCollections.users).doc('client-1').set({
        'email': 'cliente@turistar.com.br',
        'name': 'Cliente Um',
        'phone': '11999990000',
        'role': TuristarRole.customer,
        'createdAt': '2026-06-15T00:00:00.000Z',
        'updatedAt': '2026-06-15T00:00:00.000Z',
      });
      await fakeFirestore.collection(FirestoreCollections.users).doc('client-2').set({
        'email': 'outro@turistar.com.br',
        'name': 'Cliente Dois',
        'phone': '11999990001',
        'role': TuristarRole.customer,
        'createdAt': '2026-06-15T00:00:00.000Z',
        'updatedAt': '2026-06-15T00:00:00.000Z',
      });

      final results = await AdminStore.searchClients('cliente@');
      expect(results, hasLength(1));
      expect(results.first.email, 'cliente@turistar.com.br');
    });

    test('listTravelRequests filters by status', () async {
      await fakeFirestore.collection(FirestoreCollections.travelRequests).add({
        'userId': 'client-1',
        'userEmail': 'cliente@turistar.com.br',
        'origin': 'GRU',
        'destination': 'MIA',
        'departureDate': '2026-08-01',
        'passengers': 1,
        'status': TravelRequestStatus.newRequest,
        'createdAt': '2026-06-15T00:00:00.000Z',
        'updatedAt': '2026-06-15T00:00:00.000Z',
      });
      await fakeFirestore.collection(FirestoreCollections.travelRequests).add({
        'userId': 'client-1',
        'userEmail': 'cliente@turistar.com.br',
        'origin': 'GRU',
        'destination': 'BCN',
        'departureDate': '2026-09-01',
        'passengers': 2,
        'status': TravelRequestStatus.inAnalysis,
        'createdAt': '2026-06-16T00:00:00.000Z',
        'updatedAt': '2026-06-16T00:00:00.000Z',
      });

      final filtered = await AdminStore.listTravelRequests(statusFilter: TravelRequestStatus.inAnalysis);
      expect(filtered, hasLength(1));
      expect(filtered.first.destination, 'BCN');
    });

    test('updateTravelRequestStatus changes document status', () async {
      final doc = await fakeFirestore.collection(FirestoreCollections.travelRequests).add({
        'userId': 'client-1',
        'userEmail': 'cliente@turistar.com.br',
        'origin': 'GRU',
        'destination': 'PAR',
        'departureDate': '2026-10-01',
        'passengers': 1,
        'status': TravelRequestStatus.newRequest,
        'createdAt': '2026-06-15T00:00:00.000Z',
        'updatedAt': '2026-06-15T00:00:00.000Z',
      });

      await AdminStore.updateTravelRequestStatus(
        requestId: doc.id,
        status: TravelRequestStatus.quoting,
      );

      final updated = await doc.get();
      expect(updated.data()?['status'], TravelRequestStatus.quoting);
    });

    test('blocks non-staff users', () async {
      TuristarAuth.replaceSessionForTesting(
        const TuristarSession(
          uid: 'client-uid',
          email: 'cliente@turistar.com.br',
          name: 'Cliente',
          role: TuristarRole.customer,
        ),
      );

      expect(
        () => AdminStore.listTravelRequests(),
        throwsA(predicate<AuthException>((error) => error.code == 'permission-denied')),
      );
    });
  });
}
