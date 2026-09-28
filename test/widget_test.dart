import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kultivia/screens/onboarding_screen.dart';

void main() {
  testWidgets('OnboardingScreen affiche le premier slide et un bouton Suivant',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));

    expect(find.text('Vos cultures, en bonne santé'), findsOneWidget);
    expect(find.text('Suivant'), findsOneWidget);
  });
}
