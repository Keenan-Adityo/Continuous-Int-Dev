import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:continous_int_dev/main.dart';
import 'package:continous_int_dev/features/wallet/domain/entities/savings_goal.dart';
import 'package:continous_int_dev/features/wallet/domain/entities/wallet_data.dart';
import 'package:continous_int_dev/features/wallet/domain/entities/wallet_entry.dart';

import 'support/memory_wallet.dart';
import 'support/widget_helpers.dart';

SavingsGoal emergency({int saved = 0, int target = 1000000}) => SavingsGoal(
  id: 'goal',
  title: 'Emergency fund',
  targetAmount: target,
  targetDate: DateTime(2026, 12, 31),
  contributions: saved == 0
      ? []
      : [
          GoalContribution(
            id: 'deposit',
            amount: saved,
            date: DateTime(2026, 1, 1),
          ),
        ],
);

Future<void> openGoals(WidgetTester tester, MemoryWallet repository) async {
  await tester.pumpWidget(PocketApp(repository: repository));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Goals'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'create, contribute, undo, edit and delete a goal without changing the wallet',
    (tester) async {
      final repository = MemoryWallet()
        ..entries = [
          WalletEntry(
            id: 'salary',
            title: 'Salary',
            amount: 5000000,
            type: EntryType.income,
            category: Category.salary,
            date: DateTime(2026, 1, 1),
          ),
        ];
      await openGoals(tester, repository);
      expect(find.text('Give your savings a purpose'), findsOneWidget);
      await tester.tap(find.text('Add goal'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Goal name'),
        'Emergency fund',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Target amount (IDR)'),
        '1000000',
      );
      await tapVisible(tester, find.text('Save goal'));
      expect(repository.data.goals.single.title, 'Emergency fund');
      await tapVisible(tester, find.text('Add contribution'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount (IDR)'),
        '250000',
      );
      await tapVisible(tester, find.text('Save contribution'));
      expect(repository.data.goals.single.savedAmount, 250000);
      expect(find.text('25% saved · Rp 750.000 to go'), findsOneWidget);
      expect(repository.entries.single.amount, 5000000);
      await tapVisible(tester, find.text('Contribution history'));
      await tapVisible(tester, find.byTooltip('Undo contribution'));
      await tester.tap(find.widgetWithText(FilledButton, 'Undo contribution'));
      await tester.pumpAndSettle();
      expect(repository.data.goals.single.savedAmount, 0);
      expect(find.text('No contributions yet.'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byTooltip('Edit goal'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Goal name'),
        'Holiday',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Target amount (IDR)'),
        '2000000',
      );
      await tapVisible(tester, find.text('Save goal'));
      expect(repository.data.goals.single.title, 'Holiday');
      await tapVisible(tester, find.byTooltip('Delete goal'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.data.goals.length, 1);
      await tapVisible(tester, find.byTooltip('Delete goal'));
      await tester.tap(find.widgetWithText(FilledButton, 'Delete goal'));
      await tester.pumpAndSettle();
      expect(repository.data.goals, isEmpty);
      expect(repository.entries.single.amount, 5000000);
    },
  );

  testWidgets(
    'overview links to savings goals; undo reopens an achieved goal',
    (tester) async {
      final repository = MemoryWallet()
        ..data = WalletData(goals: [emergency(saved: 1000000)]);
      await tester.pumpWidget(PocketApp(repository: repository));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('View savings goals'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tapVisible(tester, find.text('View savings goals'));
      expect(find.text('Goal achieved!'), findsOneWidget);
      expect(find.text('Add contribution'), findsNothing);
      await tapVisible(tester, find.text('Contribution history'));
      await tapVisible(tester, find.byTooltip('Undo contribution'));
      await tester.tap(find.widgetWithText(FilledButton, 'Undo contribution'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('Add contribution'), findsOneWidget);
    },
  );

  testWidgets(
    'invalid goal remains open and a failed save has visible feedback and retry',
    (tester) async {
      final repository = MemoryWallet();
      await openGoals(tester, repository);
      await tester.tap(find.text('Add goal'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Save goal'));
      expect(find.text('Give your goal a name'), findsOneWidget);
      await tester.ensureVisible(
        find.widgetWithText(TextFormField, 'Goal name'),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Goal name'),
        'Emergency fund',
      );
      await tester.ensureVisible(
        find.widgetWithText(TextFormField, 'Target amount (IDR)'),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Target amount (IDR)'),
        '1000000',
      );
      repository.failSaves = true;
      await tapVisible(tester, find.text('Save goal'));
      expect(
        find.text('Could not save this change. Please try again.'),
        findsWidgets,
      );
      expect(repository.data.goals, isEmpty);
      repository.failSaves = false;
      await tapVisible(tester, find.text('Save goal'));
      expect(repository.data.goals.single.title, 'Emergency fund');
    },
  );

  testWidgets('contributions cannot exceed the remaining target', (
    tester,
  ) async {
    final repository = MemoryWallet()
      ..data = WalletData(goals: [emergency(saved: 800000)]);
    await openGoals(tester, repository);
    await tapVisible(tester, find.text('Add contribution'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount (IDR)'),
      '200001',
    );
    await tapVisible(tester, find.text('Save contribution'));
    expect(find.text('Enter a whole amount from 1 to 200000'), findsOneWidget);
    expect(repository.data.goals.single.savedAmount, 800000);
    await tester.ensureVisible(
      find.widgetWithText(TextFormField, 'Amount (IDR)'),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount (IDR)'),
      '200000',
    );
    await tapVisible(tester, find.text('Save contribution'));
    expect(repository.data.goals.single.isComplete, isTrue);
    expect(find.text('Goal achieved!'), findsOneWidget);
  });

  testWidgets(
    'edit preserves savings, validates the target, and can remove the target date',
    (tester) async {
      final repository = MemoryWallet()
        ..data = WalletData(goals: [emergency(saved: 500000)]);
      await openGoals(tester, repository);
      await tapVisible(tester, find.byTooltip('Edit goal'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Target amount (IDR)'),
        '499999',
      );
      await tapVisible(tester, find.text('Save goal'));
      expect(
        find.text('The target cannot be less than the amount already saved.'),
        findsWidgets,
      );
      expect(repository.data.goals.single.targetAmount, 1000000);
      await tester.ensureVisible(
        find.widgetWithText(TextFormField, 'Target amount (IDR)'),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Target amount (IDR)'),
        '2000000',
      );
      await tapVisible(tester, find.text('Remove target date'));
      await tapVisible(tester, find.text('Set target date (optional)'));
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Save goal'));
      expect(repository.data.goals.single.targetDate, isNull);
      expect(repository.data.goals.single.savedAmount, 500000);
    },
  );

  testWidgets('goals and large rupiah amounts fit a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = MemoryWallet()
      ..data = WalletData(
        goals: [emergency(saved: 500000000000, target: 999999999999)],
      );
    await openGoals(tester, repository);
    await tapVisible(tester, find.text('Add contribution'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount (IDR)'),
      '1',
    );
    await tapVisible(tester, find.text('Save contribution'));
    expect(repository.data.goals.single.savedAmount, 500000000001);
    await tapVisible(tester, find.text('Contribution history'));
    expect(find.text('Contribution history'), findsWidgets);
  });
}
