import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rhu_android_app/app.dart';

void main() {
  testWidgets('RHU app builds successfully', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const RHUApp());

    expect(find.text('Tawi-Tawi RHU Mobile Portal'), findsOneWidget);
  });
}