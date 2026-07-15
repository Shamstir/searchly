import 'package:flutter_test/flutter_test.dart';

import 'package:searchly/main.dart';

void main() {
  testWidgets('Searchly launcher renders core controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SearchlyApp());

    expect(find.text('Search apps'), findsOneWidget);
    expect(find.text('JAIPUR, IN'), findsOneWidget);
  });
}
