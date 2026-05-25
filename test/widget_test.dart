import 'package:flutter_test/flutter_test.dart';
import 'package:turistar_mobile/main.dart';

void main() {
  testWidgets('shows Turistar home screen', (tester) async {
    await tester.pumpWidget(const TuristarApp());

    expect(find.text('Turistar'), findsOneWidget);
    expect(find.text('Buscar melhores ofertas'), findsOneWidget);
  });
}
