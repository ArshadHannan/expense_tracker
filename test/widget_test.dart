import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/main.dart';

void main() {
  testWidgets('Home page renders 8 cards', (WidgetTester tester) async {
    await tester.pumpWidget(const ExpenseTrackerApp());

    expect(find.text('Expense Tracker'), findsOneWidget);
    expect(find.byType(Card), findsNWidgets(8));
  });
}
