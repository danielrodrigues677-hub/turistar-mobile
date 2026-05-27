import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turistar_mobile/main.dart';

void main() {
  testWidgets('shows Turistar web landing page', (tester) async {
    await tester.pumpWidget(const TuristarApp());

    expect(find.text('Nossos Servicos'), findsOneWidget);
    expect(find.text('Por Que Escolher Turistar?'), findsOneWidget);
    expect(find.text('Pronto para Comecar?'), findsOneWidget);
    expect(find.text('Buscar Voos'), findsWidgets);
    expect(find.text('Hoteis'), findsOneWidget);
    expect(find.text('Carros'), findsOneWidget);
    expect(find.text('Pacotes'), findsOneWidget);
    expect(find.text('Minhas Reservas'), findsOneWidget);
  });

  testWidgets('opens reservations history from search card', (tester) async {
    await tester.pumpWidget(const TuristarApp());
    await tester.tap(find.text('Minhas Reservas').last);
    await tester.pumpAndSettle();

    expect(find.text('Historico de reservas'), findsOneWidget);
    expect(find.text('TST482913'), findsOneWidget);
  });

  testWidgets('opens login page from menu action', (tester) async {
    await tester.pumpWidget(const TuristarApp());
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Entrar na Turistar'), findsOneWidget);
    expect(find.text('Criar cadastro'), findsOneWidget);
  });

  testWidgets('returns to search home after login submit', (tester) async {
    await tester.pumpWidget(const TuristarApp());
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'cliente@turistar.com.br');
    await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), 'senha123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Nossos Servicos'), findsOneWidget);
    expect(find.text('Entrar na Turistar'), findsNothing);
  });
}
