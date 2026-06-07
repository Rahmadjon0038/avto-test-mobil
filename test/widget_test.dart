import 'package:flutter_test/flutter_test.dart';

import 'package:avto_test_mobil/main.dart';

void main() {
  testWidgets('shows starter screen text', (WidgetTester tester) async {
    await tester.pumpWidget(const RoadTestApp());

    expect(find.text('Road Test Mobil Ilova'), findsOneWidget);
    expect(find.text('Ishga tushmoqda...'), findsOneWidget);
  });
}
