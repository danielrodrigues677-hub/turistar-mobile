import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turistar_mobile/main.dart';

void main() {
  tearDown(() {
    TuristarAuth.passwordResetHandler = null;
  });

  group('validatePasswordResetEmailField', () {
    test('rejects empty email', () {
      expect(validatePasswordResetEmailField(null), 'Campo obrigatorio');
      expect(validatePasswordResetEmailField('   '), 'Campo obrigatorio');
    });

    test('rejects invalid email', () {
      expect(validatePasswordResetEmailField('email-sem-arroba'), 'Informe um e-mail valido');
    });

    test('accepts valid email', () {
      expect(validatePasswordResetEmailField('cliente@turistar.com.br'), isNull);
    });
  });

  group('passwordResetErrorMessage', () {
    test('maps user-not-found', () {
      expect(
        passwordResetErrorMessage(FirebaseAuthException(code: 'user-not-found', message: 'missing')),
        'Nenhuma conta encontrada para este e-mail.',
      );
    });

    test('maps invalid-email', () {
      expect(
        passwordResetErrorMessage(FirebaseAuthException(code: 'invalid-email', message: 'bad')),
        'E-mail invalido.',
      );
    });

    test('maps network-request-failed', () {
      expect(
        passwordResetErrorMessage(FirebaseAuthException(code: 'network-request-failed', message: 'offline')),
        'Falha de conexao.',
      );
    });
  });

  group('firebaseAuthExceptionFromIdentityToolkitMessage', () {
    test('maps EMAIL_NOT_FOUND', () {
      final error = firebaseAuthExceptionFromIdentityToolkitMessage('EMAIL_NOT_FOUND');
      expect(error.code, 'user-not-found');
    });

    test('maps INVALID_EMAIL', () {
      final error = firebaseAuthExceptionFromIdentityToolkitMessage('INVALID_EMAIL');
      expect(error.code, 'invalid-email');
    });
  });

  group('TuristarAuth.sendPasswordResetEmail', () {
    test('sends reset email for existing account', () async {
      var calledWith = '';
      TuristarAuth.passwordResetHandler = (email) async {
        calledWith = email;
      };

      await TuristarAuth.sendPasswordResetEmail(' Cliente@Turistar.com.br ');

      expect(calledWith, 'cliente@turistar.com.br');
    });

    test('throws user-not-found for missing account', () async {
      TuristarAuth.passwordResetHandler = (email) async {
        throw FirebaseAuthException(code: 'user-not-found', message: 'User not found');
      };

      expect(
        () => TuristarAuth.sendPasswordResetEmail('inexistente@turistar.com.br'),
        throwsA(
          predicate<FirebaseAuthException>((error) => error.code == 'user-not-found'),
        ),
      );
    });

    test('returns success without error for valid send', () async {
      TuristarAuth.passwordResetHandler = (email) async {
        expect(email, 'ok@turistar.com.br');
      };

      await expectLater(
        TuristarAuth.sendPasswordResetEmail('ok@turistar.com.br'),
        completes,
      );
    });
  });
}
