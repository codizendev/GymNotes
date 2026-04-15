// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gymnotes/main.dart';

void main() {
  testWidgets('App shows bootstrap loading state', (WidgetTester tester) async {
    final bootstrapCompleter = Completer<void>();

    await tester.pumpWidget(
      WorkoutLoggerApp(bootstrap: ({onStage}) => bootstrapCompleter.future),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
