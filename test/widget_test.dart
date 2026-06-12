import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turistar_mobile/firebase_options.dart';
import 'package:turistar_mobile/main.dart';

Future<void> setTestViewport(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> pumpLandingPage(WidgetTester tester, {Size viewport = const Size(1440, 1200)}) async {
  await setTestViewport(tester, viewport);
  await tester.pumpWidget(const TuristarApp());
  await tester.pumpAndSettle();
}

Future<void> _openLogin(WidgetTester tester) async {
  final entrarAction = find.widgetWithText(HeaderAction, 'Entrar');
  if (tester.any(entrarAction)) {
    await tester.tap(entrarAction);
    return;
  }
  await tester.tap(find.byIcon(Icons.menu));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') rethrow;
    }
  });

  testWidgets('shows Turistar web landing page', (tester) async {
    await pumpLandingPage(tester);

    expect(find.text('Nossos Servicos'), findsOneWidget);
    expect(find.text('Pacotes Mais Vendidos'), findsOneWidget);
    expect(find.text('Por Que Escolher Turistar?'), findsOneWidget);
    expect(find.text('Pronto para Comecar?'), findsOneWidget);
    expect(find.text('Buscar Voos'), findsWidgets);
    expect(find.text('Hoteis'), findsOneWidget);
    expect(find.text('Carros'), findsOneWidget);
    expect(find.text('Pacotes'), findsWidgets);
    expect(find.text('Minhas Reservas'), findsOneWidget);
    expect(find.text('Tenho interesse'), findsWidgets);
    expect(find.text('Google'), findsNothing);
  });

  testWidgets('requires login before opening reservations', (tester) async {
    await pumpLandingPage(tester);
    await tester.tap(find.text('Minhas Reservas').last);
    await tester.pumpAndSettle();

    expect(find.text('Entrar na Turistar'), findsOneWidget);
    expect(find.text('Nenhuma reserva encontrada'), findsNothing);
  });

  testWidgets('requires login before searching flights', (tester) async {
    await pumpLandingPage(tester);

    await tester.ensureVisible(find.text('Buscar Agora'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buscar Agora'));
    await tester.pumpAndSettle();

    expect(find.text('Entrar na Turistar'), findsOneWidget);
  });

  testWidgets('opens login page from header action', (tester) async {
    await pumpLandingPage(tester, viewport: const Size(1600, 1200));
    await _openLogin(tester);
    await tester.pumpAndSettle();

    expect(find.text('Entrar na Turistar'), findsOneWidget);
    expect(find.textContaining('Criar cadastro'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
  });

  testWidgets('shows login form fields', (tester) async {
    await pumpLandingPage(tester, viewport: const Size(1600, 1400));
    await _openLogin(tester);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'E-mail'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Senha'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Entrar'), findsOneWidget);
  });
}
