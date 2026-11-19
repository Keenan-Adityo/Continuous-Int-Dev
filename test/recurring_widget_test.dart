import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:continous_int_dev/main.dart';
import 'package:continous_int_dev/features/wallet/domain/entities/recurring_transaction.dart';
import 'package:continous_int_dev/features/wallet/domain/entities/wallet_data.dart';
import 'package:continous_int_dev/features/wallet/domain/entities/wallet_entry.dart';

import 'support/memory_wallet.dart';

RecurringTransaction rent({DateTime? due, bool enabled = true}) {
  final date = due ?? calendarDate(DateTime.now());
  return RecurringTransaction(
    id: 'rent',
    title: 'Apartment rent',
    amount: 2500000,
    type: EntryType.expense,
    category: Category.bills,
    anchorDate: date,
    nextDueDate: date,
    frequency: RepeatFrequency.monthly,
    enabled: enabled,
  );
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'create a schedule, confirm an occurrence, pause, resume, edit and delete',
    (tester) async {
      final repository = MemoryWallet();
      await tester.pumpWidget(PocketApp(repository: repository));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recurring'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add schedule'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount (IDR)'),
        '2500000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Apartment rent',
      );
      await tapVisible(tester, find.text('Save schedule'));
      expect(repository.data.schedules.single.title, 'Apartment rent');
      expect(repository.entries, isEmpty);
      expect(find.text('Due now'), findsOneWidget);
      await tapVisible(tester, find.text('Record occurrence'));
      expect(repository.entries, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.entries, isEmpty);
      await tapVisible(tester, find.text('Record occurrence'));
      await tester.tap(find.text('Confirm record'));
      await tester.pumpAndSettle();
      expect(repository.entries.single.amount, 2500000);
      expect(find.text('Upcoming'), findsOneWidget);
      await tapVisible(tester, find.text('Pause'));
      expect(repository.data.schedules.single.enabled, isFalse);
      expect(find.text('Paused'), findsOneWidget);
      await tapVisible(tester, find.text('Resume'));
      expect(repository.data.schedules.single.enabled, isTrue);
      await tapVisible(tester, find.byTooltip('Edit schedule'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Updated rent',
      );
      await tapVisible(tester, find.text('Save schedule'));
      expect(repository.data.schedules.single.title, 'Updated rent');
      expect(repository.entries.single.title, 'Apartment rent');
      await tapVisible(tester, find.byTooltip('Delete schedule'));
      await tester.tap(find.widgetWithText(FilledButton, 'Delete schedule'));
      await tester.pumpAndSettle();
      expect(repository.data.schedules, isEmpty);
      expect(repository.entries.length, 1);
    },
  );

  testWidgets(
    'overview reminder opens due schedules and skip never records money',
    (tester) async {
      final repository = MemoryWallet()..data = WalletData(schedules: [rent()]);
      await tester.pumpWidget(PocketApp(repository: repository));
      await tester.pumpAndSettle();
      expect(
        find.text('1 recurring transaction needs your review'),
        findsOneWidget,
      );
      await tapVisible(tester, find.text('Review due transactions'));
      await tapVisible(tester, find.text('Skip occurrence'));
      await tester.tap(find.text('Confirm skip'));
      await tester.pumpAndSettle();
      expect(repository.entries, isEmpty);
      expect(repository.data.schedules.single.isDue(DateTime.now()), isFalse);
      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();
      expect(
        find.text('1 recurring transaction needs your review'),
        findsNothing,
      );
    },
  );

  testWidgets('invalid schedule stays open, and a failed save can be retried', (
    tester,
  ) async {
    final repository = MemoryWallet();
    await tester.pumpWidget(PocketApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recurring'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add schedule'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Save schedule'));
    expect(repository.data.schedules, isEmpty);
    expect(find.text('Give this transaction a title'), findsOneWidget);
    await tapVisible(tester, find.widgetWithText(TextFormField, 'Title'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Rent');
    await tester.ensureVisible(
      find.widgetWithText(TextFormField, 'Amount (IDR)'),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount (IDR)'),
      '1000000',
    );
    repository.failSaves = true;
    await tapVisible(tester, find.text('Save schedule'));
    expect(find.text('New schedule'), findsOneWidget);
    expect(
      find.text('Could not save this change. Please try again.'),
      findsWidgets,
    );
    expect(repository.data.schedules, isEmpty);
    repository.failSaves = false;
    await tapVisible(tester, find.text('Save schedule'));
    expect(repository.data.schedules.single.title, 'Rent');
  });

  testWidgets(
    'recurring page fits a small phone and keeps paused reminders quiet',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = MemoryWallet()
        ..data = WalletData(schedules: [rent(enabled: false)]);
      await tester.pumpWidget(PocketApp(repository: repository));
      await tester.pumpAndSettle();
      expect(
        find.text('1 recurring transaction needs your review'),
        findsNothing,
      );
      await tester.tap(find.text('Recurring'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Resume'));
      expect(find.text('Due now'), findsOneWidget);
      await tapVisible(tester, find.text('Record occurrence'));
      await tester.tap(find.text('Confirm record'));
      await tester.pumpAndSettle();
      expect(repository.entries.length, 1);
    },
  );
  testWidgets(
    'future schedules can change frequency and type without recording money',
    (tester) async {
      final tomorrow = calendarDate(DateTime.now())
          .add(const Duration(days: 1));
      final repository = MemoryWallet()
        ..data = WalletData(schedules: [rent(due: tomorrow)]);
      await tester.pumpWidget(PocketApp(repository: repository));
      await tester.pumpAndSettle();
      expect(
        find.text('1 recurring transaction needs your review'),
        findsNothing,
      );
      await tester.tap(find.text('Recurring'));
      await tester.pumpAndSettle();
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Record occurrence'), findsNothing);
      await tapVisible(tester, find.byTooltip('Edit schedule'));
      await tapVisible(tester, find.text('Income'));
      await tapVisible(tester, find.text('Monthly'));
      await tester.tap(find.text('Weekly').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byIcon(Icons.calendar_today_outlined));
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Save schedule'));
      expect(repository.data.schedules.single.nextDueDate, tomorrow);
      expect(
        repository.data.schedules.single.frequency,
        RepeatFrequency.weekly,
      );
      expect(repository.data.schedules.single.type, EntryType.income);
      expect(repository.entries, isEmpty);
    },
  );
}
