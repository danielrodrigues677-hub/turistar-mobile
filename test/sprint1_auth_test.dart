import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turistar_mobile/firebase_options.dart';
import 'package:turistar_mobile/firestore_schema.dart';
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

  group('TuristarSession', () {
    test('serializes uid and role', () {
      const session = TuristarSession(
        uid: 'uid-123',
        email: 'cliente@turistar.com.br',
        name: 'Cliente',
        phone: '11999990000',
        role: TuristarRole.customer,
      );

      final restored = TuristarSession.fromJson(session.toJson());
      expect(restored.uid, 'uid-123');
      expect(restored.role, TuristarRole.customer);
      expect(restored.email, 'cliente@turistar.com.br');
    });

    test('defaults invalid role to customer', () {
      final session = TuristarSession.fromJson({
        'email': 'a@b.com',
        'name': 'A',
        'role': 'unknown',
      });
      expect(session.role, TuristarRole.customer);
    });
  });

  group('FirestoreAuthStore.saveUserProfile', () {
    test('creates uid-based profile with customer role', () async {
      await FirestoreAuthStore.saveUserProfile(
        uid: 'firebase-uid-1',
        email: 'cliente@turistar.com.br',
        name: 'Daniel Turistar',
        phone: '11999990000',
      );

      final doc = await fakeFirestore.collection(FirestoreCollections.users).doc('firebase-uid-1').get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['role'], TuristarRole.customer);
      expect(doc.data()?['email'], 'cliente@turistar.com.br');
      expect(doc.data()?.containsKey('passwordHash'), isFalse);
    });

    test('fetchProfile returns role and uid', () async {
      await FirestoreAuthStore.saveUserProfile(
        uid: 'firebase-uid-2',
        email: 'agente@turistar.com.br',
        name: 'Agente',
        phone: '11999990001',
        role: TuristarRole.agent,
      );

      final profile = await FirestoreAuthStore.fetchProfile(
        'agente@turistar.com.br',
        uid: 'firebase-uid-2',
      );

      expect(profile, isNotNull);
      expect(profile!.uid, 'firebase-uid-2');
      expect(profile.role, TuristarRole.agent);
      expect(profile.name, 'Agente');
    });
  });

  group('LocalAuthStore session persistence', () {
    test('persists and restores JSON session profile', () async {
      const session = TuristarSession(
        uid: 'uid-local',
        email: 'persist@turistar.com.br',
        name: 'Persist',
        role: TuristarRole.customer,
      );

      await LocalAuthStore.saveSessionProfile(session: session, rememberMe: true);
      final restored = await LocalAuthStore.loadSessionProfile();

      expect(restored, isNotNull);
      expect(restored!.uid, 'uid-local');
      expect(restored.email, 'persist@turistar.com.br');
      expect(restored.name, 'Persist');
    });

    test('migrates legacy email-only session key', () async {
      SharedPreferences.setMockInitialValues({
        LocalAuthStore.sessionEmailKey: 'legado@turistar.com.br',
      });

      final restored = await LocalAuthStore.loadSessionProfile();
      expect(restored, isNotNull);
      expect(restored!.email, 'legado@turistar.com.br');
    });
  });

  group('TuristarRole helpers', () {
    test('validates known roles', () {
      expect(TuristarRole.isValid(TuristarRole.customer), isTrue);
      expect(TuristarRole.isValid(TuristarRole.agent), isTrue);
      expect(TuristarRole.isValid(TuristarRole.admin), isTrue);
      expect(TuristarRole.isValid('master'), isFalse);
    });
  });

  group('FirestoreCollections', () {
    test('defines sprint 1 collections', () {
      expect(FirestoreCollections.users, 'users');
      expect(FirestoreCollections.travelRequests, 'travel_requests');
      expect(FirestoreCollections.quotes, 'quotes');
      expect(FirestoreCollections.bookings, 'bookings');
      expect(FirestoreCollections.packages, 'packages');
      expect(FirestoreCollections.offers, 'offers');
    });
  });

  test('session JSON roundtrip keeps encoded email', () {
    const session = TuristarSession(
      email: 'roundtrip@turistar.com.br',
      name: 'Roundtrip',
      role: TuristarRole.customer,
    );
    final encoded = jsonEncode(session.toJson());
    expect(encoded, contains('roundtrip@turistar.com.br'));
  });
}
