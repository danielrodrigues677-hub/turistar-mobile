import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  });

  testWidgets('opens reservations history from search card', (tester) async {
    await pumpLandingPage(tester);
    await tester.tap(find.text('Minhas Reservas').last);
    await tester.pumpAndSettle();

    expect(find.text('Historico de reservas'), findsOneWidget);
    expect(find.text('TST482913'), findsOneWidget);
  });

  testWidgets('opens login page from header action', (tester) async {
    await pumpLandingPage(tester, viewport: const Size(1600, 1200));
    await _openLogin(tester);
    await tester.pumpAndSettle();

    expect(find.text('Entrar na Turistar'), findsOneWidget);
    expect(find.textContaining('Criar cadastro'), findsOneWidget);
  });

  testWidgets('returns to search home after login submit', (tester) async {
    await pumpLandingPage(tester, viewport: const Size(1600, 1400));
    await _openLogin(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'cliente@turistar.com.br');
    await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), 'senha123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Nossos Servicos'), findsOneWidget);
    expect(find.text('Entrar na Turistar'), findsNothing);
  });
}
