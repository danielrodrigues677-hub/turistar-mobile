import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turistar_mobile/firebase_options.dart';
import 'package:turistar_mobile/main.dart';

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
    fakeFirestore = FakeFirebaseFirestore();
    FirestoreAuthStore.firestoreOverride = fakeFirestore;
  });

  tearDownAll(() {
    FirestoreAuthStore.firestoreOverride = null;
  });

  test('saves and validates user credentials in Firestore', () async {
    await FirestoreAuthStore.register(
      name: 'Daniel Turistar',
      email: 'cliente@turistar.com.br',
      phone: '11999990000',
      password: 'senha123',
    );

    final session = await FirestoreAuthStore.login(
      email: 'cliente@turistar.com.br',
      password: 'senha123',
    );

    expect(session.name, 'Daniel Turistar');
    expect(session.email, 'cliente@turistar.com.br');

    final doc = await fakeFirestore.collection('users').doc('cliente_at_turistar_dot_com_dot_br').get();
    expect(doc.exists, isTrue);
    expect(session.phone, '11999990000');
  });

  test('finds legacy Firestore document id with raw email', () async {
    await fakeFirestore.collection('users').doc('legado@turistar.com.br').set({
      'email': 'legado@turistar.com.br',
      'name': 'Usuario Legado',
      'phone': '11999990001',
      'passwordHash': LocalAuthStore.hashPassword('senha123'),
      'createdAt': '2026-06-12T00:00:00.000Z',
    });

    final session = await FirestoreAuthStore.login(
      email: 'legado@turistar.com.br',
      password: 'senha123',
    );

    expect(session.name, 'Usuario Legado');
  });

  test('rejects duplicate registration', () async {
    await FirestoreAuthStore.register(
      name: 'Primeiro',
      email: 'duplicado@turistar.com.br',
      phone: '11000000000',
      password: 'abc123',
    );

    expect(
      () => FirestoreAuthStore.register(
        name: 'Segundo',
        email: 'duplicado@turistar.com.br',
        phone: '11000000001',
        password: 'xyz789',
      ),
      throwsA(isA<AuthException>()),
    );
  });
}
