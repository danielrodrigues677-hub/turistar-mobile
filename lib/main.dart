import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:http/http.dart' as http;
import 'package:turistar_mobile/firebase_options.dart';
import 'package:turistar_mobile/featured_packages_store.dart';
import 'package:turistar_mobile/firestore_schema.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_storage_web.dart' if (dart.library.io) 'app_storage_native.dart' as app_storage;
import 'admin_panel.dart';
import 'customer_area.dart';
import 'package_page.dart';
import 'package_store.dart';
import 'travel_request_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.ensureInitialized();
  unawaited(TuristarAuth.initialize());
  runApp(const TuristarApp());
}

class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static final Completer<void> _ready = Completer<void>();
  static Object? initError;
  static bool _started = false;
  static bool _channelBroken = false;

  static bool get isReady => _ready.isCompleted && initError == null;

  static bool get canUseFirebase => isReady && !_channelBroken;

  static void markChannelBroken(Object error) {
    if (!isFirebaseChannelError(error)) return;
    _channelBroken = true;
    AuthDiagnostics.step('BOOTSTRAP', 'Firebase channel marcado como indisponivel para esta sessao');
  }

  static Future<void> ensureInitialized() {
    if (_ready.isCompleted) {
      return _ready.future;
    }
    if (!_started) {
      _started = true;
      unawaited(_initialize());
    }
    return _ready.future;
  }

  static Future<void> _initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        AuthDiagnostics.step(
          'BOOTSTRAP',
          'inicializando Firebase projectId=${DefaultFirebaseOptions.currentPlatform.projectId}',
        );
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform).timeout(
          const Duration(seconds: 45),
          onTimeout: () => throw TimeoutException('Firebase initialization timed out'),
        );
      }
      initError = null;
      AuthDiagnostics.step('BOOTSTRAP', 'Firebase inicializado com sucesso');
    } catch (error, stackTrace) {
      initError = error;
      markChannelBroken(error);
      AuthDiagnostics.step('BOOTSTRAP', 'Firebase falhou na inicializacao', error: error, stack: stackTrace);
    } finally {
      if (!_ready.isCompleted) {
        _ready.complete();
      }
    }
  }
}

class AuthDiagnostics {
  const AuthDiagnostics._();

  static void logPlatformException(String phase, PlatformException error, {StackTrace? stack}) {
    debugPrint('[TuristarAuth][$phase] PlatformException');
    debugPrint('  code: ${error.code}');
    debugPrint('  message: ${error.message ?? '(null)'}');
    debugPrint('  details: ${error.details ?? '(null)'}');
    debugPrint('  stacktrace: ${error.stacktrace ?? '(null)'}');
    if (stack != null) {
      debugPrint('[TuristarAuth][$phase] dartStackTrace:');
      debugPrint(stack.toString());
    }
  }

  static void logFirebaseAuthException(String phase, FirebaseAuthException error, {StackTrace? stack}) {
    debugPrint('[TuristarAuth][$phase] FirebaseAuthException');
    debugPrint('  code: ${error.code}');
    debugPrint('  message: ${error.message ?? '(null)'}');
    debugPrint('  email: ${error.email ?? '(null)'}');
    debugPrint('  credential: ${error.credential ?? '(null)'}');
    debugPrint('  plugin: ${error.plugin}');
    debugPrint('  nativeStackTrace: ${error.stackTrace ?? '(null)'}');
    if (stack != null) {
      debugPrint('[TuristarAuth][$phase] dartStackTrace:');
      debugPrint(stack.toString());
    }
  }

  static void step(String phase, String message, {Object? error, StackTrace? stack}) {
    debugPrint('[TuristarAuth][$phase] $message');
    if (error is FirebaseAuthException) {
      logFirebaseAuthException(phase, error, stack: stack);
      return;
    }
    if (error is PlatformException) {
      logPlatformException(phase, error, stack: stack);
      return;
    }
    if (error is FirebaseException) {
      debugPrint('[TuristarAuth][$phase] FirebaseException code=${error.code} message=${error.message}');
    } else if (error is AuthException) {
      debugPrint('[TuristarAuth][$phase] AuthException code=${error.code} message=${error.message}');
    } else if (error != null) {
      debugPrint('[TuristarAuth][$phase] ERRO: $error');
    }
    if (stack != null) {
      debugPrint(stack.toString());
    }
  }

  static void config({
    required String projectId,
    required bool firebaseReady,
    String? authDomain,
    Object? initError,
  }) {
    debugPrint(
      '[TuristarAuth][CONFIG] projectId=$projectId authDomain=$authDomain '
      'firebaseReady=$firebaseReady initError=$initError',
    );
  }
}

String firebaseAuthErrorLabel(FirebaseAuthException error) {
  final message = error.message?.trim();
  if (message != null && message.isNotEmpty) {
    return '${error.code}: $message';
  }
  return error.code;
}

String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    return firebaseAuthErrorLabel(error);
  }
  if (error is PlatformException) {
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) {
      return '${error.code}: $message';
    }
    return error.code;
  }
  if (error is AuthException) {
    return '${error.code}: ${error.message}';
  }
  if (error is FirebaseException) {
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) {
      return '${error.code}: $message';
    }
    return error.code;
  }
  if (error is StateError) {
    return error.message;
  }
  return error.toString();
}

String passwordResetErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'user-not-found':
        return 'Nenhuma conta encontrada para este e-mail.';
      case 'invalid-email':
        return 'E-mail invalido.';
      case 'network-request-failed':
        return 'Falha de conexao.';
      default:
        return firebaseAuthErrorLabel(error);
    }
  }
  if (error is AuthException) {
    return error.message;
  }
  return authErrorMessage(error);
}

String? validatePasswordResetEmailField(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Campo obrigatorio';
  }
  if (!value.contains('@')) {
    return 'Informe um e-mail valido';
  }
  return null;
}

FirebaseAuthException firebaseAuthExceptionFromIdentityToolkitMessage(String message) {
  if (message.contains('EMAIL_NOT_FOUND')) {
    return FirebaseAuthException(code: 'user-not-found', message: message);
  }
  if (message.contains('INVALID_EMAIL')) {
    return FirebaseAuthException(code: 'invalid-email', message: message);
  }
  if (message.contains('INVALID_LOGIN_CREDENTIALS') || message.contains('INVALID_PASSWORD')) {
    return FirebaseAuthException(code: 'invalid-credential', message: message);
  }
  if (message.contains('USER_DISABLED')) {
    return FirebaseAuthException(code: 'user-disabled', message: message);
  }
  if (message.contains('OPERATION_NOT_ALLOWED')) {
    return FirebaseAuthException(code: 'operation-not-allowed', message: message);
  }
  return FirebaseAuthException(code: 'unknown', message: message);
}

class IdentityToolkitSignInResult {
  const IdentityToolkitSignInResult({
    required this.localId,
    required this.email,
    this.displayName,
    this.idToken,
  });

  final String localId;
  final String email;
  final String? displayName;
  final String? idToken;
}

Future<IdentityToolkitSignInResult> signInWithPasswordViaRestApi(String email, String password) async {
  final apiKey = DefaultFirebaseOptions.web.apiKey;
  final uri = Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey');
  AuthDiagnostics.step('LOGIN', 'REST signInWithPassword email=$email');
  debugPrint('[TuristarAuth][LOGIN] REST signInWithPassword email=$email');

  try {
    final response = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'password': password,
            'returnSecureToken': true,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw FirebaseAuthException(code: 'unknown', message: response.body);
      }
      debugPrint('[TuristarAuth][LOGIN] REST concluido com sucesso status=${response.statusCode}');
      return IdentityToolkitSignInResult(
        localId: decoded['localId']?.toString() ?? '',
        email: decoded['email']?.toString() ?? email,
        displayName: decoded['displayName']?.toString(),
        idToken: decoded['idToken']?.toString(),
      );
    }

    final decoded = jsonDecode(response.body);
    final errorMessage = decoded is Map && decoded['error'] is Map
        ? decoded['error']['message']?.toString() ?? response.body
        : response.body;
    debugPrint(
      '[TuristarAuth][LOGIN] REST falhou status=${response.statusCode} message=$errorMessage',
    );
    throw firebaseAuthExceptionFromIdentityToolkitMessage(errorMessage);
  } on FirebaseAuthException {
    rethrow;
  } on TimeoutException catch (error, stackTrace) {
    AuthDiagnostics.step('LOGIN', 'REST timeout', error: error, stack: stackTrace);
    throw FirebaseAuthException(code: 'network-request-failed', message: error.toString());
  } catch (error, stackTrace) {
    AuthDiagnostics.step('LOGIN', 'REST falhou', error: error, stack: stackTrace);
    if (error.toString().contains('SocketException') || error.toString().contains('Failed host lookup')) {
      throw FirebaseAuthException(code: 'network-request-failed', message: error.toString());
    }
    rethrow;
  }
}

Future<IdentityToolkitSignInResult> signUpViaRestApi(
  String email,
  String password, {
  String? displayName,
}) async {
  final apiKey = DefaultFirebaseOptions.web.apiKey;
  final uri = Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey');
  AuthDiagnostics.step('REGISTER', 'REST signUp email=$email');
  debugPrint('[TuristarAuth][REGISTER] REST signUp email=$email');

  try {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
      'returnSecureToken': true,
    };
    if (displayName != null && displayName.trim().isNotEmpty) {
      body['displayName'] = displayName.trim();
    }

    final response = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw FirebaseAuthException(code: 'unknown', message: response.body);
      }
      debugPrint('[TuristarAuth][REGISTER] REST concluido com sucesso status=${response.statusCode}');
      return IdentityToolkitSignInResult(
        localId: decoded['localId']?.toString() ?? '',
        email: decoded['email']?.toString() ?? email,
        displayName: decoded['displayName']?.toString() ?? displayName,
        idToken: decoded['idToken']?.toString(),
      );
    }

    final decoded = jsonDecode(response.body);
    final errorMessage = decoded is Map && decoded['error'] is Map
        ? decoded['error']['message']?.toString() ?? response.body
        : response.body;
    debugPrint(
      '[TuristarAuth][REGISTER] REST falhou status=${response.statusCode} message=$errorMessage',
    );
    if (errorMessage.contains('EMAIL_EXISTS')) {
      throw FirebaseAuthException(code: 'email-already-in-use', message: errorMessage);
    }
    throw firebaseAuthExceptionFromIdentityToolkitMessage(errorMessage);
  } on FirebaseAuthException {
    rethrow;
  } on TimeoutException catch (error, stackTrace) {
    AuthDiagnostics.step('REGISTER', 'REST timeout', error: error, stack: stackTrace);
    throw FirebaseAuthException(code: 'network-request-failed', message: error.toString());
  } catch (error, stackTrace) {
    AuthDiagnostics.step('REGISTER', 'REST falhou', error: error, stack: stackTrace);
    if (error.toString().contains('SocketException') || error.toString().contains('Failed host lookup')) {
      throw FirebaseAuthException(code: 'network-request-failed', message: error.toString());
    }
    rethrow;
  }
}

AuthException authExceptionFromFirebase(FirebaseAuthException error) {
  switch (error.code) {
    case 'user-not-found':
      return const AuthException(
        'user-not-found',
        'Conta nao encontrada. Deseja criar seu cadastro?',
      );
    case 'invalid-credential':
    case 'wrong-password':
      return const AuthException('invalid-credential', 'E-mail ou senha incorretos.');
    default:
      return AuthException(error.code, firebaseAuthErrorLabel(error));
  }
}

bool isFirebaseCredentialRejection(FirebaseAuthException error) {
  return error.code == 'user-not-found' ||
      error.code == 'invalid-credential' ||
      error.code == 'wrong-password' ||
      error.code == 'user-disabled';
}

Future<void> sendPasswordResetEmailViaRestApi(String email) async {
  final apiKey = DefaultFirebaseOptions.web.apiKey;
  final uri = Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=$apiKey');
  AuthDiagnostics.step('PASSWORD_RESET', 'REST sendOobCode email=$email');
  debugPrint('[TuristarAuth][PASSWORD_RESET] REST sendOobCode email=$email');

  try {
    final response = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'requestType': 'PASSWORD_RESET',
            'email': email,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      debugPrint('[TuristarAuth][PASSWORD_RESET] REST concluido com sucesso status=${response.statusCode}');
      return;
    }

    final decoded = jsonDecode(response.body);
    final errorMessage = decoded is Map && decoded['error'] is Map
        ? decoded['error']['message']?.toString() ?? response.body
        : response.body;
    debugPrint(
      '[TuristarAuth][PASSWORD_RESET] REST falhou status=${response.statusCode} message=$errorMessage',
    );
    throw firebaseAuthExceptionFromIdentityToolkitMessage(errorMessage);
  } on FirebaseAuthException {
    rethrow;
  } on TimeoutException catch (error, stackTrace) {
    AuthDiagnostics.step('PASSWORD_RESET', 'REST timeout', error: error, stack: stackTrace);
    throw FirebaseAuthException(code: 'network-request-failed', message: error.toString());
  } catch (error, stackTrace) {
    AuthDiagnostics.step('PASSWORD_RESET', 'REST falhou', error: error, stack: stackTrace);
    if (error.toString().contains('SocketException') || error.toString().contains('Failed host lookup')) {
      throw FirebaseAuthException(code: 'network-request-failed', message: error.toString());
    }
    rethrow;
  }
}

bool isFirebaseChannelError(Object error) {
  if (error is PlatformException) {
    return error.code == 'channel-error';
  }
  return error.toString().contains('channel-error');
}

bool shouldSwallowFirebaseInfraError(Object error) {
  if (isFirebaseChannelError(error)) return true;
  if (error is StateError && error.message.contains('Firebase nao inicializado')) return true;
  final text = error.toString();
  return text.contains('FirebaseCoreHostApi.initializeCore');
}

bool isFirebaseAuthUnavailable(Object error) {
  if (isFirebaseChannelError(error)) return true;
  final text = error.toString();
  if (text.contains('CONFIGURATION_NOT_FOUND')) return true;
  if (error is FirebaseAuthException) {
    return error.code == 'operation-not-allowed';
  }
  return false;
}

bool shouldFallbackFromFirebaseAuth(FirebaseAuthException error) {
  if (isFirebaseAuthUnavailable(error)) return true;
  return error.code == 'weak-password';
}

class AuthException implements Exception {
  const AuthException(this.code, this.message);

  final String code;
  final String message;
}

class TuristarSession {
  const TuristarSession({
    required this.email,
    required this.name,
    this.phone,
    this.uid,
    this.role = TuristarRole.customer,
  });

  final String email;
  final String name;
  final String? phone;
  final String? uid;
  final String role;

  Map<String, dynamic> toJson() => {
        'email': email,
        'name': name,
        if (phone != null) 'phone': phone,
        if (uid != null) 'uid': uid,
        'role': role,
      };

  factory TuristarSession.fromJson(Map<String, dynamic> json) {
    final role = json['role']?.toString();
    return TuristarSession(
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      uid: json['uid']?.toString(),
      role: TuristarRole.isValid(role) ? role! : TuristarRole.customer,
    );
  }

  TuristarSession copyWith({
    String? email,
    String? name,
    String? phone,
    String? uid,
    String? role,
  }) {
    return TuristarSession(
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      uid: uid ?? this.uid,
      role: role ?? this.role,
    );
  }
}

class TuristarAccount {
  const TuristarAccount({
    required this.email,
    required this.name,
    required this.phone,
    required this.passwordHash,
  });

  final String email;
  final String name;
  final String phone;
  final String passwordHash;

  Map<String, dynamic> toJson() => {
        'email': email,
        'name': name,
        'phone': phone,
        'passwordHash': passwordHash,
      };

  factory TuristarAccount.fromJson(Map<String, dynamic> json) {
    return TuristarAccount(
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      passwordHash: json['passwordHash']?.toString() ?? '',
    );
  }
}

class LocalAuthStore {
  const LocalAuthStore._();

  static const _accountsKey = 'turistar_accounts_v1';
  static const sessionEmailKey = 'turistar_session_email';
  static const rememberedEmailKey = 'turistar_remembered_email';
  static const authIdTokenKey = 'turistar_auth_id_token';
  static const _sessionKey = sessionEmailKey;
  static const _rememberedEmailKey = rememberedEmailKey;
  static const _authIdTokenKey = authIdTokenKey;

  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password.trim())).toString();
  }

  static Future<String?> _readString(String key) async {
    try {
      return await app_storage.appStorageGetString(key);
    } catch (error, stackTrace) {
      AuthDiagnostics.step('STORAGE', 'leitura falhou key=$key', error: error, stack: stackTrace);
      if (kIsWeb) {
        throw const AuthException(
          'storage-unavailable',
          'Nao foi possivel ler dados no navegador. No Safari, use uma aba normal (nao privada).',
        );
      }
      rethrow;
    }
  }

  static Future<void> _writeString(String key, String value) async {
    try {
      await app_storage.appStorageSetString(key, value);
    } catch (error, stackTrace) {
      AuthDiagnostics.step('STORAGE', 'escrita falhou key=$key', error: error, stack: stackTrace);
      if (kIsWeb) {
        throw const AuthException(
          'storage-unavailable',
          'Nao foi possivel salvar no navegador. No Safari, use uma aba normal (nao privada).',
        );
      }
      rethrow;
    }
  }

  static Future<void> _deleteString(String key) async {
    try {
      await app_storage.appStorageRemove(key);
    } catch (error, stackTrace) {
      AuthDiagnostics.step('STORAGE', 'remocao falhou key=$key', error: error, stack: stackTrace);
      if (kIsWeb) {
        throw const AuthException(
          'storage-unavailable',
          'Nao foi possivel atualizar dados no navegador. No Safari, use uma aba normal (nao privada).',
        );
      }
      rethrow;
    }
  }

  static Future<List<TuristarAccount>> _loadAccounts() async {
    try {
      final raw = await _readString(_accountsKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map>().map((item) => TuristarAccount.fromJson(Map<String, dynamic>.from(item))).toList();
    } catch (error, stackTrace) {
      if (error is AuthException) rethrow;
      debugPrint('Local accounts load failed: $error\n$stackTrace');
      return [];
    }
  }

  static Future<void> _saveAccounts(List<TuristarAccount> accounts) async {
    await _writeString(_accountsKey, jsonEncode(accounts.map((account) => account.toJson()).toList()));
  }

  static Future<void> saveSessionProfile({
    required TuristarSession session,
    required bool rememberMe,
  }) async {
    await _writeString(_sessionKey, jsonEncode(session.toJson()));
    if (rememberMe) {
      await saveRememberedEmail(session.email);
    }
  }

  static Future<void> clearSession() async {
    await _deleteString(_sessionKey);
    await clearAuthIdToken();
  }

  static Future<void> saveAuthIdToken(String token) async {
    if (token.isEmpty) return;
    await _writeString(_authIdTokenKey, token);
  }

  static Future<String?> authIdToken() async => _readString(_authIdTokenKey);

  static Future<void> clearAuthIdToken() async {
    await _deleteString(_authIdTokenKey);
  }

  static Future<void> saveRememberedEmail(String email) async {
    await _writeString(_rememberedEmailKey, email.trim().toLowerCase());
  }

  static Future<String?> rememberedEmail() async {
    return _readString(_rememberedEmailKey);
  }

  static Future<TuristarSession> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required bool rememberMe,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (password.trim().length < 3) {
      throw const AuthException('weak-password', 'Senha muito curta. Use pelo menos 3 caracteres.');
    }

    final accounts = await _loadAccounts();
    if (accounts.any((account) => account.email.toLowerCase() == normalizedEmail)) {
      throw const AuthException('email-already-in-use', 'Este e-mail ja possui cadastro. Use a opcao Entrar.');
    }

    final account = TuristarAccount(
      email: normalizedEmail,
      name: name.trim(),
      phone: phone.trim(),
      passwordHash: hashPassword(password),
    );
    accounts.add(account);
    await _saveAccounts(accounts);
    AuthDiagnostics.step('LOCAL', 'cadastro salvo localmente email=$normalizedEmail contas=${accounts.length}');
    final session = TuristarSession(email: account.email, name: account.name, phone: account.phone);
    await saveSessionProfile(session: session, rememberMe: rememberMe);

    return session;
  }

  static Future<TuristarSession> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final passwordHash = hashPassword(password);
    final accounts = await _loadAccounts();
    TuristarAccount? account;
    for (final item in accounts) {
      if (item.email.toLowerCase() == normalizedEmail) {
        account = item;
        break;
      }
    }

    if (account == null) {
      AuthDiagnostics.step('LOCAL', 'login: email nao encontrado localmente email=$normalizedEmail');
      throw const AuthException('user-not-found', 'Conta nao encontrada.');
    }
    if (account.passwordHash != passwordHash) {
      AuthDiagnostics.step('LOCAL', 'login: senha invalida localmente email=$normalizedEmail');
      throw const AuthException('invalid-credential', 'E-mail ou senha incorretos.');
    }

    AuthDiagnostics.step('LOCAL', 'login OK email=$normalizedEmail');

    final session = TuristarSession(email: account.email, name: account.name, phone: account.phone);
    await saveSessionProfile(session: session, rememberMe: rememberMe);

    return session;
  }

  static Future<TuristarSession?> loadSessionProfile() async {
    final raw = await _readString(_sessionKey);
    if (raw == null || raw.isEmpty) return null;

    if (raw.startsWith('{')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final session = TuristarSession.fromJson(Map<String, dynamic>.from(decoded));
          if (session.email.isNotEmpty) return session;
        }
      } catch (error, stackTrace) {
        AuthDiagnostics.step('STORAGE', 'session JSON invalido', error: error, stack: stackTrace);
      }
    }

    return loadSession();
  }

  static Future<TuristarSession?> loadSession() async {
    final email = await _readString(_sessionKey);
    if (email == null || email.isEmpty) return null;
    if (email.startsWith('{')) return loadSessionProfile();

    final accounts = await _loadAccounts();
    for (final account in accounts) {
      if (account.email.toLowerCase() == email.toLowerCase()) {
        return TuristarSession(email: account.email, name: account.name, phone: account.phone);
      }
    }

    return TuristarSession(email: email.trim().toLowerCase(), name: 'Conta');
  }

  static Future<void> clearRememberedEmail() async {
    await _deleteString(_rememberedEmailKey);
  }

  static Future<void> saveSessionOnly({
    required TuristarSession session,
    required bool rememberMe,
  }) async {
    await saveSessionProfile(session: session, rememberMe: rememberMe);
  }

  static Future<void> mirrorAccount({
    required TuristarSession session,
    required String password,
  }) async {
    final accounts = await _loadAccounts();
    final passwordHash = hashPassword(password);
    final index = accounts.indexWhere(
      (account) => account.email.toLowerCase() == session.email.toLowerCase(),
    );

    if (index >= 0) {
      final existing = accounts[index];
      accounts[index] = TuristarAccount(
        email: session.email,
        name: session.name.isNotEmpty ? session.name : existing.name,
        phone: session.phone ?? existing.phone,
        passwordHash: password.isEmpty ? existing.passwordHash : passwordHash,
      );
    } else {
      accounts.add(
        TuristarAccount(
          email: session.email,
          name: session.name,
          phone: session.phone ?? '',
          passwordHash: passwordHash,
        ),
      );
    }
    await _saveAccounts(accounts);
  }
}

class FirestoreAuthStore {
  const FirestoreAuthStore._();

  static FirebaseFirestore? _firestoreOverride;

  @visibleForTesting
  static set firestoreOverride(FirebaseFirestore? firestore) {
    _firestoreOverride = firestore;
  }

  static FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  static bool get _canAccessFirestore => _firestoreOverride != null || FirebaseBootstrap.canUseFirebase;

  static String normalizeEmail(String email) => email.trim().toLowerCase();

  static String docIdForEmail(String email) {
    return normalizeEmail(email).replaceAll('@', '_at_').replaceAll('.', '_dot_');
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>?> findUserSnapshot(String email) async {
    final emailId = normalizeEmail(email);
    final candidateIds = <String>{
      docIdForEmail(email),
      emailId,
    };

    for (final docId in candidateIds) {
      final snapshot = await _db.collection(FirestoreCollections.users).doc(docId).get();
      if (snapshot.exists) {
        debugPrint('FirestoreAuthStore: usuario encontrado em users/$docId');
        return snapshot;
      }
    }

    final query = await _db.collection(FirestoreCollections.users).where('email', isEqualTo: emailId).limit(1).get();
    if (query.docs.isNotEmpty) {
      debugPrint('FirestoreAuthStore: usuario encontrado por consulta de email');
      return query.docs.first;
    }

    debugPrint('FirestoreAuthStore: nenhum usuario para $emailId');
    return null;
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>?> findUserSnapshotByUid(String uid) async {
    if (uid.isEmpty) return null;
    final snapshot = await _db.collection(FirestoreCollections.users).doc(uid).get();
    if (snapshot.exists) {
      debugPrint('FirestoreAuthStore: usuario encontrado em users/$uid');
      return snapshot;
    }
    return null;
  }

  static TuristarSession sessionFromMap(Map<String, dynamic> data, {String? fallbackEmail}) {
    final role = data['role']?.toString();
    return TuristarSession(
      uid: data['uid']?.toString(),
      email: data['email']?.toString() ?? fallbackEmail ?? '',
      name: data['name']?.toString() ?? '',
      phone: data['phone']?.toString(),
      role: TuristarRole.isValid(role) ? role! : TuristarRole.customer,
    );
  }

  static int _rolePriority(String role) {
    switch (role) {
      case TuristarRole.admin:
        return 3;
      case TuristarRole.agent:
        return 2;
      default:
        return 1;
    }
  }

  static TuristarSession? _pickBestProfile(TuristarSession? current, TuristarSession? candidate) {
    if (candidate == null) return current;
    if (current == null) return candidate;
    if (_rolePriority(candidate.role) > _rolePriority(current.role)) return candidate;
    if (_rolePriority(candidate.role) < _rolePriority(current.role)) return current;
    if (candidate.uid != null && candidate.uid!.isNotEmpty && (current.uid == null || current.uid!.isEmpty)) {
      return candidate;
    }
    return current;
  }

  static Map<String, dynamic> _fieldsFromRest(Map<String, dynamic> fields) {
    final data = <String, dynamic>{};
    fields.forEach((key, value) {
      if (value is! Map) return;
      if (value.containsKey('stringValue')) {
        data[key] = value['stringValue'];
      } else if (value.containsKey('integerValue')) {
        data[key] = int.tryParse(value['integerValue'].toString()) ?? value['integerValue'];
      }
    });
    return data;
  }

  static Future<Map<String, dynamic>?> _fetchUserDocumentViaRest(String docId) async {
    if (docId.isEmpty) return null;
    final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/${FirestoreCollections.users}/$docId',
    );
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['fields'] is! Map) return null;
      return _fieldsFromRest(Map<String, dynamic>.from(decoded['fields'] as Map));
    } catch (error, stackTrace) {
      AuthDiagnostics.step('FIRESTORE', 'REST profile falhou doc=$docId', error: error, stack: stackTrace);
      return null;
    }
  }

  static Future<TuristarSession?> fetchProfileViaRest(String email, {String? uid}) async {
    final emailId = normalizeEmail(email);
    final candidates = <String>{
      if (uid != null && uid.isNotEmpty) uid,
      docIdForEmail(email),
      emailId,
    };

    TuristarSession? best;
    for (final docId in candidates) {
      final data = await _fetchUserDocumentViaRest(docId);
      if (data == null) continue;
      best = _pickBestProfile(best, sessionFromMap(data, fallbackEmail: emailId));
    }
    return best;
  }

  static Future<TuristarSession?> _fetchProfileViaSdk(String email, {String? uid}) async {
    TuristarSession? best;

    if (uid != null && uid.isNotEmpty) {
      final uidSnapshot = await findUserSnapshotByUid(uid);
      if (uidSnapshot != null) {
        best = sessionFromMap(uidSnapshot.data() ?? {}, fallbackEmail: email);
      }
    }

    final emailId = normalizeEmail(email);
    final snapshot = await findUserSnapshot(email);
    if (snapshot != null) {
      best = _pickBestProfile(best, sessionFromMap(snapshot.data() ?? {}, fallbackEmail: emailId));
    }

    return best;
  }

  static Future<void> _ensureReady() async {
    if (_firestoreOverride != null) return;
    await FirebaseBootstrap.ensureInitialized();
    if (!FirebaseBootstrap.canUseFirebase) {
      throw StateError('Firebase nao inicializado');
    }
  }

  static Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    if (!_canAccessFirestore) {
      AuthDiagnostics.step('FIRESTORE', 'register ignorado: Firebase indisponivel');
      return;
    }

    await _ensureReady();

    if (password.trim().length < 3) {
      throw const AuthException('weak-password', 'Senha muito curta. Use pelo menos 3 caracteres.');
    }

    final emailId = normalizeEmail(email);
    AuthDiagnostics.step('FIRESTORE', 'register inicio email=$emailId');
    final existing = await findUserSnapshot(email);
    if (existing != null) {
      AuthDiagnostics.step('FIRESTORE', 'register bloqueado: email ja existe email=$emailId');
      throw const AuthException('email-already-in-use', 'Este e-mail ja possui cadastro. Use a opcao Entrar.');
    }

    final docId = docIdForEmail(email);
    final ref = _db.collection(FirestoreCollections.users).doc(docId);
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await ref.set({
        'email': emailId,
        'name': name.trim(),
        'phone': phone.trim(),
        'passwordHash': LocalAuthStore.hashPassword(password),
        'role': TuristarRole.customer,
        'createdAt': now,
        'updatedAt': now,
      });
      AuthDiagnostics.step('FIRESTORE', 'register OK doc=users/$docId');
    } catch (error, stackTrace) {
      AuthDiagnostics.step('FIRESTORE', 'register falhou doc=users/$docId', error: error, stack: stackTrace);
      FirebaseBootstrap.markChannelBroken(error);
      if (shouldSwallowFirebaseInfraError(error)) return;
      rethrow;
    }
  }

  static Future<TuristarSession> login({
    required String email,
    required String password,
  }) async {
    if (!_canAccessFirestore) {
      AuthDiagnostics.step('FIRESTORE', 'login ignorado: Firebase indisponivel');
      throw const AuthException('user-not-found', 'Conta nao encontrada.');
    }

    await _ensureReady();

    final emailId = normalizeEmail(email);
    final snapshot = await findUserSnapshot(email);
    if (snapshot == null) {
      AuthDiagnostics.step('FIRESTORE', 'login: usuario nao encontrado email=$emailId');
      throw const AuthException('user-not-found', 'Conta nao encontrada.');
    }

    final data = snapshot.data() ?? {};
    final storedHash = data['passwordHash']?.toString();
    final providedHash = LocalAuthStore.hashPassword(password);
    if (storedHash != providedHash) {
      AuthDiagnostics.step('FIRESTORE', 'login: senha invalida email=$emailId');
      throw const AuthException('invalid-credential', 'E-mail ou senha incorretos.');
    }

    AuthDiagnostics.step('FIRESTORE', 'login OK email=$emailId');

    return sessionFromMap(data, fallbackEmail: emailId);
  }

  static Future<TuristarSession?> fetchProfile(String email, {String? uid}) async {
    TuristarSession? profile;

    if (_canAccessFirestore) {
      try {
        await _ensureReady();
        profile = await _fetchProfileViaSdk(email, uid: uid);
      } catch (error, stackTrace) {
        AuthDiagnostics.step('FIRESTORE', 'fetchProfile SDK falhou', error: error, stack: stackTrace);
        FirebaseBootstrap.markChannelBroken(error);
      }
    }

    try {
      final restProfile = await fetchProfileViaRest(email, uid: uid);
      profile = _pickBestProfile(profile, restProfile);
    } catch (error, stackTrace) {
      AuthDiagnostics.step('FIRESTORE', 'fetchProfile REST falhou', error: error, stack: stackTrace);
    }

    return profile;
  }

  static Future<void> saveUserProfile({
    required String uid,
    required String email,
    required String name,
    required String phone,
    String role = TuristarRole.customer,
  }) async {
    if (!_canAccessFirestore || uid.isEmpty) {
      AuthDiagnostics.step('FIRESTORE', 'saveUserProfile ignorado: Firebase indisponivel ou uid vazio');
      return;
    }

    await _ensureReady();

    final emailId = normalizeEmail(email);
    final ref = _db.collection(FirestoreCollections.users).doc(uid);
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      final snapshot = await ref.get();
      if (snapshot.exists) {
        await ref.set({
          'uid': uid,
          'email': emailId,
          'name': name.trim(),
          'phone': phone.trim(),
          'role': snapshot.data()?['role']?.toString() ?? role,
          'createdAt': snapshot.data()?['createdAt'] ?? now,
          'updatedAt': now,
        }, SetOptions(merge: true));
      } else {
        await ref.set({
          'uid': uid,
          'email': emailId,
          'name': name.trim(),
          'phone': phone.trim(),
          'role': TuristarRole.isValid(role) ? role : TuristarRole.customer,
          'createdAt': now,
          'updatedAt': now,
        });
      }
      AuthDiagnostics.step('FIRESTORE', 'saveUserProfile OK doc=users/$uid role=$role');
    } catch (error, stackTrace) {
      AuthDiagnostics.step('FIRESTORE', 'saveUserProfile falhou doc=users/$uid', error: error, stack: stackTrace);
      FirebaseBootstrap.markChannelBroken(error);
      if (shouldSwallowFirebaseInfraError(error)) return;
      rethrow;
    }
  }

  static Future<void> upsertProfile({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? uid,
  }) async {
    if (uid != null && uid.isNotEmpty) {
      await saveUserProfile(uid: uid, email: email, name: name, phone: phone);
      return;
    }

    try {
      await register(name: name, email: email, phone: phone, password: password);
    } on AuthException catch (error) {
      if (error.code == 'email-already-in-use') {
        AuthDiagnostics.step('FIRESTORE', 'upsert ignorado: doc ja existe email=${normalizeEmail(email)}');
        return;
      }
      rethrow;
    }
  }
}

class TuristarAuth {
  const TuristarAuth._();

  static TuristarSession? _session;
  static final StreamController<TuristarSession?> _sessionController = StreamController<TuristarSession?>.broadcast();

  static TuristarSession? get session => _session;

  static bool get isLoggedIn => _session != null;

  static bool hasRole(String role) => _session != null && _session!.role == role;

  static bool hasAnyRole(Iterable<String> roles) => _session != null && roles.contains(_session!.role);

  static bool get isCustomer => hasRole(TuristarRole.customer);

  static bool get isAgent => hasRole(TuristarRole.agent);

  static bool get isOperacional => hasRole(TuristarRole.operacional);

  static bool get isAdmin => hasRole(TuristarRole.admin);

  static String? get currentRole => _session?.role;

  static Stream<TuristarSession?> sessionChanges() => _sessionController.stream;

  static Future<void> initialize() async {
    _session = await _restoreSession();
    _emit();
    await refreshSessionFromRemote();
    unawaited(_auditFirebaseAuth());
    if (kIsWeb) {
      unawaited(_listenFirebaseAuth());
    }
  }

  static Future<void> refreshSessionFromRemote() async {
    final current = _session;
    if (current == null || current.email.isEmpty) return;

    try {
      final remote = await FirestoreAuthStore.fetchProfile(current.email, uid: current.uid);
      if (remote == null) return;

      final updated = current.copyWith(
        uid: remote.uid ?? current.uid,
        name: remote.name.isNotEmpty ? remote.name : current.name,
        phone: remote.phone ?? current.phone,
        role: remote.role,
      );

      if (updated.role == current.role &&
          updated.name == current.name &&
          updated.phone == current.phone &&
          updated.uid == current.uid) {
        return;
      }

      _session = updated;
      await LocalAuthStore.saveSessionProfile(session: updated, rememberMe: true);
      _emit();
      AuthDiagnostics.step('SESSION', 'perfil remoto sincronizado role=${updated.role}');
    } catch (error, stackTrace) {
      AuthDiagnostics.step('SESSION', 'refresh remoto falhou', error: error, stack: stackTrace);
    }
  }

  static Future<void> _auditFirebaseAuth() async {
    if (!kIsWeb) {
      AuthDiagnostics.step('AUDIT', 'pulado: ambiente nao-web');
      return;
    }

    try {
      await FirebaseBootstrap.ensureInitialized();
      AuthDiagnostics.config(
        projectId: DefaultFirebaseOptions.currentPlatform.projectId,
        firebaseReady: FirebaseBootstrap.isReady,
        authDomain: DefaultFirebaseOptions.currentPlatform.authDomain,
        initError: FirebaseBootstrap.initError,
      );
      if (!FirebaseBootstrap.isReady) {
        AuthDiagnostics.step(
          'AUDIT',
          'Firebase Auth indisponivel: bootstrap falhou. Cadastro/login usara armazenamento local.',
        );
        return;
      }
      if (!FirebaseBootstrap.canUseFirebase) {
        AuthDiagnostics.step('AUDIT', 'Firebase Auth indisponivel: channel-error detectado.');
        return;
      }

      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail('auth-audit@turistar.local');
      AuthDiagnostics.step('AUDIT', 'Firebase Auth ativo. signInMethods=$methods');
    } catch (error, stackTrace) {
      FirebaseBootstrap.markChannelBroken(error);
      AuthDiagnostics.step(
        'AUDIT',
        'Firebase Auth nao configurado ou Email/Password desabilitado',
        error: error,
        stack: stackTrace,
      );
    }
  }

  static Future<TuristarSession?> _restoreSession() async {
    try {
      final profile = await LocalAuthStore.loadSessionProfile();
      if (profile != null && profile.email.isNotEmpty) {
        try {
          final remote = await FirestoreAuthStore.fetchProfile(profile.email, uid: profile.uid);
          if (remote != null) {
            return profile.copyWith(
              uid: remote.uid ?? profile.uid,
              name: remote.name.isNotEmpty ? remote.name : profile.name,
              phone: remote.phone ?? profile.phone,
              role: remote.role,
            );
          }
        } catch (error, stackTrace) {
          debugPrint('Firestore session restore fallback: $error\n$stackTrace');
        }
        return profile;
      }
    } catch (error, stackTrace) {
      debugPrint('Local session restore failed: $error\n$stackTrace');
    }

    return null;
  }

  static Future<void> _listenFirebaseAuth() async {
    try {
      await FirebaseBootstrap.ensureInitialized();
      if (!FirebaseBootstrap.isReady) return;

      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) {
          _session = (_session ?? TuristarSession(email: user.email ?? '', name: 'Conta')).copyWith(
            email: user.email ?? _session?.email ?? '',
            uid: user.uid,
            name: user.displayName?.trim().isNotEmpty == true ? user.displayName!.trim() : (_session?.name ?? 'Conta'),
            phone: _session?.phone,
            role: _session?.role ?? TuristarRole.customer,
          );
          _emit();
          return;
        }

        if (_session != null) {
          unawaited(LocalAuthStore.clearSession());
          _session = null;
          _emit();
        }
      });
    } catch (error, stackTrace) {
      debugPrint('Firebase auth listener skipped: $error\n$stackTrace');
    }
  }

  static Future<TuristarSession> registerLocal({
    required String name,
    required String email,
    required String phone,
    required String password,
    required bool rememberMe,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    AuthDiagnostics.step('REGISTER', 'inicio email=$normalizedEmail');

    if (kIsWeb) {
      try {
        AuthDiagnostics.step('REGISTER', 'etapa 1/3 REST signUp');
        final signUp = await signUpViaRestApi(
          normalizedEmail,
          password,
          displayName: name.trim(),
        );
        final session = TuristarSession(
          uid: signUp.localId,
          email: normalizedEmail,
          name: name.trim(),
          phone: phone.trim(),
          role: TuristarRole.customer,
        );
        await _persistRegistration(
          session: session,
          password: password,
          rememberMe: rememberMe,
          name: name,
          phone: phone,
        );
        if (signUp.idToken != null && signUp.idToken!.isNotEmpty) {
          await LocalAuthStore.saveAuthIdToken(signUp.idToken!);
        }
        _session = session;
        _emit();
        AuthDiagnostics.step('REGISTER', 'concluido via REST (web) email=$normalizedEmail');
        return session;
      } on FirebaseAuthException catch (error, stackTrace) {
        AuthDiagnostics.step('REGISTER', 'REST signUp falhou', error: error, stack: stackTrace);
        if (error.code == 'email-already-in-use') {
          AuthDiagnostics.step('REGISTER', 'email ja existe no Firebase Auth, tentando login');
          return loginLocal(email: email, password: password, rememberMe: rememberMe);
        }
        if (!shouldFallbackFromFirebaseAuth(error) && error.code != 'weak-password') {
          throw authExceptionFromFirebase(error);
        }
        AuthDiagnostics.step('REGISTER', 'fallback para Firebase SDK / armazenamento local');
      }
    }

    await FirebaseBootstrap.ensureInitialized();
    if (kIsWeb && FirebaseBootstrap.canUseFirebase) {
      try {
        AuthDiagnostics.step('REGISTER', 'etapa 1/3 createUserWithEmailAndPassword');
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
        if (name.trim().isNotEmpty) {
          await credential.user?.updateDisplayName(name.trim());
        }
        AuthDiagnostics.step('REGISTER', 'Firebase Auth OK uid=${credential.user?.uid}');

        final session = TuristarSession(
          uid: credential.user?.uid,
          email: normalizedEmail,
          name: name.trim(),
          phone: phone.trim(),
          role: TuristarRole.customer,
        );
        await _persistRegistration(
          session: session,
          password: password,
          rememberMe: rememberMe,
          name: name,
          phone: phone,
        );
        _session = session;
        _emit();
        AuthDiagnostics.step('REGISTER', 'concluido via Firebase Auth email=$normalizedEmail');
        return session;
      } on FirebaseAuthException catch (error, stackTrace) {
        FirebaseBootstrap.markChannelBroken(error);
        AuthDiagnostics.step('REGISTER', 'createUserWithEmailAndPassword falhou', error: error, stack: stackTrace);
        if (error.code == 'email-already-in-use') {
          AuthDiagnostics.step('REGISTER', 'email ja existe no Firebase Auth, tentando login');
          return loginLocal(email: email, password: password, rememberMe: rememberMe);
        }
        if (!shouldFallbackFromFirebaseAuth(error)) {
          rethrow;
        }
        AuthDiagnostics.step('REGISTER', 'fallback para armazenamento local');
      } on PlatformException catch (error, stackTrace) {
        FirebaseBootstrap.markChannelBroken(error);
        AuthDiagnostics.step('REGISTER', 'createUserWithEmailAndPassword falhou (platform)', error: error, stack: stackTrace);
        if (!isFirebaseChannelError(error)) {
          rethrow;
        }
        AuthDiagnostics.step('REGISTER', 'fallback para armazenamento local (channel-error)');
      } catch (error, stackTrace) {
        FirebaseBootstrap.markChannelBroken(error);
        AuthDiagnostics.step('REGISTER', 'createUserWithEmailAndPassword falhou (inesperado)', error: error, stack: stackTrace);
        if (!shouldSwallowFirebaseInfraError(error)) {
          rethrow;
        }
        AuthDiagnostics.step('REGISTER', 'fallback para armazenamento local (infra)');
      }
    } else {
      AuthDiagnostics.step('REGISTER', 'Firebase indisponivel, usando armazenamento local');
    }

    return _registerWithLocalStore(
      name: name,
      email: email,
      phone: phone,
      password: password,
      rememberMe: rememberMe,
      normalizedEmail: normalizedEmail,
    );
  }

  static Future<TuristarSession> _registerWithLocalStore({
    required String name,
    required String email,
    required String phone,
    required String password,
    required bool rememberMe,
    required String normalizedEmail,
  }) async {
    AuthDiagnostics.step('REGISTER', 'etapa 2/3 LocalAuthStore.register');
    TuristarSession session;
    try {
      session = await LocalAuthStore.register(
        name: name,
        email: email,
        phone: phone,
        password: password,
        rememberMe: rememberMe,
      );
    } on AuthException catch (error) {
      if (error.code == 'email-already-in-use') {
        AuthDiagnostics.step('REGISTER', 'email ja existe localmente, tentando login');
        return loginLocal(email: email, password: password, rememberMe: rememberMe);
      }
      rethrow;
    }

    _session = session;
    _emit();
    if (FirebaseBootstrap.canUseFirebase) {
      AuthDiagnostics.step('REGISTER', 'etapa 3/3 FirestoreAuthStore.register');
      await _syncRegisterToFirestore(
        name: name,
        email: email,
        phone: phone,
        password: password,
      );
    } else {
      AuthDiagnostics.step('REGISTER', 'etapa 3/3 Firestore ignorado (Firebase indisponivel)');
    }
    AuthDiagnostics.step('REGISTER', 'concluido via armazenamento local email=$normalizedEmail');
    return session;
  }

  static Future<TuristarSession> _completeSuccessfulLogin({
    required String normalizedEmail,
    required String password,
    required bool rememberMe,
    required String displayName,
    required String viaLabel,
    String? uid,
    String? phone,
    String? idToken,
  }) async {
    var session = TuristarSession(
      uid: uid,
      email: normalizedEmail,
      name: displayName.trim().isNotEmpty ? displayName.trim() : 'Conta',
      phone: phone,
      role: TuristarRole.customer,
    );
    try {
      final profile = await FirestoreAuthStore.fetchProfile(session.email, uid: uid);
      if (profile != null) {
        session = session.copyWith(
          uid: profile.uid ?? session.uid,
          name: profile.name.isNotEmpty ? profile.name : session.name,
          phone: profile.phone ?? session.phone,
          role: profile.role,
        );
        AuthDiagnostics.step('LOGIN', 'perfil carregado do Firestore');
      }
    } catch (error, stackTrace) {
      AuthDiagnostics.step('LOGIN', 'perfil Firestore indisponivel', error: error, stack: stackTrace);
    }

    if (session.uid != null && session.uid!.isNotEmpty) {
      try {
        await FirestoreAuthStore.saveUserProfile(
          uid: session.uid!,
          email: session.email,
          name: session.name,
          phone: session.phone ?? '',
          role: session.role,
        );
      } catch (error, stackTrace) {
        AuthDiagnostics.step('LOGIN', 'saveUserProfile falhou', error: error, stack: stackTrace);
      }
    }

    if (idToken != null && idToken.isNotEmpty) {
      await LocalAuthStore.saveAuthIdToken(idToken);
    }

    await LocalAuthStore.saveSessionProfile(session: session, rememberMe: rememberMe);
    await LocalAuthStore.mirrorAccount(session: session, password: password);
    _session = session;
    _emit();
    AuthDiagnostics.step('LOGIN', 'concluido via $viaLabel email=$normalizedEmail');
    return session;
  }

  static Future<TuristarSession> loginLocal({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    AuthDiagnostics.step('LOGIN', 'inicio email=$normalizedEmail');

    if (kIsWeb) {
      try {
        AuthDiagnostics.step('LOGIN', 'etapa 1/3 REST signInWithPassword');
        final signIn = await signInWithPasswordViaRestApi(normalizedEmail, password);
        AuthDiagnostics.step('LOGIN', 'REST OK uid=${signIn.localId}');
        return _completeSuccessfulLogin(
          normalizedEmail: normalizedEmail,
          password: password,
          rememberMe: rememberMe,
          displayName: signIn.displayName ?? '',
          uid: signIn.localId,
          idToken: signIn.idToken,
          viaLabel: 'REST (web)',
        );
      } on FirebaseAuthException catch (error, stackTrace) {
        AuthDiagnostics.step('LOGIN', 'REST signInWithPassword falhou', error: error, stack: stackTrace);
        if (isFirebaseCredentialRejection(error)) {
          throw authExceptionFromFirebase(error);
        }
        if (error.code != 'network-request-failed') {
          throw authExceptionFromFirebase(error);
        }
        AuthDiagnostics.step('LOGIN', 'REST offline, tentando armazenamento local');
      }
    }

    await FirebaseBootstrap.ensureInitialized();
    if (kIsWeb && FirebaseBootstrap.canUseFirebase) {
      try {
        AuthDiagnostics.step('LOGIN', 'etapa 1/3 signInWithEmailAndPassword');
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
        final user = credential.user;
        AuthDiagnostics.step('LOGIN', 'Firebase Auth OK uid=${user?.uid}');

        return _completeSuccessfulLogin(
          normalizedEmail: normalizedEmail,
          password: password,
          rememberMe: rememberMe,
          displayName: user?.displayName ?? '',
          uid: user?.uid,
          viaLabel: 'Firebase Auth',
        );
      } on FirebaseAuthException catch (error, stackTrace) {
        FirebaseBootstrap.markChannelBroken(error);
        AuthDiagnostics.step('LOGIN', 'signInWithEmailAndPassword falhou', error: error, stack: stackTrace);
        if (!shouldFallbackFromFirebaseAuth(error) &&
            error.code != 'user-not-found' &&
            error.code != 'wrong-password' &&
            error.code != 'invalid-credential') {
          rethrow;
        }
        AuthDiagnostics.step('LOGIN', 'fallback para armazenamento local');
      } on PlatformException catch (error, stackTrace) {
        FirebaseBootstrap.markChannelBroken(error);
        AuthDiagnostics.step('LOGIN', 'signInWithEmailAndPassword falhou (platform)', error: error, stack: stackTrace);
        if (!isFirebaseChannelError(error)) {
          rethrow;
        }
        AuthDiagnostics.step('LOGIN', 'fallback para armazenamento local (channel-error)');
      } catch (error, stackTrace) {
        FirebaseBootstrap.markChannelBroken(error);
        AuthDiagnostics.step('LOGIN', 'signInWithEmailAndPassword falhou (inesperado)', error: error, stack: stackTrace);
        if (!shouldSwallowFirebaseInfraError(error)) {
          rethrow;
        }
        AuthDiagnostics.step('LOGIN', 'fallback para armazenamento local (infra)');
      }
    } else {
      AuthDiagnostics.step('LOGIN', 'Firebase indisponivel, usando armazenamento local');
    }

    AuthDiagnostics.step('LOGIN', 'etapa 2/3 LocalAuthStore.login');
    AuthException? localError;
    try {
      final session = await LocalAuthStore.login(
        email: email,
        password: password,
        rememberMe: rememberMe,
      );
      _session = session;
      _emit();
      AuthDiagnostics.step('LOGIN', 'concluido via armazenamento local email=$normalizedEmail');
      return session;
    } on AuthException catch (error) {
      if (error.code != 'user-not-found' && error.code != 'invalid-credential') rethrow;
      localError = error;
      AuthDiagnostics.step('LOGIN', 'local falhou (${error.code}), tentando Firestore');
    }

    try {
      if (!FirebaseBootstrap.canUseFirebase) {
        AuthDiagnostics.step('LOGIN', 'etapa 3/3 Firestore ignorado (Firebase indisponivel)');
        throw const AuthException('user-not-found', 'Conta nao encontrada.');
      }

      AuthDiagnostics.step('LOGIN', 'etapa 3/3 FirestoreAuthStore.login');
      final session = await FirestoreAuthStore.login(email: email, password: password);
      await LocalAuthStore.saveSessionProfile(session: session, rememberMe: rememberMe);
      await LocalAuthStore.mirrorAccount(session: session, password: password);
      _session = session;
      _emit();
      AuthDiagnostics.step('LOGIN', 'concluido via Firestore email=$normalizedEmail');
      return session;
    } on AuthException catch (firestoreError) {
      if (firestoreError.code != 'user-not-found' && firestoreError.code != 'invalid-credential') {
        rethrow;
      }
      if (localError?.code == 'user-not-found' && firestoreError.code == 'user-not-found') {
        AuthDiagnostics.step('LOGIN', 'falha final: conta inexistente em todas as fontes');
        throw const AuthException(
          'user-not-found',
          'Conta nao encontrada. Deseja criar seu cadastro?',
        );
      }
      AuthDiagnostics.step('LOGIN', 'falha final: senha invalida');
      throw const AuthException('invalid-credential', 'E-mail ou senha incorretos.');
    } catch (error, stackTrace) {
      FirebaseBootstrap.markChannelBroken(error);
      AuthDiagnostics.step('LOGIN', 'falha inesperada no Firestore', error: error, stack: stackTrace);
      if (shouldSwallowFirebaseInfraError(error)) {
        if (localError?.code == 'user-not-found') {
          throw const AuthException(
            'user-not-found',
            'Conta nao encontrada. Deseja criar seu cadastro?',
          );
        }
        throw const AuthException('invalid-credential', 'E-mail ou senha incorretos.');
      }
      rethrow;
    }
  }

  static Future<void> _persistRegistration({
    required TuristarSession session,
    required String password,
    required bool rememberMe,
    required String name,
    required String phone,
  }) async {
    try {
      await LocalAuthStore.mirrorAccount(session: session, password: password);
      await LocalAuthStore.saveSessionProfile(session: session, rememberMe: rememberMe);
      AuthDiagnostics.step('PERSIST', 'espelhamento local OK email=${session.email}');
    } catch (error, stackTrace) {
      AuthDiagnostics.step('PERSIST', 'espelhamento local falhou', error: error, stack: stackTrace);
    }

    if (!FirebaseBootstrap.canUseFirebase && (session.uid == null || session.uid!.isEmpty)) {
      AuthDiagnostics.step('PERSIST', 'documento Firestore ignorado (Firebase indisponivel)');
      return;
    }

    try {
      if (session.uid != null && session.uid!.isNotEmpty) {
        await FirestoreAuthStore.saveUserProfile(
          uid: session.uid!,
          email: session.email,
          name: name,
          phone: phone,
          role: session.role,
        );
      } else {
        await FirestoreAuthStore.upsertProfile(
          name: name,
          email: session.email,
          phone: phone,
          password: password,
          uid: session.uid,
        );
      }
      AuthDiagnostics.step('PERSIST', 'documento Firestore OK email=${session.email}');
    } catch (error, stackTrace) {
      FirebaseBootstrap.markChannelBroken(error);
      AuthDiagnostics.step('PERSIST', 'documento Firestore falhou', error: error, stack: stackTrace);
    }
  }

  static Future<void> _syncRegisterToFirestore({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      await FirestoreAuthStore.register(
        name: name,
        email: email,
        phone: phone,
        password: password,
      );
    } on AuthException catch (error) {
      if (error.code == 'email-already-in-use') {
        AuthDiagnostics.step('FIRESTORE', 'sync register: doc ja existia email=${email.trim().toLowerCase()}');
        return;
      }
      AuthDiagnostics.step('FIRESTORE', 'sync register falhou', error: error);
    } catch (error, stackTrace) {
      AuthDiagnostics.step('FIRESTORE', 'sync register falhou', error: error, stack: stackTrace);
    }
  }

  static Future<void> signOut({bool clearRememberedEmail = false}) async {
    await LocalAuthStore.clearSession();
    if (clearRememberedEmail) {
      await LocalAuthStore.clearRememberedEmail();
    }
    _session = null;
    _emit();
    if (FirebaseBootstrap.isReady) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (error, stackTrace) {
        AuthDiagnostics.step('LOGOUT', 'Firebase signOut falhou', error: error, stack: stackTrace);
      }
    }
  }

  static Future<void> updateProfile({
    required String name,
    required String phone,
  }) async {
    final current = _session;
    if (current == null) {
      throw const AuthException('auth-required', 'Faca login para editar seu perfil.');
    }

    final updated = current.copyWith(name: name.trim(), phone: phone.trim());
    if (current.uid != null && current.uid!.isNotEmpty) {
      await FirestoreAuthStore.saveUserProfile(
        uid: current.uid!,
        email: current.email,
        name: updated.name,
        phone: updated.phone ?? '',
        role: updated.role,
      );
    }

    await LocalAuthStore.saveSessionProfile(session: updated, rememberMe: true);
    await LocalAuthStore.mirrorAccount(session: updated, password: '');
    _session = updated;
    _emit();
  }

  @visibleForTesting
  static Future<void> Function(String email)? passwordResetHandler;

  static Future<void> sendPasswordResetEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    AuthDiagnostics.step('PASSWORD_RESET', 'inicio email=$normalizedEmail');
    debugPrint('[TuristarAuth][PASSWORD_RESET] sendPasswordResetEmail iniciado email=$normalizedEmail');

    if (passwordResetHandler != null) {
      await passwordResetHandler!(normalizedEmail);
      debugPrint('[TuristarAuth][PASSWORD_RESET] sendPasswordResetEmail concluido (mock)');
      return;
    }

    if (kIsWeb) {
      await sendPasswordResetEmailViaRestApi(normalizedEmail);
      debugPrint('[TuristarAuth][PASSWORD_RESET] sendPasswordResetEmail concluido via REST (web)');
      return;
    }

    await FirebaseBootstrap.ensureInitialized();
    if (!FirebaseBootstrap.canUseFirebase) {
      debugPrint('[TuristarAuth][PASSWORD_RESET] Firebase indisponivel');
      throw const AuthException(
        'firebase-unavailable',
        'Recuperacao de senha indisponivel no momento. Recarregue a pagina e tente novamente.',
      );
    }

    try {
      debugPrint('[TuristarAuth][PASSWORD_RESET] chamando FirebaseAuth.sendPasswordResetEmail');
      await FirebaseAuth.instance.sendPasswordResetEmail(email: normalizedEmail);
      debugPrint('[TuristarAuth][PASSWORD_RESET] sendPasswordResetEmail concluido com sucesso');
    } on FirebaseAuthException catch (error, stackTrace) {
      FirebaseBootstrap.markChannelBroken(error);
      AuthDiagnostics.step('PASSWORD_RESET', 'sendPasswordResetEmail falhou', error: error, stack: stackTrace);
      debugPrint('[TuristarAuth][PASSWORD_RESET] FirebaseAuthException code=${error.code} message=${error.message}');
      rethrow;
    } on PlatformException catch (error, stackTrace) {
      FirebaseBootstrap.markChannelBroken(error);
      AuthDiagnostics.step('PASSWORD_RESET', 'sendPasswordResetEmail falhou (platform)', error: error, stack: stackTrace);
      debugPrint('[TuristarAuth][PASSWORD_RESET] PlatformException code=${error.code} message=${error.message}');
      rethrow;
    }
  }

  static String greeting(TuristarSession? session) {
    if (session == null) return 'Entrar';
    final name = session.name.trim();
    if (name.isNotEmpty) {
      final first = name.split(' ').first;
      return first.length > 14 ? 'Conta' : first;
    }
    final email = session.email.split('@').first;
    return email.isEmpty ? 'Conta' : email;
  }

  static void _emit() {
    if (!_sessionController.isClosed) {
      _sessionController.add(_session);
    }
  }

  @visibleForTesting
  static void replaceSessionForTesting(TuristarSession? session) {
    _session = session;
    _emit();
  }
}

Future<void> requireAuth(
  BuildContext context,
  VoidCallback onAuthenticated, {
  List<String>? roles,
}) async {
  if (!TuristarAuth.isLoggedIn) {
    final loggedIn = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LoginPage(requireSuccess: true)),
    );

    if (!context.mounted) return;
    if (loggedIn != true && !TuristarAuth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Faca login ou crie seu cadastro para continuar.'),
          backgroundColor: TuristarColors.navy,
        ),
      );
      return;
    }
  }

  if (roles != null && roles.isNotEmpty && !TuristarAuth.hasAnyRole(roles)) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voce nao tem permissao para acessar esta area.'),
        backgroundColor: TuristarColors.navy,
      ),
    );
    return;
  }

  onAuthenticated();
}

class TuristarApp extends StatelessWidget {
  const TuristarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Turistar Viagens Premium',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: TuristarColors.page,
        colorScheme: ColorScheme.fromSeed(
          seedColor: TuristarColors.navy,
          primary: TuristarColors.navy,
          secondary: TuristarColors.orange,
        ),
        fontFamily: 'Arial',
      ),
      onGenerateInitialRoutes: (initialRoute) => [generateTuristarRoute(RouteSettings(name: initialRoute))!],
      onGenerateRoute: generateTuristarRoute,
    );
  }
}

class TuristarColors {
  static const navy = Color(0xFF002B66);
  static const navyDark = Color(0xFF001D46);
  static const navyDeep = Color(0xFF00142F);
  static const orange = Color(0xFFF6A313);
  static const orangeDark = Color(0xFFD48600);
  static const page = Color(0xFFF8FAFE);
  static const text = Color(0xFF092A5E);
  static const muted = Color(0xFF62728B);
  static const line = Color(0xFFE2E8F3);
  static const green = Color(0xFF1DBE72);
}

enum TravelService { flights, hotels, cars, packages }

extension TravelServiceInfo on TravelService {
  String get label {
    switch (this) {
      case TravelService.flights:
        return 'Passagens Aereas';
      case TravelService.hotels:
        return 'Hospedagem';
      case TravelService.cars:
        return 'Aluguel de Carros';
      case TravelService.packages:
        return 'Pacotes';
    }
  }

  String get shortLabel {
    switch (this) {
      case TravelService.flights:
        return 'Voos';
      case TravelService.hotels:
        return 'Hoteis';
      case TravelService.cars:
        return 'Carros';
      case TravelService.packages:
        return 'Pacotes';
    }
  }

  String get actionLabel {
    switch (this) {
      case TravelService.flights:
        return 'Buscar Voos';
      case TravelService.hotels:
        return 'Buscar Hoteis';
      case TravelService.cars:
        return 'Alugar Carro';
      case TravelService.packages:
        return 'Buscar Pacotes';
    }
  }

  IconData get icon {
    switch (this) {
      case TravelService.flights:
        return Icons.flight_takeoff;
      case TravelService.hotels:
        return Icons.apartment;
      case TravelService.cars:
        return Icons.directions_car;
      case TravelService.packages:
        return Icons.luggage;
    }
  }
}

class SearchRequest {
  const SearchRequest({
    required this.service,
    required this.origin,
    required this.destination,
    required this.departureDate,
    required this.returnDate,
    required this.travelers,
  });

  final TravelService service;
  final String origin;
  final String destination;
  final String departureDate;
  final String returnDate;
  final String travelers;
}

class SearchResultItem {
  const SearchResultItem({
    this.id,
    required this.title,
    required this.subtitle,
    required this.details,
    required this.price,
    required this.badge,
    required this.icon,
    this.fromApi = false,
  });

  final String? id;
  final String title;
  final String subtitle;
  final String details;
  final String price;
  final String badge;
  final IconData icon;
  final bool fromApi;
}

/// Fase 1 - vender sem integracoes: cada acao de busca/interesse abre o
/// WhatsApp comercial com uma mensagem de cotacao pronta, que a equipe
/// responde manualmente com os fornecedores.
class Whatsapp {
  const Whatsapp._();

  /// Numero comercial da Turistar no formato internacional, somente digitos
  /// (55 + DDD + numero). Sobrescreva no build com:
  /// flutter run -d chrome --dart-define=TURISTAR_WHATSAPP_NUMBER=5511978916580
  static const String number = String.fromEnvironment(
    'TURISTAR_WHATSAPP_NUMBER',
    defaultValue: '5511978916580',
  );

  static Future<void> open(BuildContext context, String message) async {
    await openToNumber(context, number, message);
  }

  static Future<void> openToNumber(BuildContext context, String phone, String message) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Telefone do cliente nao informado.')),
      );
      return;
    }
    final uri = Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(message)}');
    var launched = false;
    try {
      // Safari (macOS/iOS) bloqueia pop-ups se o link nao abrir no clique direto.
      launched = await launchUrl(
        uri,
        mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } catch (_) {
      launched = false;
    }
    if (!launched) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(kIsWeb
              ? 'Permita pop-ups para agenciaturistar.com.br no Safari e tente novamente.'
              : 'Nao foi possivel abrir o WhatsApp. Tente novamente.'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  static String quoteForRequest(SearchRequest request) {
    final start = _formatDate(request.departureDate);
    final end = _formatDate(request.returnDate);
    switch (request.service) {
      case TravelService.flights:
        return [
          'Ola, gostaria de uma cotacao de passagem.',
          'Origem: ${request.origin}',
          'Destino: ${request.destination}',
          'Ida: $start',
          if (end.isNotEmpty) 'Volta: $end',
          'Passageiros: ${request.travelers}',
        ].join('\n');
      case TravelService.hotels:
        return [
          'Ola, gostaria de uma cotacao de hospedagem.',
          'Destino: ${request.destination}',
          'Check-in: $start',
          if (end.isNotEmpty) 'Check-out: $end',
          'Hospedes: ${request.travelers}',
        ].join('\n');
      case TravelService.cars:
        return [
          'Ola, gostaria de uma cotacao de aluguel de carro.',
          'Retirada: ${request.origin}',
          'Devolucao: ${request.destination}',
          'Retirada em: $start',
          if (end.isNotEmpty) 'Devolucao em: $end',
          'Veiculo: ${request.travelers}',
        ].join('\n');
      case TravelService.packages:
        return [
          'Ola, gostaria de uma cotacao de pacote de viagem.',
          'Origem: ${request.origin}',
          'Destino: ${request.destination}',
          'Ida: $start',
          if (end.isNotEmpty) 'Volta: $end',
          'Passageiros: ${request.travelers}',
        ].join('\n');
    }
  }

  static String quoteForService(TravelService service) {
    switch (service) {
      case TravelService.flights:
        return 'Ola, gostaria de uma cotacao de passagens aereas.';
      case TravelService.hotels:
        return 'Ola, gostaria de uma cotacao de hospedagem.';
      case TravelService.cars:
        return 'Ola, gostaria de uma cotacao de aluguel de carro.';
      case TravelService.packages:
        return 'Ola, gostaria de uma cotacao de pacote de viagem.';
    }
  }

  static String packageInterest(String packageName) => 'Tenho interesse no pacote $packageName.';

  static String _formatDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }
}

class TuristarLandingPage extends StatefulWidget {
  const TuristarLandingPage({super.key});

  @override
  State<TuristarLandingPage> createState() => _TuristarLandingPageState();
}

class _TuristarLandingPageState extends State<TuristarLandingPage> {
  TravelService selectedService = TravelService.flights;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            TopNavigation(onServiceSelected: _selectService),
            HeroSection(
              selectedService: selectedService,
              onServiceChanged: _selectService,
              onSearch: _openResults,
            ),
            ServicesSection(onServiceSelected: _openResultsForService),
            const PopularPackagesSection(),
            const WhyChooseSection(),
            CallToActionSection(onSearch: () => _openResultsForService(selectedService)),
            const FooterSection(),
          ],
        ),
      ),
    );
  }

  void _selectService(TravelService service) {
    setState(() => selectedService = service);
  }

  void _openResults(SearchRequest request) {
    Whatsapp.open(context, Whatsapp.quoteForRequest(request));
  }

  void _openResultsForService(TravelService service) {
    _selectService(service);
    Whatsapp.open(context, Whatsapp.quoteForService(service));
  }
}

class LocationResolver {
  const LocationResolver._();

  static const Map<String, String> _aliases = {
    'SAO PAULO': 'GRU',
    'SP': 'GRU',
    'GRU': 'GRU',
    'GUARULHOS': 'GRU',
    'CONGONHAS': 'CGH',
    'CGH': 'CGH',
    'VIRACOPOS': 'VCP',
    'CAMPINAS': 'VCP',
    'VCP': 'VCP',
    'RIO': 'GIG',
    'RIO DE JANEIRO': 'GIG',
    'GIG': 'GIG',
    'GALEAO': 'GIG',
    'SANTOS DUMONT': 'SDU',
    'SDU': 'SDU',
    'BRASILIA': 'BSB',
    'BSB': 'BSB',
    'SALVADOR': 'SSA',
    'SSA': 'SSA',
    'RECIFE': 'REC',
    'REC': 'REC',
    'MIAMI': 'MIA',
    'MIA': 'MIA',
    'ORLANDO': 'MCO',
    'MCO': 'MCO',
    'LISBOA': 'LIS',
    'LISBON': 'LIS',
    'LIS': 'LIS',
    'PARIS': 'CDG',
    'CDG': 'CDG',
    'BUENOS AIRES': 'EZE',
    'EZE': 'EZE',
  };

  static String codeFor(String value, {String fallback = 'GRU'}) {
    final normalized = _normalize(value);
    if (normalized.isEmpty) return fallback;
    if (_aliases.containsKey(normalized)) return _aliases[normalized]!;
    final exactCode = RegExp(r'^[A-Z]{3}$').firstMatch(normalized);
    if (exactCode != null) return exactCode.group(0)!;
    final embeddedCode = RegExp(r'\b[A-Z]{3}\b').firstMatch(normalized);
    if (embeddedCode != null) return embeddedCode.group(0)!;
    return normalized.substring(0, normalized.length.clamp(0, 3).toInt()).padRight(3, 'X');
  }

  static String labelFor(String value) {
    final normalized = _normalize(value);
    if (normalized.isEmpty) return 'Origem';
    if (_aliases.containsKey(normalized)) return '${_titleCase(value)} (${_aliases[normalized]})';
    return value.trim();
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toUpperCase()
        .replaceAll('\u00C1', 'A')
        .replaceAll('\u00C0', 'A')
        .replaceAll('\u00C2', 'A')
        .replaceAll('\u00C3', 'A')
        .replaceAll('\u00C9', 'E')
        .replaceAll('\u00CA', 'E')
        .replaceAll('\u00CD', 'I')
        .replaceAll('\u00D3', 'O')
        .replaceAll('\u00D4', 'O')
        .replaceAll('\u00D5', 'O')
        .replaceAll('\u00DA', 'U')
        .replaceAll('\u00C7', 'C');
  }

  static String _titleCase(String value) {
    return value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part.length == 1 ? part.toUpperCase() : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }
}

class Responsive {
  static bool isMobile(BuildContext context) => MediaQuery.sizeOf(context).width < 720;
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= 720 && width < 1040;
  }

  static double maxWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 720) return width;
    if (width < 1040) return 920;
    return 1180;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    return EdgeInsets.symmetric(horizontal: isMobile(context) ? 16 : 24);
  }
}

class LayoutShell extends StatelessWidget {
  const LayoutShell({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: Responsive.maxWidth(context)),
        child: Padding(
          padding: padding ?? Responsive.pagePadding(context),
          child: child,
        ),
      ),
    );
  }
}

class TopNavigation extends StatelessWidget {
  const TopNavigation({super.key, required this.onServiceSelected});

  final ValueChanged<TravelService> onServiceSelected;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TuristarSession?>(
      stream: TuristarAuth.sessionChanges(),
      initialData: TuristarAuth.session,
      builder: (context, snapshot) {
        final session = snapshot.data;
        return _buildNavigation(context, session);
      },
    );
  }

  Widget _buildNavigation(BuildContext context, TuristarSession? session) {
    // Below 1040px the page content is capped at 920px (see Responsive.maxWidth),
    // which is not wide enough for the full horizontal menu. Collapse to the
    // compact (menu button) layout at that breakpoint to avoid clipping the nav.
    final compact = MediaQuery.sizeOf(context).width < 1040;
    final accountLabel = TuristarAuth.greeting(session);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: TuristarColors.orange, width: 2)),
      ),
      child: LayoutShell(
        padding: Responsive.pagePadding(context),
        child: SizedBox(
          height: compact ? 70 : 78,
          child: Row(
            children: [
              const BrandLogo(),
              if (!compact) ...[
                const SizedBox(width: 54),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Center the links when there is room, but allow them to
                      // scroll horizontally instead of overflowing if space is tight.
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: constraints.maxWidth),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              NavLink(label: 'Passagens', onTap: () => onServiceSelected(TravelService.flights)),
                              NavLink(label: 'Hospedagens', onTap: () => onServiceSelected(TravelService.hotels)),
                              NavLink(label: 'Aluguel de Carros', onTap: () => onServiceSelected(TravelService.cars)),
                              NavLink(label: 'Pacotes', onTap: () => onServiceSelected(TravelService.packages)),
                              const NavLink(label: 'Servicos'),
                              const NavLink(label: 'Empresa'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                HeaderAction(
                  icon: Icons.confirmation_number_outlined,
                  label: 'Minhas Reservas',
                  onTap: () => openReservationsPage(context),
                ),
                const SizedBox(width: 22),
                const HeaderAction(icon: Icons.help_outline, label: 'Ajuda'),
                const SizedBox(width: 22),
                AccountMenuTrigger(
                  session: session,
                  accountLabel: accountLabel,
                ),
              ] else
                const Spacer(),
              const SizedBox(width: 18),
              AccountMenuTrigger(
                session: session,
                accountLabel: accountLabel,
                compact: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

}

List<PopupMenuEntry<String>> buildAccountMenuItems() {
  final email = TuristarAuth.session?.email ?? 'Conta Turistar';
  final isStaff = TuristarAuth.hasAnyRole(TuristarRole.staff);

  return [
    PopupMenuItem<String>(
      enabled: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(email, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900)),
          if (isStaff) ...[
            const SizedBox(height: 4),
            Text(
              TuristarAuth.isAdmin
                  ? 'Equipe: Administrador'
                  : TuristarAuth.isAgent
                      ? 'Equipe: Consultor'
                      : 'Equipe: Operacional',
              style: const TextStyle(color: TuristarColors.orange, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ],
        ],
      ),
    ),
    const PopupMenuDivider(),
    if (isStaff)
      _accountMenuItem('admin', Icons.dashboard_outlined, 'Painel administrativo'),
    _accountMenuItem('hub', Icons.dashboard_outlined, 'Area do cliente'),
    _accountMenuItem('profile', Icons.person_outline, 'Meu perfil'),
    _accountMenuItem('trips', Icons.flight_takeoff, 'Minhas Viagens'),
    _accountMenuItem('quotes', Icons.request_quote_outlined, 'Meus Orcamentos'),
    _accountMenuItem('request', Icons.add_circle_outline, 'Solicitar orcamento'),
    _accountMenuItem('reservations', Icons.confirmation_number_outlined, 'Minhas Reservas'),
    const PopupMenuDivider(),
    _accountMenuItem('logout', Icons.logout, 'Sair'),
  ];
}

PopupMenuItem<String> _accountMenuItem(String value, IconData icon, String label) {
  return PopupMenuItem<String>(
    value: value,
    child: Row(
      children: [
        Icon(icon, color: TuristarColors.navy, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w600))),
      ],
    ),
  );
}

Future<void> handleAccountMenuAction(BuildContext context, String action) async {
  switch (action) {
    case 'admin':
      openAdminPanel(context);
      return;
    case 'hub':
      openCustomerAreaHub(context);
      return;
    case 'profile':
      openCustomerProfilePage(context);
      return;
    case 'trips':
      openMyTripsPage(context);
      return;
    case 'quotes':
      openMyQuotesPage(context);
      return;
    case 'request':
      openNewTravelRequestPage(context);
      return;
    case 'reservations':
      openReservationsPage(context);
      return;
    case 'logout':
      await TuristarAuth.signOut();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sessao encerrada.'), backgroundColor: TuristarColors.navy),
        );
      }
      return;
  }
}

class AccountMenuTrigger extends StatefulWidget {
  const AccountMenuTrigger({
    super.key,
    required this.session,
    required this.accountLabel,
    this.compact = false,
  });

  final TuristarSession? session;
  final String accountLabel;
  final bool compact;

  @override
  State<AccountMenuTrigger> createState() => _AccountMenuTriggerState();
}

class _AccountMenuTriggerState extends State<AccountMenuTrigger> {
  final GlobalKey _anchorKey = GlobalKey();

  Future<void> _onTap() async {
    if (widget.session == null) {
      openLoginPage(context);
      return;
    }

    await TuristarAuth.refreshSessionFromRemote();
    if (!mounted) return;

    final renderBox = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final menuWidth = 280.0;
    final left = (position.dx + renderBox.size.width - menuWidth).clamp(8.0, overlay.size.width - menuWidth - 8.0);

    final selected = await showMenu<String>(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      elevation: 8,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(left, position.dy + renderBox.size.height + 8, menuWidth, 0),
        Offset.zero & overlay.size,
      ),
      items: buildAccountMenuItems(),
    );

    if (selected != null && mounted) {
      await handleAccountMenuAction(context, selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.session == null && !widget.compact) {
      return HeaderAction(
        icon: Icons.person_outline,
        label: 'Entrar',
        onTap: () => openLoginPage(context),
      );
    }

    if (widget.compact) {
      return InkWell(
        key: _anchorKey,
        onTap: _onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            border: Border.all(color: TuristarColors.line),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            widget.session == null ? Icons.menu : Icons.account_circle_outlined,
            size: 20,
            color: TuristarColors.navy,
          ),
        ),
      );
    }

    return InkWell(
      key: _anchorKey,
      onTap: _onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.session == null ? Icons.person_outline : Icons.account_circle_outlined,
              color: TuristarColors.navy,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              widget.accountLabel,
              style: const TextStyle(
                color: TuristarColors.navy,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, color: TuristarColors.navy, size: 20),
          ],
        ),
      ),
    );
  }
}

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    return TuristarLogo(
      onDark: onDark,
      markSize: mobile ? 38 : 44,
      titleSize: mobile ? 18 : 22,
      taglineSize: mobile ? 8 : 10,
    );
  }
}

class TuristarLogo extends StatelessWidget {
  const TuristarLogo({
    super.key,
    this.onDark = false,
    this.markSize = 44,
    this.titleSize = 22,
    this.taglineSize = 10,
  });

  final bool onDark;
  final double markSize;
  final double titleSize;
  final double taglineSize;

  @override
  Widget build(BuildContext context) {
    final blue = onDark ? Colors.white : TuristarColors.navy;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TuristarLogoMark(size: markSize),
        SizedBox(width: markSize * 0.18),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w900,
                  height: 0.92,
                  letterSpacing: -0.8,
                ),
                children: [
                  const TextSpan(text: 'TURISTAR', style: TextStyle(color: TuristarColors.orange)),
                  TextSpan(text: ' VIAGENS', style: TextStyle(color: blue)),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'SEUS SONHOS COMECAM AQUI',
              style: TextStyle(
                color: onDark ? Colors.white70 : TuristarColors.navy,
                fontSize: taglineSize,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.1,
                height: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class TuristarLogoMark extends StatelessWidget {
  const TuristarLogoMark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: Size.square(size), painter: TuristarGlobePainter()),
          Transform.rotate(
            angle: -0.45,
            child: Icon(
              Icons.flight,
              color: TuristarColors.orange,
              size: size * 0.68,
            ),
          ),
        ],
      ),
    );
  }
}

class TuristarGlobePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final orangePaint = Paint()
      ..color = TuristarColors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075
      ..strokeCap = StrokeCap.round;
    final bluePaint = Paint()
      ..color = TuristarColors.navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.40;
    final circleRect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(circleRect, 0.60, 4.95, false, orangePaint);
    canvas.drawArc(circleRect, -0.20, 0.55, false, bluePaint);
    canvas.drawLine(Offset(size.width * 0.16, size.height * 0.45), Offset(size.width * 0.70, size.height * 0.45), orangePaint);
    canvas.drawLine(Offset(size.width * 0.20, size.height * 0.65), Offset(size.width * 0.56, size.height * 0.65), orangePaint);
    canvas.drawArc(Rect.fromLTWH(size.width * 0.27, size.height * 0.10, size.width * 0.46, size.height * 0.80), -1.40, 2.65, false, orangePaint);
    canvas.drawArc(Rect.fromLTWH(size.width * 0.27, size.height * 0.10, size.width * 0.46, size.height * 0.80), 1.80, 1.95, false, orangePaint);
    canvas.drawLine(Offset(size.width * 0.49, size.height * 0.12), Offset(size.width * 0.49, size.height * 0.84), orangePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class NavLink extends StatelessWidget {
  const NavLink({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        child: Text(
          label,
          style: const TextStyle(
            color: TuristarColors.navy,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class HeaderAction extends StatelessWidget {
  const HeaderAction({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: TuristarColors.navy, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: TuristarColors.navy,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void openLoginPage(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const LoginPage()),
  );
}

void openReservationsPage(BuildContext context) {
  requireAuth(
    context,
    () => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MyReservationsPage()),
    ),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.requireSuccess = false});

  final bool requireSuccess;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  bool createAccount = false;
  bool rememberMe = true;
  bool obscurePassword = true;
  bool isLoading = false;
  bool isGoogleLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final email = await LocalAuthStore.rememberedEmail();
    if (!mounted || email == null || email.isEmpty) return;
    emailController.text = email;
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);

    return Scaffold(
      body: Container(
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).height,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              TuristarColors.navyDeep,
              TuristarColors.navy,
              Color(0xFFB87312),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutShell(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: mobile ? 18 : 42),
              child: mobile
                  ? Column(
                      children: [
                        const LoginBrandPanel(),
                        const SizedBox(height: 18),
                        _buildLoginCard(context),
                      ],
                    )
                  : Row(
                      children: [
                        const Expanded(child: LoginBrandPanel()),
                        const SizedBox(width: 42),
                        SizedBox(width: 440, child: _buildLoginCard(context)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Responsive.isMobile(context) ? 20 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 26,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: TuristarColors.navy),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: TuristarColors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Area do cliente',
                    style: TextStyle(color: TuristarColors.orangeDark, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              createAccount ? 'Criar sua conta' : 'Entrar na Turistar',
              style: const TextStyle(
                color: TuristarColors.navy,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              createAccount
                  ? 'Cadastre-se para acompanhar reservas, ofertas e suporte.'
                  : 'Acesse suas reservas, favoritos e ofertas exclusivas.',
              style: const TextStyle(color: TuristarColors.muted, height: 1.4),
            ),
            const SizedBox(height: 22),
            LoginModeSwitch(
              createAccount: createAccount,
              onChanged: (value) => setState(() => createAccount = value),
            ),
            const SizedBox(height: 22),
            if (createAccount) ...[
              LoginTextField(
                controller: nameController,
                label: 'Nome completo',
                icon: Icons.person_outline,
                validator: _required,
              ),
              const SizedBox(height: 14),
              LoginTextField(
                controller: phoneController,
                label: 'Telefone',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: _required,
              ),
              const SizedBox(height: 14),
            ],
            LoginTextField(
              controller: emailController,
              label: 'E-mail',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              validator: _emailValidator,
            ),
            const SizedBox(height: 14),
            LoginTextField(
              controller: passwordController,
              label: 'Senha',
              icon: Icons.lock_outline,
              obscureText: obscurePassword,
              validator: _required,
              suffix: IconButton(
                onPressed: () => setState(() => obscurePassword = !obscurePassword),
                icon: Icon(
                  obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: TuristarColors.muted,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: rememberMe,
                  activeColor: TuristarColors.orange,
                  onChanged: (value) => setState(() => rememberMe = value ?? true),
                ),
                const Expanded(
                  child: Text('Manter conectado', style: TextStyle(color: TuristarColors.muted)),
                ),
                TextButton(
                  onPressed: createAccount || isLoading || isGoogleLoading ? null : _openForgotPassword,
                  child: const Text('Esqueci a senha'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading || isGoogleLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TuristarColors.orange,
                  foregroundColor: TuristarColors.navyDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: TuristarColors.navyDark),
                      )
                    : Text(
                        createAccount ? 'Criar Conta' : 'Entrar',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Expanded(child: Divider(color: TuristarColors.line)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('ou continue com', style: TextStyle(color: TuristarColors.muted)),
                ),
                Expanded(child: Divider(color: TuristarColors.line)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isLoading || isGoogleLoading ? null : _signInWithGoogle,
                    icon: isGoogleLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.g_mobiledata, size: 26),
                    label: const Text('Google'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showPendingAuthMessage('Login corporativo'),
                    icon: const Icon(Icons.business_center_outlined, size: 19),
                    label: const Text('Empresa'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Center(
              child: TextButton(
                onPressed: () => setState(() => createAccount = !createAccount),
                child: Text(
                  createAccount ? 'Ja tenho conta. Entrar' : 'Ainda nao tenho conta. Criar cadastro',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obrigatorio';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;
    if (!value!.contains('@')) {
      return 'Informe um e-mail valido';
    }
    return null;
  }

  Future<void> _submit() async {
    if (formKey.currentState?.validate() != true || isLoading || isGoogleLoading) {
      return;
    }

    setState(() => isLoading = true);
    try {
      final email = emailController.text.trim();
      final password = passwordController.text;

      if (createAccount) {
        await TuristarAuth.registerLocal(
          name: nameController.text.trim(),
          email: email,
          phone: phoneController.text.trim(),
          password: password,
          rememberMe: rememberMe,
        );
        _finishAuth(createAccount: true);
      } else {
        await TuristarAuth.loginLocal(
          email: email,
          password: password,
          rememberMe: rememberMe,
        );
        _finishAuth(createAccount: false);
      }
    } catch (error, stackTrace) {
      AuthDiagnostics.step(
        createAccount ? 'REGISTER' : 'LOGIN',
        'falha final na UI',
        error: error,
        stack: stackTrace,
      );
      if (createAccount && shouldSwallowFirebaseInfraError(error)) {
        FirebaseBootstrap.markChannelBroken(error);
        try {
          await TuristarAuth.registerLocal(
            name: nameController.text.trim(),
            email: emailController.text.trim(),
            phone: phoneController.text.trim(),
            password: passwordController.text,
            rememberMe: rememberMe,
          );
          _finishAuth(createAccount: true);
          return;
        } catch (retryError, retryStack) {
          AuthDiagnostics.step('REGISTER', 'retry local falhou', error: retryError, stack: retryStack);
          _showAuthError(authErrorMessage(retryError));
          return;
        }
      }
      if (!createAccount && error is AuthException && error.code == 'user-not-found') {
        _offerCreateAccount(error.message);
        return;
      }
      _showAuthError(authErrorMessage(error));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (isLoading || isGoogleLoading) return;

    setState(() => isGoogleLoading = true);
    try {
      await FirebaseBootstrap.ensureInitialized();
      if (!FirebaseBootstrap.isReady) {
        _showAuthError('Login com Google indisponivel no momento. Recarregue a pagina e tente novamente.');
        return;
      }

      final provider = GoogleAuthProvider();
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        await FirebaseAuth.instance.signInWithProvider(provider);
      }
      _finishAuth(createAccount: false, providerLabel: 'Google');
    } catch (error, stackTrace) {
      AuthDiagnostics.step('GOOGLE', 'signInWithPopup/signInWithProvider falhou', error: error, stack: stackTrace);
      _showAuthError(authErrorMessage(error));
    } finally {
      if (mounted) setState(() => isGoogleLoading = false);
    }
  }

  void _finishAuth({required bool createAccount, String? providerLabel}) {
    final message = providerLabel != null
        ? 'Login com $providerLabel realizado com sucesso.'
        : createAccount
            ? 'Cadastro realizado com sucesso.'
            : 'Login realizado com sucesso.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: TuristarColors.navy),
    );

    if (widget.requireSuccess) {
      Navigator.of(context).pop(true);
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const TuristarLandingPage()),
    );
  }

  void _offerCreateAccount(String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Conta nao encontrada'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              setState(() => createAccount = true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: TuristarColors.orange,
              foregroundColor: TuristarColors.navyDark,
            ),
            child: const Text('Criar cadastro'),
          ),
        ],
      ),
    );
  }

  void _openForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordPage(initialEmail: emailController.text.trim()),
      ),
    );
  }

  void _showAuthError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  void _showPendingAuthMessage(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action em breve na area do cliente.'),
        backgroundColor: TuristarColors.navy,
      ),
    );
  }
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController emailController;
  bool isSending = false;
  bool sentSuccessfully = false;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);

    return Scaffold(
      body: Container(
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).height,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              TuristarColors.navyDeep,
              TuristarColors.navy,
              Color(0xFFB87312),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutShell(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: mobile ? 18 : 42),
              child: mobile
                  ? Column(
                      children: [
                        const LoginBrandPanel(),
                        const SizedBox(height: 18),
                        _buildCard(context),
                      ],
                    )
                  : Row(
                      children: [
                        const Expanded(child: LoginBrandPanel()),
                        const SizedBox(width: 42),
                        SizedBox(width: 440, child: _buildCard(context)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Responsive.isMobile(context) ? 20 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 26,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: isSending ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: TuristarColors.navy),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: TuristarColors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Area do cliente',
                    style: TextStyle(color: TuristarColors.orangeDark, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Esqueci minha senha',
              style: TextStyle(
                color: TuristarColors.navy,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Informe seu e-mail para receber um link de recuperacao de senha.',
              style: TextStyle(color: TuristarColors.muted, height: 1.4),
            ),
            if (sentSuccessfully) ...[
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: TuristarColors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: TuristarColors.green.withOpacity(0.35)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline, color: TuristarColors.green),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Enviamos um link de recuperacao para seu e-mail.',
                        style: TextStyle(
                          color: TuristarColors.navy,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            LoginTextField(
              controller: emailController,
              label: 'E-mail',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              validator: validatePasswordResetEmailField,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isSending ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TuristarColors.orange,
                  foregroundColor: TuristarColors.navyDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: isSending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: TuristarColors.navyDark),
                      )
                    : const Text(
                        'Enviar link de recuperacao',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (formKey.currentState?.validate() != true || isSending) {
      return;
    }

    setState(() {
      isSending = true;
      sentSuccessfully = false;
    });

    try {
      await TuristarAuth.sendPasswordResetEmail(emailController.text);
      if (!mounted) return;
      setState(() => sentSuccessfully = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enviamos um link de recuperacao para seu e-mail.'),
          backgroundColor: TuristarColors.navy,
        ),
      );
    } catch (error, stackTrace) {
      AuthDiagnostics.step('PASSWORD_RESET', 'falha final na UI', error: error, stack: stackTrace);
      debugPrint('[TuristarAuth][PASSWORD_RESET] erro na UI: $error');
      if (!mounted) return;
      _showError(passwordResetErrorMessage(error));
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }
}

class LoginBrandPanel extends StatelessWidget {
  const LoginBrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const BrandLogoOnDark(),
        SizedBox(height: mobile ? 24 : 42),
        Text(
          'Sua viagem comecando em um login simples.',
          style: TextStyle(
            color: Colors.white,
            fontSize: mobile ? 34 : 48,
            fontWeight: FontWeight.w900,
            height: 1.05,
            letterSpacing: -1.1,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Entre para acompanhar reservas, receber ofertas personalizadas e falar com nosso suporte 24/7.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.82),
            fontSize: mobile ? 15 : 18,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        const Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            LoginBenefit(icon: Icons.confirmation_number_outlined, label: 'Reservas em um lugar'),
            LoginBenefit(icon: Icons.local_offer_outlined, label: 'Ofertas exclusivas'),
            LoginBenefit(icon: Icons.support_agent, label: 'Suporte premium'),
          ],
        ),
      ],
    );
  }
}

class BrandLogoOnDark extends StatelessWidget {
  const BrandLogoOnDark({super.key});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: const TuristarLogo(
        onDark: true,
        markSize: 72,
        titleSize: 30,
        taglineSize: 11,
      ),
    );
  }
}

class LoginBenefit extends StatelessWidget {
  const LoginBenefit({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: TuristarColors.orange, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class LoginModeSwitch extends StatelessWidget {
  const LoginModeSwitch({
    super.key,
    required this.createAccount,
    required this.onChanged,
  });

  final bool createAccount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: TuristarColors.page,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TuristarColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: LoginModeButton(
              label: 'Entrar',
              selected: !createAccount,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: LoginModeButton(
              label: 'Cadastrar',
              selected: createAccount,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class LoginModeButton extends StatelessWidget {
  const LoginModeButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? TuristarColors.navy : TuristarColors.muted,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class LoginTextField extends StatelessWidget {
  const LoginTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: TuristarColors.orange),
        suffixIcon: suffix,
        filled: true,
        fillColor: TuristarColors.page,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TuristarColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TuristarColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TuristarColors.orange, width: 2),
        ),
      ),
    );
  }
}

class HeroSection extends StatelessWidget {
  const HeroSection({
    super.key,
    required this.selectedService,
    required this.onServiceChanged,
    required this.onSearch,
  });

  final TravelService selectedService;
  final ValueChanged<TravelService> onServiceChanged;
  final ValueChanged<SearchRequest> onSearch;

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    final tablet = Responsive.isTablet(context);
    final titleSize = mobile ? 34.0 : (tablet ? 42.0 : 52.0);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            TuristarColors.navyDeep,
            TuristarColors.navy,
            Color(0xFF063D88),
            Color(0xFFB87312),
          ],
          stops: [0, 0.38, 0.68, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: HeroSkyPainter())),
          if (!mobile)
            Positioned(
              right: tablet ? 28 : 56,
              top: tablet ? 84 : 64,
              child: Transform.rotate(
                angle: -0.26,
                child: Icon(
                  Icons.airplanemode_active,
                  size: tablet ? 210 : 300,
                  color: Colors.white.withOpacity(0.78),
                ),
              ),
            ),
          LayoutShell(
            child: Padding(
              padding: EdgeInsets.only(top: mobile ? 34 : 56, bottom: mobile ? 24 : 34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: mobile ? double.infinity : 670),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: titleSize,
                              height: 1.08,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.2,
                            ),
                            children: const [
                              TextSpan(text: 'Explore o '),
                              TextSpan(text: 'Mundo', style: TextStyle(color: TuristarColors.orange)),
                              TextSpan(text: ' com\n'),
                              TextSpan(text: 'Confianca', style: TextStyle(color: TuristarColors.orange)),
                              TextSpan(text: ' e Seguranca'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'As melhores opcoes de viagens para voce e sua familia. Voos, hoteis, carros e pacotes com atendimento completo.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.92),
                            fontSize: mobile ? 15 : 18,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: mobile ? 26 : 34),
                  SearchHeroCard(
                    selectedService: selectedService,
                    onServiceChanged: onServiceChanged,
                    onSearch: onSearch,
                  ),
                  SizedBox(height: mobile ? 20 : 26),
                  const HeroStats(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HeroSkyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final orangePaint = Paint()..color = TuristarColors.orange.withOpacity(0.18);
    final whitePaint = Paint()..color = Colors.white.withOpacity(0.08);
    canvas.drawCircle(Offset(size.width * 0.86, size.height * 0.17), 170, orangePaint);
    canvas.drawCircle(Offset(size.width * 0.72, size.height * 0.08), 80, whitePaint);
    canvas.drawCircle(Offset(size.width * 0.18, size.height * 0.45), 140, whitePaint);

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..strokeWidth = 1;
    for (var i = 0; i < 9; i++) {
      final y = size.height * (0.16 + i * 0.08);
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 80), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SearchHeroCard extends StatefulWidget {
  const SearchHeroCard({
    super.key,
    required this.selectedService,
    required this.onServiceChanged,
    required this.onSearch,
  });

  final TravelService selectedService;
  final ValueChanged<TravelService> onServiceChanged;
  final ValueChanged<SearchRequest> onSearch;

  @override
  State<SearchHeroCard> createState() => _SearchHeroCardState();
}

class _SearchHeroCardState extends State<SearchHeroCard> {
  late final TextEditingController originController;
  late final TextEditingController destinationController;
  late final TextEditingController departureController;
  late final TextEditingController returnController;
  late final TextEditingController travelersController;
  int tripType = 0;
  int adults = 1;
  int children = 0;
  int cars = 1;

  @override
  void initState() {
    super.initState();
    originController = TextEditingController();
    destinationController = TextEditingController();
    departureController = TextEditingController();
    returnController = TextEditingController();
    travelersController = TextEditingController();
    _resetTravelersSummary();
  }

  @override
  void didUpdateWidget(covariant SearchHeroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedService != widget.selectedService) {
      adults = 1;
      children = 0;
      cars = 1;
      _resetTravelersSummary();
    }
  }

  void _resetTravelersSummary() {
    switch (widget.selectedService) {
      case TravelService.cars:
        travelersController.text = '$cars carro, automatico';
      case TravelService.hotels:
        travelersController.text = '$adults hospede${adults == 1 ? '' : 's'}';
      default:
        travelersController.text = '$adults passageiro${adults == 1 ? '' : 's'}, Economica';
    }
  }

  @override
  void dispose() {
    originController.dispose();
    destinationController.dispose();
    departureController.dispose();
    returnController.dispose();
    travelersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);

    return Container(
      padding: EdgeInsets.all(mobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(mobile ? 16 : 10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ServiceTabs(
            selectedService: widget.selectedService,
            onServiceChanged: widget.onServiceChanged,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => openReservationsPage(context),
              icon: const Icon(Icons.confirmation_number_outlined, size: 18),
              label: const Text('Minhas Reservas'),
            ),
          ),
          const SizedBox(height: 20),
          TripTypeSelector(
            service: widget.selectedService,
            selectedIndex: tripType,
            onChanged: (value) => setState(() => tripType = value),
          ),
          const SizedBox(height: 20),
          ResponsiveFields(
            children: [
              SearchTextField(
                controller: originController,
                label: _originLabel(widget.selectedService),
                hint: _originHint(widget.selectedService),
                icon: Icons.trip_origin,
              ),
              SearchTextField(
                controller: destinationController,
                label: _destinationLabel(widget.selectedService),
                hint: _destinationHint(widget.selectedService),
                icon: widget.selectedService.icon,
              ),
              SearchTextField(
                controller: departureController,
                label: _departureLabel(widget.selectedService),
                hint: 'Data inicial',
                icon: Icons.calendar_today,
                readOnly: true,
                onTap: () => _pickDate(departureController),
              ),
              SearchTextField(
                controller: returnController,
                label: _returnLabel(widget.selectedService),
                hint: 'Data final',
                icon: Icons.calendar_month,
                readOnly: true,
                onTap: () => _pickDate(returnController),
              ),
              SearchTextField(
                controller: travelersController,
                label: _travelersLabel(widget.selectedService),
                hint: 'Quantidade',
                icon: Icons.keyboard_arrow_down,
                readOnly: true,
                onTap: _pickTravelers,
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: TuristarColors.orange,
                foregroundColor: TuristarColors.navyDark,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                widget.selectedService.actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final origin = originController.text.trim();
    final destination = destinationController.text.trim();
    final departureDate = departureController.text.trim();
    final returnDate = returnController.text.trim();
    final travelers = travelersController.text.trim();

    if (origin.isEmpty || destination.isEmpty || departureDate.isEmpty || travelers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha origem, destino, datas e passageiros para buscar.'),
          backgroundColor: TuristarColors.navy,
        ),
      );
      return;
    }

    if (tripType == 0 && returnDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe a data de volta para viagens de ida e volta.'),
          backgroundColor: TuristarColors.navy,
        ),
      );
      return;
    }

    widget.onSearch(
      SearchRequest(
        service: widget.selectedService,
        origin: origin,
        destination: destination,
        departureDate: departureDate,
        returnDate: returnDate,
        travelers: travelers,
      ),
    );
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _parseIsoDate(controller.text) ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
      helpText: 'Selecione a data',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: TuristarColors.navy,
                  secondary: TuristarColors.orange,
                ),
          ),
          child: child!,
        );
      },
    );

    if (selected != null) {
      setState(() => controller.text = _formatIsoDate(selected));
    }
  }

  Future<void> _pickTravelers() async {
    var nextAdults = adults;
    var nextChildren = children;
    var nextCars = cars;
    final isCarSearch = widget.selectedService == TravelService.cars;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCarSearch ? 'Selecionar carros' : 'Selecionar passageiros',
                    style: const TextStyle(color: TuristarColors.navy, fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 18),
                  if (isCarSearch)
                    QuantityRow(
                      label: 'Carros',
                      subtitle: 'Quantidade de veiculos',
                      value: nextCars,
                      min: 1,
                      onChanged: (value) => setModalState(() => nextCars = value),
                    )
                  else ...[
                    QuantityRow(
                      label: 'Adultos',
                      subtitle: '12 anos ou mais',
                      value: nextAdults,
                      min: 1,
                      onChanged: (value) => setModalState(() => nextAdults = value),
                    ),
                    const Divider(),
                    QuantityRow(
                      label: 'Criancas',
                      subtitle: '2 a 11 anos',
                      value: nextChildren,
                      min: 0,
                      onChanged: (value) => setModalState(() => nextChildren = value),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(backgroundColor: TuristarColors.orange, foregroundColor: TuristarColors.navyDark),
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (confirmed == true) {
      setState(() {
        adults = nextAdults;
        children = nextChildren;
        cars = nextCars;
        travelersController.text = isCarSearch
            ? '$cars carro${cars == 1 ? '' : 's'}, automatico'
            : '$adults adulto${adults == 1 ? '' : 's'}${children > 0 ? ', $children crianca${children == 1 ? '' : 's'}' : ''}, Economica';
      });
    }
  }

  DateTime? _parseIsoDate(String value) {
    return DateTime.tryParse(value.trim());
  }

  String _formatIsoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

String _originLabel(TravelService service) {
  switch (service) {
    case TravelService.flights:
      return 'De onde?';
    case TravelService.hotels:
      return 'Cidade';
    case TravelService.cars:
      return 'Retirada';
    case TravelService.packages:
      return 'Origem';
  }
}

String _destinationLabel(TravelService service) {
  switch (service) {
    case TravelService.flights:
      return 'Para onde?';
    case TravelService.hotels:
      return 'Hospedagem em';
    case TravelService.cars:
      return 'Devolucao';
    case TravelService.packages:
      return 'Destino';
  }
}

String _departureLabel(TravelService service) => service == TravelService.hotels ? 'Check-in' : 'Ida';
String _returnLabel(TravelService service) => service == TravelService.hotels ? 'Check-out' : 'Volta';
String _travelersLabel(TravelService service) => service == TravelService.cars ? 'Carro' : 'Passageiros';
String _originHint(TravelService service) => service == TravelService.hotels ? 'Cidade ou regiao' : 'Cidade ou aeroporto de origem';
String _destinationHint(TravelService service) => service == TravelService.cars ? 'Local de devolucao' : 'Cidade, hotel ou destino';

class ServiceTabs extends StatelessWidget {
  const ServiceTabs({
    super.key,
    required this.selectedService,
    required this.onServiceChanged,
  });

  final TravelService selectedService;
  final ValueChanged<TravelService> onServiceChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final service in TravelService.values)
          ChoiceChip(
            selected: selectedService == service,
            avatar: Icon(
              service.icon,
              size: 18,
              color: selectedService == service ? Colors.white : TuristarColors.navy,
            ),
            label: Text(service.shortLabel),
            labelStyle: TextStyle(
              color: selectedService == service ? Colors.white : TuristarColors.navy,
              fontWeight: FontWeight.w900,
            ),
            selectedColor: TuristarColors.navy,
            backgroundColor: TuristarColors.page,
            side: BorderSide(color: selectedService == service ? TuristarColors.navy : TuristarColors.line),
            onSelected: (_) => onServiceChanged(service),
          ),
      ],
    );
  }
}

class TripTypeSelector extends StatelessWidget {
  const TripTypeSelector({
    super.key,
    required this.service,
    required this.selectedIndex,
    required this.onChanged,
  });

  final TravelService service;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = _optionsFor(service);

    return Wrap(
      spacing: 14,
      runSpacing: 10,
      children: [
        for (var i = 0; i < options.length; i++)
          TripTypeTile(
            icon: options[i].icon,
            title: options[i].title,
            subtitle: options[i].subtitle,
            selected: selectedIndex == i,
            onTap: () => onChanged(i),
          ),
      ],
    );
  }

  List<TripTypeOption> _optionsFor(TravelService service) {
    switch (service) {
      case TravelService.flights:
        return const [
          TripTypeOption(Icons.sync_alt, 'Ida e Volta', 'Viagem completa'),
          TripTypeOption(Icons.flight_takeoff, 'So Ida', 'Somente ida'),
          TripTypeOption(Icons.travel_explore, 'Multidestino', 'Varios destinos'),
        ];
      case TravelService.hotels:
        return const [
          TripTypeOption(Icons.hotel, 'Hotel', 'Quartos e suites'),
          TripTypeOption(Icons.pool, 'Resort', 'Lazer completo'),
          TripTypeOption(Icons.home_work, 'Pousada', 'Estadias especiais'),
        ];
      case TravelService.cars:
        return const [
          TripTypeOption(Icons.directions_car, 'Economico', 'Menor preco'),
          TripTypeOption(Icons.car_rental, 'SUV', 'Mais conforto'),
          TripTypeOption(Icons.electric_car, 'Eletrico', 'Baixa emissao'),
        ];
      case TravelService.packages:
        return const [
          TripTypeOption(Icons.beach_access, 'Praia', 'Sol e descanso'),
          TripTypeOption(Icons.location_city, 'Urbano', 'Cidades icones'),
          TripTypeOption(Icons.family_restroom, 'Familia', 'Viagem completa'),
        ];
    }
  }
}

class TripTypeOption {
  const TripTypeOption(this.icon, this.title, this.subtitle);

  final IconData icon;
  final String title;
  final String subtitle;
}

class TripTypeTile extends StatelessWidget {
  const TripTypeTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minWidth: 190),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? TuristarColors.orange.withOpacity(0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? TuristarColors.orange : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: TuristarColors.orange, size: 23),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900)),
                Text(subtitle, style: const TextStyle(color: TuristarColors.muted, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ResponsiveFields extends StatelessWidget {
  const ResponsiveFields({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < 650 ? 1 : (width < 980 ? 2 : 3);
        final spacing = 14.0;
        final itemWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class SearchTextField extends StatelessWidget {
  const SearchTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: Icon(icon, color: TuristarColors.navy, size: 19),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: TuristarColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: TuristarColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: TuristarColors.orange, width: 2),
        ),
      ),
    );
  }
}

class QuantityRow extends StatelessWidget {
  const QuantityRow({
    super.key,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final int value;
  final int min;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900)),
              Text(subtitle, style: const TextStyle(color: TuristarColors.muted, fontSize: 12)),
            ],
          ),
        ),
        IconButton(
          onPressed: value <= min ? null : () => onChanged(value - 1),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 38,
          child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        IconButton(
          onPressed: value >= 9 ? null : () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

class HeroStats extends StatelessWidget {
  const HeroStats({super.key});

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    final stats = const [
      (Icons.travel_explore, '100+', 'Destinos', 'Ao redor do mundo'),
      (Icons.support_agent, '24/7', 'Suporte', 'Atendimento sempre'),
      (Icons.verified_user, 'Seguranca', 'Total', 'Seus dados protegidos'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: mobile ? 16 : 90,
          runSpacing: 18,
          children: [
            for (final stat in stats)
              SizedBox(
                width: mobile ? constraints.maxWidth : 245,
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: TuristarColors.orange, width: 2),
                      ),
                      child: Icon(stat.$1, color: TuristarColors.orange),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stat.$2, style: const TextStyle(color: TuristarColors.orange, fontSize: 18, fontWeight: FontWeight.w900)),
                          Text(stat.$3, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
                          Text(stat.$4, style: TextStyle(color: Colors.white.withOpacity(0.74), fontSize: 12), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class ServicesSection extends StatelessWidget {
  const ServicesSection({super.key, required this.onServiceSelected});

  final ValueChanged<TravelService> onServiceSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(vertical: Responsive.isMobile(context) ? 28 : 38),
      child: LayoutShell(
        child: Column(
          children: [
            const SectionHeading(title: 'Nossos Servicos', subtitle: 'Tudo que voce precisa para sua viagem em um so lugar'),
            const SizedBox(height: 28),
            ResponsiveCardGrid(
              minCardWidth: 240,
              children: [
                ServiceCard(
                  service: TravelService.flights,
                  onTap: () => onServiceSelected(TravelService.flights),
                ),
                ServiceCard(
                  service: TravelService.hotels,
                  onTap: () => onServiceSelected(TravelService.hotels),
                ),
                ServiceCard(
                  service: TravelService.cars,
                  onTap: () => onServiceSelected(TravelService.cars),
                ),
                ServiceCard(
                  service: TravelService.packages,
                  onTap: () => onServiceSelected(TravelService.packages),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PackageOffer {
  const PackageOffer({
    required this.name,
    required this.duration,
    required this.summary,
    required this.icon,
    required this.imageAsset,
  });

  final String name;
  final String duration;
  final String summary;
  final IconData icon;
  final String imageAsset;
}

/// Pacotes mais vendidos cadastrados manualmente (Fase 1). Edite esta lista
/// para publicar novas ofertas; cada cartao gera um lead direto no WhatsApp.
const List<PackageOffer> kPopularPackages = [
  PackageOffer(
    name: 'Porto de Galinhas',
    duration: '7 noites',
    summary: 'Aereo + hospedagem + traslados inclusos',
    icon: Icons.beach_access,
    imageAsset: 'assets/images/packages/porto-de-galinhas.jpg',
  ),
  PackageOffer(
    name: 'Maragogi',
    duration: '5 noites',
    summary: 'O Caribe brasileiro com praias paradisiacas',
    icon: Icons.waves,
    imageAsset: 'assets/images/packages/maragogi.jpg',
  ),
  PackageOffer(
    name: 'Gramado',
    duration: '4 noites',
    summary: 'Serra gaucha com passeios e gastronomia',
    icon: Icons.cabin,
    imageAsset: 'assets/images/packages/gramado.jpg',
  ),
  PackageOffer(
    name: 'Patagonia',
    duration: '10 dias',
    summary: 'Roteiro completo entre Argentina e Chile',
    icon: Icons.landscape,
    imageAsset: 'assets/images/packages/patagonia.jpg',
  ),
  PackageOffer(
    name: 'Maceio + Maragogi',
    duration: '7 noites',
    summary: 'Combinado pelo melhor do litoral alagoano',
    icon: Icons.sailing,
    imageAsset: 'assets/images/packages/maceio-maragogi.jpg',
  ),
];

class PopularPackagesSection extends StatefulWidget {
  const PopularPackagesSection({super.key});

  @override
  State<PopularPackagesSection> createState() => _PopularPackagesSectionState();
}

class _PopularPackagesSectionState extends State<PopularPackagesSection> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: TuristarColors.page,
      padding: EdgeInsets.symmetric(vertical: Responsive.isMobile(context) ? 28 : 38),
      child: LayoutShell(
        child: Column(
          children: [
            const SectionHeading(
              title: 'Pacotes Mais Vendidos',
              subtitle: 'Escolha um destino e receba sua cotacao personalizada',
            ),
            const SizedBox(height: 28),
            StreamBuilder<List<TravelPackage>>(
              stream: FeaturedPackagesStore.watchHomePackages(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: TuristarColors.orange));
                }
                final packages = snapshot.data ?? [];
                if (packages.isEmpty) {
                  return ResponsiveCardGrid(
                    minCardWidth: 240,
                    children: [
                      for (final offer in kPopularPackages) _LegacyPackageOfferCard(offer: offer),
                    ],
                  );
                }

                return ResponsiveCardGrid(
                  minCardWidth: 240,
                  children: [
                    for (final package in packages) PackageHomeCard(package: package),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LegacyPackageOfferCard extends StatelessWidget {
  const _LegacyPackageOfferCard({required this.offer});

  final PackageOffer offer;

  @override
  Widget build(BuildContext context) {
    return PackageOfferCard(offer: offer);
  }
}

class PackageOfferCard extends StatelessWidget {
  const PackageOfferCard({super.key, required this.offer});

  final PackageOffer offer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TuristarColors.line),
        boxShadow: const [BoxShadow(color: Color(0x09000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 128,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  offer.imageAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFEAF2FF),
                    alignment: Alignment.center,
                    child: Icon(offer.icon, color: TuristarColors.navy, size: 34),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 48,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.45)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: TuristarColors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      offer.duration,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.name,
                  style: const TextStyle(color: TuristarColors.navy, fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  offer.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: TuristarColors.muted, fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Whatsapp.open(context, Whatsapp.packageInterest(offer.name)),
                    icon: const Icon(Icons.chat, size: 16),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TuristarColors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    label: const Text('Tenho interesse', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ResponsiveCardGrid extends StatelessWidget {
  const ResponsiveCardGrid({
    super.key,
    required this.children,
    this.minCardWidth = 260,
    this.spacing = 18,
  });

  final List<Widget> children;
  final double minCardWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = (width / minCardWidth).floor().clamp(1, 4).toInt();
        final itemWidth = (width - spacing * (count - 1)) / count;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class ServiceCard extends StatelessWidget {
  const ServiceCard({super.key, required this.service, required this.onTap});

  final TravelService service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final data = _serviceCopy(service);
    return Container(
      height: 252,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TuristarColors.line),
        boxShadow: const [BoxShadow(color: Color(0x09000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(color: data.background, shape: BoxShape.circle),
            child: Icon(service.icon, color: data.iconColor, size: 32),
          ),
          const SizedBox(height: 12),
          Text(service.label, textAlign: TextAlign.center, style: const TextStyle(color: TuristarColors.navy, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              data.description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: TuristarColors.muted, fontSize: 12, height: 1.35),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: TuristarColors.navy,
              side: const BorderSide(color: TuristarColors.navy),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              minimumSize: const Size(0, 40),
            ),
            child: Text(service.actionLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

ServiceCopy _serviceCopy(TravelService service) {
  switch (service) {
    case TravelService.flights:
      return const ServiceCopy(Color(0xFFEAF2FF), Color(0xFF4E8DFF), 'Milhares de rotas com as melhores companhias');
    case TravelService.hotels:
      return const ServiceCopy(Color(0xFFFFF2D8), Color(0xFFF6A313), 'Hoteis, pousadas e resorts com tarifas competitivas');
    case TravelService.cars:
      return const ServiceCopy(Color(0xFFE1F8EC), Color(0xFF1DBE72), 'Retire seu carro no aeroporto ou cidade de destino');
    case TravelService.packages:
      return const ServiceCopy(Color(0xFFF1E8FF), Color(0xFF7C3AED), 'Monte viagem completa com voo, hotel e experiencias');
  }
}

class ServiceCopy {
  const ServiceCopy(this.background, this.iconColor, this.description);

  final Color background;
  final Color iconColor;
  final String description;
}

class WhyChooseSection extends StatelessWidget {
  const WhyChooseSection({super.key});

  @override
  Widget build(BuildContext context) {
    final benefits = const [
      BenefitData(Icons.credit_card, 'Melhor Preco', 'Garantimos os melhores precos do mercado para sua viagem'),
      BenefitData(Icons.refresh, 'Protecao de Compra', 'Sua compra 100% protegida com garantia de reembolso'),
      BenefitData(Icons.verified_user, 'Confianca Comprovada', 'Mais de 100.000 clientes satisfeitos ao redor do mundo'),
      BenefitData(Icons.local_offer, 'Ofertas Exclusivas', 'Acesso a ofertas especiais e promocoes VIP'),
      BenefitData(Icons.public, 'Cobertura Global', 'Atendemos em mais de 100 paises e 1.000 destinos'),
      BenefitData(Icons.lock, 'Pagamento Seguro', 'Seus dados e pagamentos protegidos com criptografia'),
      BenefitData(Icons.support_agent, 'Suporte 24/7', 'Nossa equipe esta sempre disponivel para ajudar voce'),
      BenefitData(Icons.swap_calls, 'Flexibilidade Total', 'Altere ou cancele sua viagem com facilidade'),
    ];

    return Container(
      color: TuristarColors.page,
      padding: const EdgeInsets.only(top: 18, bottom: 28),
      child: LayoutShell(
        child: Column(
          children: [
            const SectionHeading(title: 'Por Que Escolher Turistar?', subtitle: 'Somos lideres em inovacao e atendimento no mercado de viagens'),
            const SizedBox(height: 18),
            ResponsiveCardGrid(
              minCardWidth: 430,
              spacing: 12,
              children: [
                for (final benefit in benefits) BenefitTile(benefit: benefit),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BenefitData {
  const BenefitData(this.icon, this.title, this.description);

  final IconData icon;
  final String title;
  final String description;
}

class BenefitTile extends StatelessWidget {
  const BenefitTile({super.key, required this.benefit});

  final BenefitData benefit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TuristarColors.line),
      ),
      child: Row(
        children: [
          Icon(benefit.icon, color: TuristarColors.navy, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(benefit.title, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900, fontSize: 13)),
                Text(benefit.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: TuristarColors.muted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CallToActionSection extends StatelessWidget {
  const CallToActionSection({super.key, required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);

    return Container(
      color: TuristarColors.page,
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutShell(
        child: Container(
          padding: EdgeInsets.all(mobile ? 18 : 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [TuristarColors.navy, Color(0xFF2D3329), TuristarColors.orangeDark],
            ),
          ),
          child: mobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CtaCopy(),
                    const SizedBox(height: 18),
                    SizedBox(width: double.infinity, child: CtaButton(onSearch: onSearch)),
                  ],
                )
              : Row(
                  children: [
                    const Expanded(child: CtaCopy()),
                    CtaButton(onSearch: onSearch),
                  ],
                ),
        ),
      ),
    );
  }
}

class CtaCopy extends StatelessWidget {
  const CtaCopy({super.key});

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    return Row(
      children: [
        Container(
          width: mobile ? 58 : 74,
          height: mobile ? 58 : 74,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(Icons.flight_takeoff, color: TuristarColors.orange, size: mobile ? 32 : 42),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pronto para Comecar?', style: TextStyle(color: Colors.white, fontSize: mobile ? 21 : 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('Encontre as melhores opcoes de viagem para seu proximo destino', style: TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}

class CtaButton extends StatelessWidget {
  const CtaButton({super.key, required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: Responsive.isMobile(context) ? double.infinity : 230,
      height: 58,
      child: ElevatedButton(
        onPressed: onSearch,
        style: ElevatedButton.styleFrom(
          backgroundColor: TuristarColors.navy,
          foregroundColor: Colors.white,
          side: const BorderSide(color: TuristarColors.orange, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          elevation: 8,
          shadowColor: TuristarColors.orange.withOpacity(0.45),
        ),
        child: const Text('Buscar Agora', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: TuristarColors.navy,
            fontSize: Responsive.isMobile(context) ? 23 : 27,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 5),
        Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: TuristarColors.muted, fontSize: 13)),
      ],
    );
  }
}

class FooterSection extends StatelessWidget {
  const FooterSection({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 880;

    return Container(
      color: TuristarColors.navyDark,
      padding: const EdgeInsets.only(top: 34, bottom: 24),
      child: LayoutShell(
        child: Column(
          children: [
            compact
                ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FooterBrand(),
                      SizedBox(height: 26),
                      FooterLinks(),
                    ],
                  )
                : const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: FooterBrand()),
                      Expanded(flex: 5, child: FooterLinks()),
                    ],
                  ),
            const SizedBox(height: 28),
            Divider(color: Colors.white.withOpacity(0.12)),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '(c) 2024 Turistar Viagens e Turismo Ltda. Todos os direitos reservados.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                if (!compact) const PaymentBadges(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FooterBrand extends StatelessWidget {
  const FooterBrand({super.key});

  static const instagramUrl = 'https://www.instagram.com/agencia.turistar';
  static const tiktokUrl = 'https://www.tiktok.com/@turistar.viagens3';

  static Future<void> _openSocialLink(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel abrir o link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BrandLogo(onDark: true),
        const SizedBox(height: 18),
        const Text(
          'A Turistar e sua parceira de confianca para viagens inesqueciveis.',
          style: TextStyle(color: Colors.white70, height: 1.45),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            SocialDot(
              icon: Icons.chat_outlined,
              onTap: () => Whatsapp.open(context, 'Ola! Vim pelo site da Turistar Viagens.'),
            ),
            SocialDot(
              label: 'ig',
              onTap: () => _openSocialLink(context, instagramUrl),
            ),
            SocialDot(
              label: 'tt',
              onTap: () => _openSocialLink(context, tiktokUrl),
            ),
          ],
        ),
      ],
    );
  }
}

class SocialDot extends StatelessWidget {
  const SocialDot({
    super.key,
    this.label,
    this.icon,
    this.onTap,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: const EdgeInsets.only(right: 12),
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
      child: icon != null
          ? Icon(icon, color: Colors.white, size: 14)
          : Text(label ?? '', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
    );

    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: content,
    );
  }
}

class FooterLinks extends StatelessWidget {
  const FooterLinks({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 60,
      runSpacing: 24,
      children: const [
        FooterColumn(title: 'Servicos', items: ['Passagens Aereas', 'Hospedagens', 'Aluguel de Carros', 'Pacotes de Viagem', 'Seguros Viagem']),
        FooterColumn(title: 'Empresa', items: ['Sobre Nos', 'Trabalhe Conosco', 'Politica de Privacidade', 'Termos de Uso', 'Imprensa']),
        FooterColumn(title: 'Ajuda', items: ['Central de Ajuda', 'Fale Conosco', 'Perguntas Frequentes', 'Politica de Reembolso']),
        FooterContact(),
      ],
    );
  }
}

class FooterColumn extends StatelessWidget {
  const FooterColumn({super.key, required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Text(item, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class FooterContact extends StatelessWidget {
  const FooterContact({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Contato', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          SizedBox(height: 14),
          ContactLine(icon: Icons.phone, label: '(11) 4002-8922'),
          ContactLine(icon: Icons.mail, label: 'contato@turistar.com.br'),
          ContactLine(icon: Icons.access_time, label: 'Atendimento 24/7'),
        ],
      ),
    );
  }
}

class ContactLine extends StatelessWidget {
  const ContactLine({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: TuristarColors.orange, size: 16),
          const SizedBox(width: 10),
          Flexible(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        ],
      ),
    );
  }
}

class PaymentBadges extends StatelessWidget {
  const PaymentBadges({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        PaymentBadge(label: 'VISA'),
        PaymentBadge(label: 'MC'),
        PaymentBadge(label: 'elo'),
        PaymentBadge(label: 'pix'),
      ],
    );
  }
}

class PaymentBadge extends StatelessWidget {
  const PaymentBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key, required this.request});

  final SearchRequest request;

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  late final Future<SearchResultState> resultsFuture;

  @override
  void initState() {
    super.initState();
    resultsFuture = SearchRepository().search(widget.request);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TuristarColors.navy,
        foregroundColor: Colors.white,
        title: Text('${widget.request.service.shortLabel} encontrados'),
      ),
      body: LayoutShell(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: Responsive.isMobile(context) ? 18 : 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.request.origin} para ${widget.request.destination}',
                style: TextStyle(
                  color: TuristarColors.navy,
                  fontSize: Responsive.isMobile(context) ? 23 : 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '${widget.request.departureDate} - ${widget.request.returnDate} - ${widget.request.travelers}',
                style: const TextStyle(color: TuristarColors.muted),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<SearchResultState>(
                  future: resultsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final state = snapshot.data ??
                        SearchResultState(
                          items: SearchCatalog.resultsFor(widget.request),
                          source: SearchResultSource.mock,
                          notice: 'Nao foi possivel carregar a API. Exibindo dados demonstrativos.',
                        );

                    return Column(
                      children: [
                        ResultSummary(state: state, service: widget.request.service),
                        const SizedBox(height: 18),
                        Expanded(
                          child: state.items.isEmpty
                              ? const EmptyResults()
                              : ListView.separated(
                                  itemCount: state.items.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                                  itemBuilder: (context, index) {
                                    final item = state.items[index];
                                    return SearchResultCard(
                                      item: item,
                                      onSelect: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => PassengerDetailsPage(
                                              request: widget.request,
                                              offer: item,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ResultSummary extends StatelessWidget {
  const ResultSummary({super.key, required this.state, required this.service});

  final SearchResultState state;
  final TravelService service;

  @override
  Widget build(BuildContext context) {
    final usingApi = state.source == SearchResultSource.api;
    final message = state.notice ??
        (usingApi
            ? '${state.items.length} ofertas reais retornadas pelo provedor configurado.'
            : '${state.items.length} ofertas demonstrativas. Configure o backend para dados reais.');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TuristarColors.line),
      ),
      child: Row(
        children: [
          Icon(service.icon, color: TuristarColors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyResults extends StatelessWidget {
  const EmptyResults({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Nenhum resultado encontrado. Ajuste a busca e tente novamente.'),
    );
  }
}

class SearchResultCard extends StatelessWidget {
  const SearchResultCard({super.key, required this.item, required this.onSelect});

  final SearchResultItem item;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    return Container(
      padding: EdgeInsets.all(mobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TuristarColors.line),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 14, offset: Offset(0, 8))],
      ),
      child: mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ResultInfo(item: item),
                const SizedBox(height: 14),
                _ResultPrice(item: item, onSelect: onSelect),
              ],
            )
          : Row(
              children: [
                Expanded(child: _ResultInfo(item: item)),
                const SizedBox(width: 18),
                _ResultPrice(item: item, onSelect: onSelect),
              ],
            ),
    );
  }
}

class _ResultInfo extends StatelessWidget {
  const _ResultInfo({required this.item});

  final SearchResultItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(color: TuristarColors.orange.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(item.icon, color: TuristarColors.orange),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: const TextStyle(color: TuristarColors.navy, fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(item.subtitle, style: const TextStyle(color: TuristarColors.muted)),
              const SizedBox(height: 5),
              Text(item.details, style: const TextStyle(color: TuristarColors.text, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(item.badge, style: const TextStyle(color: TuristarColors.orange, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultPrice extends StatelessWidget {
  const _ResultPrice({required this.item, required this.onSelect});

  final SearchResultItem item;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: Responsive.isMobile(context) ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(item.price, style: const TextStyle(color: TuristarColors.orange, fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: onSelect,
          style: ElevatedButton.styleFrom(backgroundColor: TuristarColors.orange, foregroundColor: TuristarColors.navyDark),
          child: const Text('Selecionar'),
        ),
      ],
    );
  }
}

class PassengerInfo {
  const PassengerInfo({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.document,
    required this.birthDate,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String document;
  final String birthDate;

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'document': document,
      'birthDate': birthDate,
    };
  }
}

class BookingDraft {
  const BookingDraft({
    required this.request,
    required this.offer,
    required this.passenger,
    required this.fareRules,
  });

  final SearchRequest request;
  final SearchResultItem offer;
  final PassengerInfo passenger;
  final FareRules fareRules;
}

class FareRules {
  const FareRules({
    required this.summary,
    required this.penalty,
    required this.baggage,
    required this.refundable,
  });

  final String summary;
  final String penalty;
  final String baggage;
  final bool refundable;
}

class BookingConfirmation {
  const BookingConfirmation({
    required this.locator,
    required this.status,
    required this.provider,
    required this.createdAt,
  });

  final String locator;
  final String status;
  final String provider;
  final DateTime createdAt;
}

class ReservationHistoryItem {
  const ReservationHistoryItem({
    required this.locator,
    required this.route,
    required this.passenger,
    required this.date,
    required this.status,
    required this.price,
  });

  final String locator;
  final String route;
  final String passenger;
  final String date;
  final String status;
  final String price;
}

const List<ReservationHistoryItem> reservationHistory = [];

class MyReservationsPage extends StatefulWidget {
  const MyReservationsPage({super.key});

  @override
  State<MyReservationsPage> createState() => _MyReservationsPageState();
}

class _MyReservationsPageState extends State<MyReservationsPage> {
  late Future<List<CustomerBooking>> _future;

  @override
  void initState() {
    super.initState();
    _future = CustomerAreaStore.listBookings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TuristarColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Minhas Reservas'),
      ),
      body: LayoutShell(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: FutureBuilder<List<CustomerBooking>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: TuristarColors.orange));
              }

              final bookings = snapshot.data ?? [];
              return ListView(
                children: [
                  BookingStepHeader(
                    step: 'Area do cliente',
                    title: 'Historico de reservas',
                    subtitle: TuristarAuth.session?.email == null
                        ? 'Consulte localizadores, acompanhe status e cancele reservas.'
                        : 'Reservas vinculadas a ${TuristarAuth.session!.email}.',
                  ),
                  const SizedBox(height: 18),
                  if (bookings.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TuristarColors.line),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.confirmation_number_outlined, color: TuristarColors.muted, size: 42),
                          SizedBox(height: 12),
                          Text(
                            'Nenhuma reserva encontrada',
                            style: TextStyle(color: TuristarColors.navy, fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Quando sua solicitacao virar reserva confirmada, ela aparecera aqui.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: TuristarColors.muted, height: 1.4),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final booking in bookings)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _CustomerBookingCard(booking: booking),
                      ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CustomerBookingCard extends StatelessWidget {
  const _CustomerBookingCard({required this.booking});

  final CustomerBooking booking;

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TuristarColors.line),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 14, offset: Offset(0, 8))],
      ),
      child: mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _icon(),
                const SizedBox(height: 12),
                _details(),
                const SizedBox(height: 14),
                _priceAndStatus(CrossAxisAlignment.start),
              ],
            )
          : Row(
              children: [
                _icon(),
                const SizedBox(width: 16),
                Expanded(child: _details()),
                const SizedBox(width: 16),
                _priceAndStatus(CrossAxisAlignment.end),
              ],
            ),
    );
  }

  Widget _icon() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(color: TuristarColors.orange.withOpacity(0.12), shape: BoxShape.circle),
      child: const Icon(Icons.confirmation_number_outlined, color: TuristarColors.orange),
    );
  }

  Widget _details() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(booking.route, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 6),
        Text('Localizador: ${booking.locator}', style: const TextStyle(color: TuristarColors.text, fontWeight: FontWeight.w700)),
        if (booking.passenger.isNotEmpty)
          Text('Passageiro: ${booking.passenger}', style: const TextStyle(color: TuristarColors.muted)),
      ],
    );
  }

  Widget _priceAndStatus(CrossAxisAlignment align) {
    return Column(
      crossAxisAlignment: align,
      children: [
        if (booking.price.isNotEmpty)
          Text(
            booking.price.startsWith('R\$') ? booking.price : 'R\$ ${booking.price}',
            style: const TextStyle(color: TuristarColors.orange, fontWeight: FontWeight.w900, fontSize: 18),
          ),
        const SizedBox(height: 6),
        Text(booking.status, style: const TextStyle(color: TuristarColors.muted, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class ReservationHistoryCard extends StatelessWidget {
  const ReservationHistoryCard({super.key, required this.reservation});

  final ReservationHistoryItem reservation;

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TuristarColors.line),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 14, offset: Offset(0, 8))],
      ),
      child: mobile ? _mobileContent() : _desktopContent(),
    );
  }

  Widget _desktopContent() {
    return Row(
      children: [
        _icon(),
        const SizedBox(width: 16),
        Expanded(child: _details()),
        const SizedBox(width: 16),
        _priceAndStatus(CrossAxisAlignment.end),
      ],
    );
  }

  Widget _mobileContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _icon(),
        const SizedBox(height: 12),
        _details(),
        const SizedBox(height: 14),
        _priceAndStatus(CrossAxisAlignment.start),
      ],
    );
  }

  Widget _icon() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(color: TuristarColors.orange.withOpacity(0.12), shape: BoxShape.circle),
      child: const Icon(Icons.confirmation_number_outlined, color: TuristarColors.orange),
    );
  }

  Widget _details() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(reservation.locator, style: const TextStyle(color: TuristarColors.navy, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('${reservation.route} | ${reservation.date}', style: const TextStyle(color: TuristarColors.muted)),
        const SizedBox(height: 4),
        Text(reservation.passenger, style: const TextStyle(color: TuristarColors.text, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _priceAndStatus(CrossAxisAlignment alignment) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(reservation.price, style: const TextStyle(color: TuristarColors.orange, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Chip(label: Text(reservation.status), backgroundColor: TuristarColors.page),
      ],
    );
  }
}

class PassengerDetailsPage extends StatefulWidget {
  const PassengerDetailsPage({
    super.key,
    required this.request,
    required this.offer,
  });

  final SearchRequest request;
  final SearchResultItem offer;

  @override
  State<PassengerDetailsPage> createState() => _PassengerDetailsPageState();
}

class _PassengerDetailsPageState extends State<PassengerDetailsPage> {
  final formKey = GlobalKey<FormState>();
  final firstNameController = TextEditingController(text: 'Daniel');
  final lastNameController = TextEditingController(text: 'Rodrigues');
  final emailController = TextEditingController(text: 'cliente@turistar.com.br');
  final phoneController = TextEditingController(text: '11999999999');
  final documentController = TextEditingController(text: '12345678900');
  final birthDateController = TextEditingController(text: '1990-01-01');
  late final Future<FareRules> rulesFuture;

  @override
  void initState() {
    super.initState();
    rulesFuture = BookingRepository().getFareRules(widget.offer);
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    documentController.dispose();
    birthDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: TuristarColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Dados do passageiro'),
      ),
      body: LayoutShell(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: mobile ? 18 : 28),
          child: ListView(
            children: [
              BookingStepHeader(
                step: 'Etapa 2 de 4',
                title: 'Informe os dados para reservar',
                subtitle: 'Esses campos antecipam o checklist de homologacao Wooba.',
              ),
              const SizedBox(height: 18),
              OfferSummaryCard(offer: widget.offer),
              const SizedBox(height: 18),
              FutureBuilder<FareRules>(
                future: rulesFuture,
                builder: (context, snapshot) {
                  final rules = snapshot.data ?? BookingRepository.mockFareRules(widget.offer);
                  return FareRulesCard(rules: rules);
                },
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: TuristarColors.line),
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Passageiro adulto', style: TextStyle(color: TuristarColors.navy, fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 16),
                      ResponsiveFields(
                        children: [
                          BookingTextField(controller: firstNameController, label: 'Nome', icon: Icons.person_outline),
                          BookingTextField(controller: lastNameController, label: 'Sobrenome', icon: Icons.person_outline),
                          BookingTextField(controller: emailController, label: 'E-mail', icon: Icons.mail_outline, keyboardType: TextInputType.emailAddress),
                          BookingTextField(controller: phoneController, label: 'Telefone', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                          BookingTextField(controller: documentController, label: 'CPF ou documento', icon: Icons.badge_outlined),
                          BookingTextField(controller: birthDateController, label: 'Nascimento (YYYY-MM-DD)', icon: Icons.calendar_today),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: _continueToReview,
                          style: ElevatedButton.styleFrom(backgroundColor: TuristarColors.orange, foregroundColor: TuristarColors.navyDark),
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Revisar reserva'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _continueToReview() async {
    if (formKey.currentState?.validate() != true) return;

    final rules = await rulesFuture.catchError((_) => BookingRepository.mockFareRules(widget.offer));
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingReviewPage(
          draft: BookingDraft(
            request: widget.request,
            offer: widget.offer,
            passenger: PassengerInfo(
              firstName: firstNameController.text.trim(),
              lastName: lastNameController.text.trim(),
              email: emailController.text.trim(),
              phone: phoneController.text.trim(),
              document: documentController.text.trim(),
              birthDate: birthDateController.text.trim(),
            ),
            fareRules: rules,
          ),
        ),
      ),
    );
  }
}

class BookingReviewPage extends StatefulWidget {
  const BookingReviewPage({super.key, required this.draft});

  final BookingDraft draft;

  @override
  State<BookingReviewPage> createState() => _BookingReviewPageState();
}

class _BookingReviewPageState extends State<BookingReviewPage> {
  bool acceptedRules = true;
  bool creating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TuristarColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Revisar reserva'),
      ),
      body: LayoutShell(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: ListView(
            children: [
              const BookingStepHeader(
                step: 'Etapa 3 de 4',
                title: 'Revise antes de criar a reserva',
                subtitle: 'Na homologacao, esta etapa corresponde ao pre-booking/reserva.',
              ),
              const SizedBox(height: 18),
              OfferSummaryCard(offer: widget.draft.offer),
              const SizedBox(height: 18),
              PassengerSummaryCard(passenger: widget.draft.passenger),
              const SizedBox(height: 18),
              FareRulesCard(rules: widget.draft.fareRules),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: acceptedRules,
                activeColor: TuristarColors.orange,
                onChanged: creating ? null : (value) => setState(() => acceptedRules = value ?? false),
                title: const Text('Confirmo que revisei dados do passageiro e regras tarifarias.'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: acceptedRules && !creating ? _createBooking : null,
                style: ElevatedButton.styleFrom(backgroundColor: TuristarColors.orange, foregroundColor: TuristarColors.navyDark),
                icon: creating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.confirmation_number_outlined),
                label: Text(creating ? 'Criando reserva...' : 'Criar reserva mock'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createBooking() async {
    setState(() => creating = true);
    final confirmation = await BookingRepository().createBooking(widget.draft);
    if (!mounted) return;
    setState(() => creating = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BookingConfirmationPage(
          draft: widget.draft,
          confirmation: confirmation,
        ),
      ),
    );
  }
}

class BookingConfirmationPage extends StatefulWidget {
  const BookingConfirmationPage({
    super.key,
    required this.draft,
    required this.confirmation,
  });

  final BookingDraft draft;
  final BookingConfirmation confirmation;

  @override
  State<BookingConfirmationPage> createState() => _BookingConfirmationPageState();
}

class _BookingConfirmationPageState extends State<BookingConfirmationPage> {
  bool cancelled = false;
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final status = cancelled ? 'CANCELLED' : widget.confirmation.status;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: TuristarColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Reserva criada'),
      ),
      body: LayoutShell(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: ListView(
            children: [
              BookingStepHeader(
                step: 'Etapa 4 de 4',
                title: 'Localizador ${widget.confirmation.locator}',
                subtitle: 'Status: $status | Provedor: ${widget.confirmation.provider}',
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: TuristarColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(cancelled ? Icons.cancel_outlined : Icons.check_circle_outline, color: cancelled ? Colors.red : TuristarColors.green, size: 42),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            cancelled ? 'Reserva cancelada no fluxo mock' : 'Reserva mock criada com sucesso',
                            style: const TextStyle(color: TuristarColors.navy, fontSize: 22, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    OfferSummaryCard(offer: widget.draft.offer),
                    const SizedBox(height: 18),
                    PassengerSummaryCard(passenger: widget.draft.passenger),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: busy ? null : _consultBooking,
                          icon: const Icon(Icons.search),
                          label: const Text('Consultar reserva'),
                        ),
                        OutlinedButton.icon(
                          onPressed: busy || cancelled ? null : _cancelBooking,
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Cancelar reserva'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                          style: ElevatedButton.styleFrom(backgroundColor: TuristarColors.orange, foregroundColor: TuristarColors.navyDark),
                          icon: const Icon(Icons.home_outlined),
                          label: const Text('Voltar para busca'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _consultBooking() async {
    setState(() => busy = true);
    final result = await BookingRepository().getBooking(widget.confirmation.locator);
    if (!mounted) return;
    setState(() => busy = false);
    _showMessage('Consulta mock: ${result.status} (${result.locator})');
  }

  Future<void> _cancelBooking() async {
    setState(() => busy = true);
    final result = await BookingRepository().cancelBooking(widget.confirmation.locator);
    if (!mounted) return;
    setState(() {
      busy = false;
      cancelled = result.status == 'CANCELLED';
    });
    _showMessage('Cancelamento mock confirmado: ${result.locator}');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: TuristarColors.navy),
    );
  }
}

class BookingStepHeader extends StatelessWidget {
  const BookingStepHeader({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
  });

  final String step;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(step, style: const TextStyle(color: TuristarColors.orange, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(title, style: const TextStyle(color: TuristarColors.navy, fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: TuristarColors.muted)),
      ],
    );
  }
}

class OfferSummaryCard extends StatelessWidget {
  const OfferSummaryCard({super.key, required this.offer});

  final SearchResultItem offer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TuristarColors.line),
      ),
      child: Row(
        children: [
          Icon(offer.icon, color: TuristarColors.orange, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(offer.title, style: const TextStyle(color: TuristarColors.navy, fontWeight: FontWeight.w900, fontSize: 17)),
                const SizedBox(height: 4),
                Text(offer.subtitle, style: const TextStyle(color: TuristarColors.muted)),
                const SizedBox(height: 4),
                Text(offer.details, style: const TextStyle(color: TuristarColors.text, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Text(offer.price, style: const TextStyle(color: TuristarColors.orange, fontWeight: FontWeight.w900, fontSize: 20)),
        ],
      ),
    );
  }
}

class FareRulesCard extends StatelessWidget {
  const FareRulesCard({super.key, required this.rules});

  final FareRules rules;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TuristarColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Regras tarifarias', style: TextStyle(color: TuristarColors.navy, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text(rules.summary, style: const TextStyle(color: TuristarColors.text)),
          const SizedBox(height: 6),
          Text('Bagagem: ${rules.baggage}', style: const TextStyle(color: TuristarColors.muted)),
          const SizedBox(height: 6),
          Text('Penalidade: ${rules.penalty}', style: const TextStyle(color: TuristarColors.muted)),
          const SizedBox(height: 6),
          Text(rules.refundable ? 'Tarifa reembolsavel' : 'Tarifa nao reembolsavel', style: const TextStyle(color: TuristarColors.orange, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class PassengerSummaryCard extends StatelessWidget {
  const PassengerSummaryCard({super.key, required this.passenger});

  final PassengerInfo passenger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TuristarColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Passageiro', style: TextStyle(color: TuristarColors.navy, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text('${passenger.firstName} ${passenger.lastName}', style: const TextStyle(color: TuristarColors.text, fontWeight: FontWeight.w800)),
          Text(passenger.email, style: const TextStyle(color: TuristarColors.muted)),
          Text('Documento: ${passenger.document} | Nascimento: ${passenger.birthDate}', style: const TextStyle(color: TuristarColors.muted)),
        ],
      ),
    );
  }
}

class BookingTextField extends StatelessWidget {
  const BookingTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Campo obrigatorio';
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: TuristarColors.orange),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class BookingRepository {
  BookingRepository({BookingGateway? gateway}) : gateway = gateway ?? const BookingGateway();

  final BookingGateway gateway;

  static FareRules mockFareRules(SearchResultItem offer) {
    return FareRules(
      summary: 'Regra mock para ${offer.title}. Confirmar politica final no retorno Wooba.',
      penalty: 'Alteracao/cancelamento sujeito a multa e diferenca tarifaria.',
      baggage: '1 bagagem de mao inclusa. Bagagem despachada conforme tarifa.',
      refundable: false,
    );
  }

  Future<FareRules> getFareRules(SearchResultItem offer) async {
    try {
      return await gateway.getFareRules(offer);
    } catch (_) {
      return mockFareRules(offer);
    }
  }

  Future<BookingConfirmation> createBooking(BookingDraft draft) async {
    try {
      return await gateway.createBooking(draft);
    } catch (_) {
      return BookingConfirmation(
        locator: 'TST${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        status: 'RESERVED',
        provider: 'mock',
        createdAt: DateTime.now(),
      );
    }
  }

  Future<BookingConfirmation> getBooking(String locator) async {
    try {
      return await gateway.getBooking(locator);
    } catch (_) {
      return BookingConfirmation(locator: locator, status: 'RESERVED', provider: 'mock', createdAt: DateTime.now());
    }
  }

  Future<BookingConfirmation> cancelBooking(String locator) async {
    try {
      return await gateway.cancelBooking(locator);
    } catch (_) {
      return BookingConfirmation(locator: locator, status: 'CANCELLED', provider: 'mock', createdAt: DateTime.now());
    }
  }
}

class BookingGateway {
  const BookingGateway({http.Client? client}) : _client = client;

  static const apiBaseUrl = String.fromEnvironment('TURISTAR_FLIGHTS_API_BASE_URL');
  final http.Client? _client;

  Future<FareRules> getFareRules(SearchResultItem offer) async {
    final decoded = await _get('flights/rules', {'offerId': offer.id ?? offer.title});
    return FareRules(
      summary: decoded['summary']?.toString() ?? 'Regras recebidas do provedor.',
      penalty: decoded['penalty']?.toString() ?? 'Consultar penalidade.',
      baggage: decoded['baggage']?.toString() ?? 'Consultar bagagem.',
      refundable: decoded['refundable'] == true,
    );
  }

  Future<BookingConfirmation> createBooking(BookingDraft draft) async {
    final decoded = await _post('bookings/create', {
      'offer': {
        'id': draft.offer.id,
        'title': draft.offer.title,
        'subtitle': draft.offer.subtitle,
        'price': draft.offer.price,
      },
      'passenger': draft.passenger.toJson(),
      'request': {
        'origin': draft.request.origin,
        'destination': draft.request.destination,
        'departureDate': draft.request.departureDate,
        'returnDate': draft.request.returnDate,
        'travelers': draft.request.travelers,
      },
    });
    return _confirmationFromJson(decoded);
  }

  Future<BookingConfirmation> getBooking(String locator) async {
    final decoded = await _get('bookings/get', {'locator': locator});
    return _confirmationFromJson(decoded);
  }

  Future<BookingConfirmation> cancelBooking(String locator) async {
    final decoded = await _post('bookings/cancel', {'locator': locator});
    return _confirmationFromJson(decoded);
  }

  Future<Map<String, dynamic>> _get(String path, Map<String, String> queryParameters) async {
    final uri = _uri(path, queryParameters);
    final client = _client ?? http.Client();
    try {
      final response = await client.get(uri, headers: const {'Accept': 'application/json'}).timeout(const Duration(seconds: 18));
      return _decode(response);
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> payload) async {
    final uri = _uri(path, const {});
    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(uri, headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'}, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 18));
      return _decode(response);
    } finally {
      if (_client == null) client.close();
    }
  }

  Uri _uri(String path, Map<String, String> queryParameters) {
    if (apiBaseUrl.trim().isEmpty) throw const FormatException('TURISTAR_FLIGHTS_API_BASE_URL not configured');
    final base = Uri.parse(apiBaseUrl);
    final normalizedPath = base.path.endsWith('/') ? '${base.path}$path' : '${base.path}/$path';
    return base.replace(path: normalizedPath, queryParameters: queryParameters.isEmpty ? null : queryParameters);
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Booking API returned HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) throw const FormatException('Unexpected booking response');
    return decoded;
  }

  BookingConfirmation _confirmationFromJson(Map<String, dynamic> json) {
    return BookingConfirmation(
      locator: json['locator']?.toString() ?? json['localizador']?.toString() ?? 'TST0000',
      status: json['status']?.toString() ?? 'RESERVED',
      provider: json['provider']?.toString() ?? json['source']?.toString() ?? 'mock',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

enum SearchResultSource { mock, api }

class SearchResultState {
  const SearchResultState({
    required this.items,
    required this.source,
    this.notice,
  });

  final List<SearchResultItem> items;
  final SearchResultSource source;
  final String? notice;
}

class SearchRepository {
  SearchRepository({FlightOffersGateway? flightOffersGateway})
      : flightOffersGateway = flightOffersGateway ?? const FlightOffersGateway();

  final FlightOffersGateway flightOffersGateway;

  Future<SearchResultState> search(SearchRequest request) async {
    if (request.service != TravelService.flights) {
      return SearchResultState(
        items: SearchCatalog.resultsFor(request),
        source: SearchResultSource.mock,
        notice: 'Busca de ${request.service.shortLabel.toLowerCase()} ainda usa dados demonstrativos.',
      );
    }

    try {
      final apiItems = await flightOffersGateway.search(request);
      if (apiItems.isEmpty) {
        return SearchResultState(
          items: SearchCatalog.resultsFor(request),
          source: SearchResultSource.mock,
          notice: 'O provedor nao retornou ofertas para esta rota. Exibindo ofertas demonstrativas para continuar o teste.',
        );
      }

      return SearchResultState(
        items: apiItems,
        source: SearchResultSource.api,
      );
    } catch (error) {
      return SearchResultState(
        items: SearchCatalog.resultsFor(request),
        source: SearchResultSource.mock,
        notice: 'API do provedor indisponivel ou nao configurada. Exibindo dados demonstrativos.',
      );
    }
  }
}

class FlightOffersGateway {
  const FlightOffersGateway({http.Client? client}) : _client = client;

  static const apiBaseUrl = String.fromEnvironment('TURISTAR_FLIGHTS_API_BASE_URL');
  final http.Client? _client;

  Future<List<SearchResultItem>> search(SearchRequest request) async {
    if (apiBaseUrl.trim().isEmpty) {
      throw const FormatException('TURISTAR_FLIGHTS_API_BASE_URL not configured');
    }

    final client = _client ?? http.Client();
    final uri = _searchUri(request);

    try {
      final response = await client.get(
        uri,
        headers: const {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 18));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Flight API returned HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Unexpected flight API response');
      }

      return FlightOffersParser.parse(decoded);
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Uri _searchUri(SearchRequest request) {
    final base = Uri.parse(apiBaseUrl);
    final path = base.path.endsWith('/')
        ? '${base.path}flights/search'
        : '${base.path}/flights/search';

    return base.replace(
      path: path,
      queryParameters: {
        'originLocationCode': _iataCode(request.origin),
        'destinationLocationCode': _iataCode(request.destination),
        'departureDate': _dateToIso(request.departureDate),
        if (request.returnDate.trim().isNotEmpty) 'returnDate': _dateToIso(request.returnDate),
        'adults': _adults(request.travelers).toString(),
        'currencyCode': 'BRL',
        'max': '10',
      },
    );
  }

  String _iataCode(String value) {
    return LocationResolver.codeFor(value);
  }

  int _adults(String value) {
    final match = RegExp(r'\d+').firstMatch(value);
    return int.tryParse(match?.group(0) ?? '')?.clamp(1, 9).toInt() ?? 1;
  }

  String _dateToIso(String value) {
    final trimmed = value.trim();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
      return trimmed;
    }

    final match = RegExp(r'(\d{1,2})\s+de\s+([A-Za-z]+),?\s+(\d{4})', caseSensitive: false).firstMatch(trimmed);
    if (match == null) {
      return DateTime.now().add(const Duration(days: 30)).toIso8601String().split('T').first;
    }

    final day = match.group(1)!.padLeft(2, '0');
    final month = _monthNumber(match.group(2)!);
    final year = match.group(3)!;
    return '$year-$month-$day';
  }

  String _monthNumber(String monthName) {
    final months = {
      'janeiro': '01',
      'fevereiro': '02',
      'marco': '03',
      'abril': '04',
      'maio': '05',
      'junho': '06',
      'julho': '07',
      'agosto': '08',
      'setembro': '09',
      'outubro': '10',
      'novembro': '11',
      'dezembro': '12',
    };
    return months[monthName.toLowerCase()] ?? '06';
  }
}

class FlightOffersParser {
  const FlightOffersParser._();

  static List<SearchResultItem> parse(Map<String, dynamic> payload) {
    final normalizedItems = payload['items'];
    if (normalizedItems is List) {
      return normalizedItems.whereType<Map<String, dynamic>>().map(_fromNormalized).toList();
    }

    final data = payload['data'];
    if (data is! List) {
      return const [];
    }

    return data.whereType<Map<String, dynamic>>().map(_fromAmadeusOffer).toList();
  }

  static SearchResultItem _fromNormalized(Map<String, dynamic> item) {
    return SearchResultItem(
      title: item['title']?.toString() ?? 'Oferta de voo',
      subtitle: item['subtitle']?.toString() ?? '',
      details: item['details']?.toString() ?? '',
      price: item['price']?.toString() ?? 'Consultar',
      badge: item['badge']?.toString() ?? 'API Amadeus',
      icon: Icons.flight_takeoff,
      fromApi: true,
    );
  }

  static SearchResultItem _fromAmadeusOffer(Map<String, dynamic> offer) {
    final itineraries = offer['itineraries'];
    final firstItinerary = itineraries is List && itineraries.isNotEmpty && itineraries.first is Map<String, dynamic>
        ? itineraries.first as Map<String, dynamic>
        : const <String, dynamic>{};

    final segments = firstItinerary['segments'];
    final typedSegments = segments is List ? segments.whereType<Map<String, dynamic>>().toList() : <Map<String, dynamic>>[];
    final firstSegment = typedSegments.isNotEmpty ? typedSegments.first : const <String, dynamic>{};
    final lastSegment = typedSegments.isNotEmpty ? typedSegments.last : firstSegment;

    final carrier = firstSegment['carrierCode']?.toString() ?? _firstString(offer['validatingAirlineCodes']) ?? 'Cia aerea';
    final flightNumber = firstSegment['number']?.toString();
    final departure = _locationCode(firstSegment['departure']);
    final arrival = _locationCode(lastSegment['arrival']);
    final departureTime = _time(firstSegment['departure']);
    final arrivalTime = _time(lastSegment['arrival']);
    final duration = _duration(firstItinerary['duration']?.toString());
    final stops = typedSegments.length <= 1 ? 'Direto' : '${typedSegments.length - 1} parada(s)';
    final price = offer['price'] is Map<String, dynamic> ? offer['price'] as Map<String, dynamic> : const <String, dynamic>{};
    final currency = price['currency']?.toString() ?? 'BRL';
    final total = price['grandTotal']?.toString() ?? price['total']?.toString() ?? 'Consultar';
    final seats = offer['numberOfBookableSeats']?.toString();

    return SearchResultItem(
      title: flightNumber == null ? carrier : '$carrier $flightNumber',
      subtitle: '$departure - $arrival | $departureTime - $arrivalTime',
      details: '$duration - $stops - ${seats == null ? 'Oferta Amadeus' : '$seats assentos'}',
      price: '$currency $total',
      badge: 'API Amadeus',
      icon: Icons.flight_takeoff,
      fromApi: true,
    );
  }

  static String? _firstString(Object? value) {
    if (value is List && value.isNotEmpty) {
      return value.first?.toString();
    }
    return null;
  }

  static String _locationCode(Object? value) {
    if (value is Map<String, dynamic>) {
      return value['iataCode']?.toString() ?? '---';
    }
    return '---';
  }

  static String _time(Object? value) {
    if (value is Map<String, dynamic>) {
      final at = value['at']?.toString();
      if (at != null && at.contains('T')) {
        return at.split('T').last.substring(0, 5);
      }
    }
    return '--:--';
  }

  static String _duration(String? value) {
    if (value == null || value.isEmpty) {
      return 'Duracao nao informada';
    }

    return value
        .replaceFirst('PT', '')
        .replaceAll('H', 'h ')
        .replaceAll('M', 'm')
        .trim();
  }
}

class SearchCatalog {
  static List<SearchResultItem> resultsFor(SearchRequest request) {
    switch (request.service) {
      case TravelService.flights:
        final origin = LocationResolver.codeFor(request.origin);
        final destination = LocationResolver.codeFor(request.destination, fallback: 'MIA');
        final route = '$origin - $destination';
        return [
          SearchResultItem(
            id: 'mock-${origin}-${destination}-latam',
            title: 'LATAM Airlines',
            subtitle: '$route | 08:00 - 14:30',
            details: '7h 30m - Direto - Bagagem inclusa',
            price: 'R\$ 1.200',
            badge: 'Mais vendido',
            icon: Icons.flight_takeoff,
          ),
          SearchResultItem(
            id: 'mock-${origin}-${destination}-gol',
            title: 'Gol Linhas Aereas',
            subtitle: '$route | 10:15 - 17:05',
            details: '8h 50m - 1 parada - Tarifa Light',
            price: 'R\$ 980',
            badge: 'Melhor preco',
            icon: Icons.flight,
          ),
          SearchResultItem(
            id: 'mock-${origin}-${destination}-azul',
            title: 'Azul',
            subtitle: '$route | 21:30 - 06:40',
            details: '9h 10m - Direto - Conforto extra',
            price: 'R\$ 1.390',
            badge: 'Conforto',
            icon: Icons.airlines,
          ),
        ];
      case TravelService.hotels:
        final destination = LocationResolver.labelFor(request.destination);
        return [
          SearchResultItem(title: 'Turistar Beach Resort', subtitle: '$destination - 4 estrelas', details: 'Cafe incluso - Piscina - 300m da praia', price: 'R\$ 620/noite', badge: 'Mais reservado', icon: Icons.hotel),
          SearchResultItem(title: 'Downtown Premium Hotel', subtitle: '$destination - Centro', details: 'Cancelamento gratis - Academia - Wi-Fi', price: 'R\$ 790/noite', badge: 'Melhor avaliacao', icon: Icons.apartment),
          SearchResultItem(title: 'Family Suites Airport', subtitle: '$destination - Proximo ao aeroporto', details: 'Suite familia - Transfer - Cafe incluso', price: 'R\$ 480/noite', badge: 'Ideal familia', icon: Icons.king_bed),
        ];
      case TravelService.cars:
        final pickup = LocationResolver.labelFor(request.origin);
        final dropoff = LocationResolver.labelFor(request.destination);
        return [
          SearchResultItem(title: 'Compacto Automatico', subtitle: 'Retirada em $pickup', details: 'Devolucao em $dropoff - Seguro basico', price: 'R\$ 180/dia', badge: 'Economico', icon: Icons.directions_car),
          SearchResultItem(title: 'SUV Confort', subtitle: 'Retirada e devolucao flexivel', details: '7 lugares - Cambio automatico - GPS', price: 'R\$ 320/dia', badge: 'Mais espaco', icon: Icons.car_rental),
          SearchResultItem(title: 'Eletrico Premium', subtitle: 'Pontos de recarga parceiros', details: 'Autonomia estendida - Seguro completo', price: 'R\$ 410/dia', badge: 'Sustentavel', icon: Icons.electric_car),
        ];
      case TravelService.packages:
        final destination = LocationResolver.labelFor(request.destination);
        return [
          SearchResultItem(title: '$destination Completo', subtitle: 'Voo + hotel + transfer', details: '7 noites - Hotel 4 estrelas - Suporte 24/7', price: 'R\$ 4.890', badge: 'Pacote completo', icon: Icons.luggage),
          SearchResultItem(title: '$destination Familia', subtitle: 'Voo + resort + carro', details: '10 noites - Ingressos opcionais - Seguro viagem', price: 'R\$ 6.450', badge: 'Ideal familia', icon: Icons.family_restroom),
          SearchResultItem(title: '$destination Essencial', subtitle: 'Multidestino opcional', details: '12 noites - Hoteis centrais - Transfers inclusos', price: 'R\$ 9.990', badge: 'Multidestino', icon: Icons.travel_explore),
        ];
    }
  }
}
