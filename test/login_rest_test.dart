import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turistar_mobile/main.dart';

void main() {
  group('firebaseAuthExceptionFromIdentityToolkitMessage (login)', () {
    test('maps INVALID_LOGIN_CREDENTIALS', () {
      final error = firebaseAuthExceptionFromIdentityToolkitMessage('INVALID_LOGIN_CREDENTIALS');
      expect(error.code, 'invalid-credential');
    });

    test('maps INVALID_PASSWORD', () {
      final error = firebaseAuthExceptionFromIdentityToolkitMessage('INVALID_PASSWORD');
      expect(error.code, 'invalid-credential');
    });
  });

  group('authExceptionFromFirebase', () {
    test('maps invalid-credential to friendly message', () {
      final error = authExceptionFromFirebase(
        FirebaseAuthException(code: 'invalid-credential', message: 'bad'),
      );
      expect(error.code, 'invalid-credential');
      expect(error.message, 'E-mail ou senha incorretos.');
    });

    test('maps user-not-found to create-account prompt', () {
      final error = authExceptionFromFirebase(
        FirebaseAuthException(code: 'user-not-found', message: 'missing'),
      );
      expect(error.code, 'user-not-found');
      expect(error.message, contains('Deseja criar seu cadastro'));
    });
  });
}
