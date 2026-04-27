import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/main.dart';

void main() {
  testWidgets('Home page boots and shows the app bar', (tester) async {
    await tester.pumpWidget(const ExpenseTrackerApp());
    await tester.pump();

    expect(find.text('Expense Tracker'), findsOneWidget);
  });
}
