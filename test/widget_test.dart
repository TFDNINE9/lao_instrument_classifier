import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lao_instrument_classifier/app.dart';

void main() {
  testWidgets('App can build and render', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const LaoInstrumentClassifierApp());

    // Verify that the app builds without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
