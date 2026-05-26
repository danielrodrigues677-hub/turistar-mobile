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
  });

  testWidgets('opens login page from menu action', (tester) async {
    await tester.pumpWidget(const TuristarApp());
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Entrar na Turistar'), findsOneWidget);
    expect(find.text('Criar cadastro'), findsOneWidget);
  });
}
