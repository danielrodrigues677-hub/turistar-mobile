import 'package:flutter_test/flutter_test.dart';
import 'package:turistar_mobile/main.dart';

void main() {
  testWidgets('shows Turistar web landing page', (tester) async {
    await tester.pumpWidget(const TuristarApp());

    expect(find.text('Nossos Servicos'), findsOneWidget);
    expect(find.text('Por Que Escolher Turistar?'), findsOneWidget);
    expect(find.text('Pronto para Comecar?'), findsOneWidget);
    expect(find.text('Buscar Voos'), findsWidgets);
  });
}
