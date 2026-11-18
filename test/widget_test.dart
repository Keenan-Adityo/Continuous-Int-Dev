import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:continous_int_dev/main.dart';
import 'package:continous_int_dev/features/wallet/domain/entities/wallet_entry.dart';
import 'package:continous_int_dev/features/wallet/domain/repositories/wallet_repository.dart';

class MemoryWallet implements WalletRepository {
  List<WalletEntry> entries = [];
  @override
  Future<List<WalletEntry>> load() async => entries;
  @override
  Future<void> save(List<WalletEntry> entries) async => this.entries = entries;
}

void main() {
  testWidgets('add, edit, filter and delete a transaction', (tester) async {
    final repository = MemoryWallet();
    await tester.pumpWidget(PocketApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('A fresh start for your money'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('A fresh start for your money'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Add income'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Add income'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount (IDR)'),
      '5000000',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Monthly salary',
    );
    await tester.ensureVisible(find.text('Save transaction'));
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    expect(repository.entries.single.type, EntryType.income);
    expect(repository.entries.single.amount, 5000000);
    await tester.scrollUntilVisible(
      find.text('Monthly salary'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Monthly salary'), findsOneWidget);
    await tester.tap(find.text('Monthly salary'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount (IDR)'),
      '6000000',
    );
    await tester.ensureVisible(find.text('Save transaction'));
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    expect(repository.entries.single.amount, 6000000);
    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expenses'));
    await tester.pumpAndSettle();
    expect(find.text('Monthly salary'), findsNothing);
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monthly salary'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Delete transaction'));
    await tester.tap(find.text('Delete transaction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repository.entries, isEmpty);
  });

  testWidgets('invalid transaction stays open and is not saved', (
    tester,
  ) async {
    final repository = MemoryWallet();
    await tester.pumpWidget(PocketApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save transaction'));
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Give this transaction a title'), findsOneWidget);
    expect(repository.entries, isEmpty);
  });

  testWidgets('overview and insights fit a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = MemoryWallet()
      ..entries = [
        WalletEntry(
          id: '1',
          title: 'Lunch',
          amount: 45000,
          type: EntryType.expense,
          category: Category.food,
          date: DateTime.now(),
        ),
      ];
    await tester.pumpWidget(PocketApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();
    expect(find.text('Where it went'), findsOneWidget);
  });
}
