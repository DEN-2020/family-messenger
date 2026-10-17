import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Hearth & Nordic Linen theme and security badges render cleanly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FamilyTheme.light(),
        darkTheme: FamilyTheme.dark(),
        home: const Scaffold(
          body: Column(
            children: [
              E2eeSecurityBadge(
                encrypted: true,
                label: 'E2EE (m.megolm.v1.aes-sha2)',
              ),
              ConnectionStateBanner(
                isConnected: false,
                statusText: 'Нет связи с сервером',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('E2EE (m.megolm.v1.aes-sha2)'), findsOneWidget);
    expect(find.text('Нет связи с сервером'), findsOneWidget);
  });
}
