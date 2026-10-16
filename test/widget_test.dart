import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:searchly/main.dart';
import 'package:searchly/services/context_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    ContextEngine.instance.stop();
  });

  testWidgets('Searchly launcher boots and renders correctly', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'has_completed_onboarding': true});

    await tester.pumpWidget(const SearchlyApp());
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(SearchlyApp), findsOneWidget);

    // Pump widget tree out so dispose is triggered cleanly
    await tester.pumpWidget(const SizedBox());
    ContextEngine.instance.stop();
  });
}
