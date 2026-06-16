import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turistar_mobile/firebase_options.dart';
import 'package:turistar_mobile/firestore_schema.dart';
import 'package:turistar_mobile/main.dart';
import 'package:turistar_mobile/travel_request_store.dart';

void main() {
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

  group('TravelRequest', () {
    test('maps firestore document fields', () {
      final request = TravelRequest.fromMap('req-1', {
        'userId': 'uid-1',
        'userEmail': 'cliente@turistar.com.br',
        'origin': 'Sao Paulo',
        'destination': 'Lisboa',
        'departureDate': '2026-08-10',
        'returnDate': '2026-08-20',
        'passengers': 2,
        'notes': 'Classe executiva',
        'status': TravelRequestStatus.newRequest,
        'createdAt': '2026-06-15T00:00:00.000Z',
        'updatedAt': '2026-06-15T00:00:00.000Z',
      });

      expect(request.routeLabel, 'Sao Paulo → Lisboa');
      expect(request.passengers, 2);
      expect(TravelRequestStatus.label(request.status), 'Nova');
    });
  });

  group('CustomerAreaStore', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      CustomerAreaStore.firestoreOverride = fakeFirestore;
      TuristarAuth.replaceSessionForTesting(
        TuristarSession(
          uid: 'uid-customer',
          email: 'cliente@turistar.com.br',
          name: 'Cliente Turistar',
          role: TuristarRole.customer,
        ),
      );
    });

    tearDown(() {
      CustomerAreaStore.firestoreOverride = null;
      TuristarAuth.replaceSessionForTesting(null);
    });

    test('creates travel request document for current user', () async {
      final request = await CustomerAreaStore.createTravelRequest(
        origin: 'Campinas',
        destination: 'Paris',
        departureDate: '2026-09-01',
        returnDate: '2026-09-15',
        passengers: 3,
        notes: 'Lua de mel',
      );

      expect(request.origin, 'Campinas');
      expect(request.destination, 'Paris');
      expect(request.status, TravelRequestStatus.newRequest);

      final docs = await fakeFirestore.collection(FirestoreCollections.travelRequests).get();
      expect(docs.docs, hasLength(1));
      expect(docs.docs.first.data()['userId'], 'uid-customer');
      expect(docs.docs.first.data()['notes'], 'Lua de mel');
    });

    test('lists travel requests by user id', () async {
      await fakeFirestore.collection(FirestoreCollections.travelRequests).add({
        'userId': 'uid-customer',
        'userEmail': 'cliente@turistar.com.br',
        'origin': 'GRU',
        'destination': 'MIA',
        'departureDate': '2026-07-01',
        'passengers': 1,
        'notes': '',
        'status': TravelRequestStatus.newRequest,
        'createdAt': '2026-06-15T00:00:00.000Z',
        'updatedAt': '2026-06-15T00:00:00.000Z',
      });

      final requests = await CustomerAreaStore.listTravelRequests();
      expect(requests, hasLength(1));
      expect(requests.first.destination, 'MIA');
    });
  });
}
