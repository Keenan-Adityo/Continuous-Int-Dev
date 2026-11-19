import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:continous_int_dev/features/wallet/domain/entities/recurring_transaction.dart';
import 'package:continous_int_dev/features/wallet/domain/entities/wallet_data.dart';
import 'package:continous_int_dev/features/wallet/domain/entities/wallet_entry.dart';
import 'package:continous_int_dev/features/wallet/domain/usecases/manage_recurring_transactions.dart';
import 'package:continous_int_dev/features/wallet/domain/usecases/manage_wallet.dart';
import 'package:continous_int_dev/features/wallet/data/datasources/wallet_file_store.dart';
import 'package:continous_int_dev/features/wallet/data/models/wallet_entry_model.dart';
import 'package:continous_int_dev/features/wallet/data/repositories/local_wallet_repository.dart';
import 'package:continous_int_dev/features/wallet/presentation/bloc/wallet_bloc.dart';

import 'support/memory_wallet.dart';

RecurringTransaction schedule({
  DateTime? date,
  RepeatFrequency frequency = RepeatFrequency.monthly,
  EntryType type = EntryType.expense,
}) {
  final start = date ?? DateTime(2026, 1, 31);
  return RecurringTransaction(
    id: 'rent',
    title: 'Rent',
    amount: 2000000,
    type: type,
    category: Category.bills,
    anchorDate: start,
    nextDueDate: start,
    frequency: frequency,
    note: 'Apartment',
  );
}

void main() {
  test('monthly dates return to the anchor day after a short month', () {
    final january = schedule();
    expect(january.followingDate, DateTime(2026, 2, 28));
    final february = january.copyWith(nextDueDate: january.followingDate);
    expect(february.followingDate, DateTime(2026, 3, 31));
    expect(
      schedule(date: DateTime(2028, 1, 31)).followingDate,
      DateTime(2028, 2, 29),
    );
  });

  test('yearly leap-day schedules regain February 29 in a leap year', () {
    var current = schedule(
      date: DateTime(2024, 2, 29),
      frequency: RepeatFrequency.yearly,
    );
    for (var year = 2025; year <= 2028; year++) {
      final next = current.followingDate;
      expect(next, DateTime(year, 2, year == 2028 ? 29 : 28));
      current = current.copyWith(nextDueDate: next);
    }
  });

  test(
    'daily and weekly schedules advance calendar dates across year boundaries',
    () {
      expect(
        schedule(
          date: DateTime(2026, 12, 31),
          frequency: RepeatFrequency.daily,
        ).followingDate,
        DateTime(2027, 1, 1),
      );
      expect(
        schedule(
          date: DateTime(2026, 12, 31),
          frequency: RepeatFrequency.weekly,
        ).followingDate,
        DateTime(2027, 1, 7),
      );
    },
  );

  test('due checks use calendar dates and ignore paused schedules', () {
    final current = schedule();
    expect(current.isDue(DateTime(2026, 1, 31)), isTrue);
    expect(current.isDue(DateTime(2026, 1, 30, 23, 59)), isFalse);
    expect(current.copyWith(enabled: false).isDue(DateTime(2027)), isFalse);
  });

  test('creating and editing a schedule do not record a transaction', () async {
    final repository = MemoryWallet();
    final recurring = ManageRecurringTransactions(repository);
    final created = await recurring.upsert(WalletData(), schedule());
    final updated = await recurring.upsert(
      created,
      schedule(type: EntryType.income),
    );
    expect(updated.entries, isEmpty);
    expect(updated.schedules.single.type, EntryType.income);
    expect(repository.data, same(updated));
  });

  test('confirm income and expense once, advance dates, and reject stale confirmations', () async {
    for (final type in EntryType.values) {
      final repository = MemoryWallet();
      final recurring = ManageRecurringTransactions(
        repository,
        clock: () => DateTime(2026, 4),
      );
      final initial = WalletData(schedules: [schedule(type: type)]);
      final confirmed = await recurring.resolve(
        initial,
        'rent',
        DateTime(2026, 1, 31),
        record: true,
      );
      expect(confirmed.entries.single.type, type);
      expect(confirmed.entries.single.date, DateTime(2026, 1, 31));
      expect(confirmed.schedules.single.nextDueDate, DateTime(2026, 2, 28));
      expect(
        WalletSummary(confirmed.entries, DateTime(2026, 1)).balance,
        type == EntryType.income ? 2000000 : -2000000,
      );
      await expectLater(
        recurring.resolve(
          confirmed,
          'rent',
          DateTime(2026, 1, 31),
          record: true,
        ),
        throwsA(isA<WalletFailure>()),
      );
      expect(repository.data.entries.length, 1);
    }
  });

  test(
    'skip advances only one missed occurrence without changing the balance',
    () async {
      final recurring = ManageRecurringTransactions(
        MemoryWallet(),
        clock: () => DateTime(2026, 4),
      );
      final skipped = await recurring.resolve(
        WalletData(schedules: [schedule()]),
        'rent',
        DateTime(2026, 1, 31),
        record: false,
      );
      expect(skipped.entries, isEmpty);
      expect(skipped.schedules.single.nextDueDate, DateTime(2026, 2, 28));
      expect(skipped.schedules.single.isDue(DateTime(2026, 4)), isTrue);
    },
  );

  test(
    'future, paused, and already recorded occurrences cannot be recorded',
    () async {
      final repository = MemoryWallet();
      final recurring = ManageRecurringTransactions(
        repository,
        clock: () => DateTime(2026, 1, 30),
      );
      await expectLater(
        recurring.resolve(
          WalletData(schedules: [schedule()]),
          'rent',
          DateTime(2026, 1, 31),
          record: true,
        ),
        throwsA(isA<WalletFailure>()),
      );
      final due = ManageRecurringTransactions(
        repository,
        clock: () => DateTime(2026, 2),
      );
      final paused = WalletData(
        schedules: [schedule().copyWith(enabled: false)],
      );
      await expectLater(
        due.resolve(paused, 'rent', DateTime(2026, 1, 31), record: true),
        throwsA(isA<WalletFailure>()),
      );
      final recorded = await due.resolve(
        WalletData(schedules: [schedule()]),
        'rent',
        DateTime(2026, 1, 31),
        record: true,
      );
      final rewound = recorded.copyWith(schedules: [schedule()]);
      await expectLater(
        due.resolve(rewound, 'rent', DateTime(2026, 1, 31), record: true),
        throwsA(isA<WalletFailure>()),
      );
    },
  );

  test('ordinary edits preserve schedules; deleting a schedule preserves recorded entries', () async {
    final repository = MemoryWallet();
    final recurring = ManageRecurringTransactions(
      repository,
      clock: () => DateTime(2026, 2),
    );
    final recorded = await recurring.resolve(
      WalletData(schedules: [schedule()]),
      'rent',
      DateTime(2026, 1, 31),
      record: true,
    );
    final edited = await ManageWallet(repository).upsert(
      recorded,
      WalletEntry(
        id: 'lunch',
        title: 'Lunch',
        amount: 50000,
        type: EntryType.expense,
        category: Category.food,
        date: DateTime(2026, 1, 1),
      ),
    );
    expect(edited.schedules.single.nextDueDate, DateTime(2026, 2, 28));
    final deleted = await recurring.remove(edited, 'rent');
    expect(deleted.entries.length, 2);
    expect(deleted.schedules, isEmpty);
  });

  test('pause and resume preserve the next unreviewed due date', () async {
    final recurring = ManageRecurringTransactions(MemoryWallet());
    final paused = await recurring.toggle(
      WalletData(schedules: [schedule()]),
      'rent',
    );
    expect(paused.schedules.single.enabled, isFalse);
    final resumed = await recurring.toggle(paused, 'rent');
    expect(resumed.schedules.single.enabled, isTrue);
    expect(resumed.schedules.single.nextDueDate, DateTime(2026, 1, 31));
  });

  test(
    'failed confirmation preserves both entries and the original next due date',
    () async {
      final repository = MemoryWallet()
        ..data = WalletData(schedules: [schedule()])
        ..failSaves = true;
      final bloc = WalletBloc(
        ManageWallet(repository),
        ManageRecurringTransactions(repository, clock: () => DateTime(2026, 2)),
      );
      addTearDown(bloc.close);
      final loaded = bloc.stream.firstWhere(
        (state) => state.status == WalletStatus.ready,
      );
      bloc.add(WalletOpened());
      await loaded;
      final failed = bloc.stream.firstWhere((state) => state.error != null);
      bloc.add(OccurrenceResolved('rent', DateTime(2026, 1, 31), record: true));
      final state = await failed;
      expect(state.entries, isEmpty);
      expect(state.schedules.single.nextDueDate, DateTime(2026, 1, 31));
      expect(repository.data.entries, isEmpty);
    },
  );

  test(
    'queued duplicate confirmations produce exactly one entry after reopening',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'pocket-recurring-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final repository = LocalWalletRepository(
        WalletFileStore(() async => directory),
      );
      await repository.save(WalletData(schedules: [schedule()]));
      final bloc = WalletBloc(
        ManageWallet(repository),
        ManageRecurringTransactions(repository, clock: () => DateTime(2026, 4)),
      );
      addTearDown(bloc.close);
      final loaded = bloc.stream.firstWhere(
        (state) => state.status == WalletStatus.ready,
      );
      bloc.add(WalletOpened());
      await loaded;
      final stale = bloc.stream.firstWhere((state) => state.error != null);
      bloc.add(OccurrenceResolved('rent', DateTime(2026, 1, 31), record: true));
      bloc.add(OccurrenceResolved('rent', DateTime(2026, 1, 31), record: true));
      await stale;
      final reopened = await repository.load();
      expect(reopened.entries.length, 1);
      expect(reopened.schedules.single.nextDueDate, DateTime(2026, 2, 28));
      expect(reopened.schedules.single.note, 'Apartment');
    },
  );

  test(
    'version 1 wallets migrate without losing entries or overwriting on read',
    () async {
      final directory = await Directory.systemTemp.createTemp('pocket-v1-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/pocket_wallet.json');
      final oldEntry = WalletEntry(
        id: 'legacy',
        title: 'Salary',
        amount: 5000000,
        type: EntryType.income,
        category: Category.salary,
        date: DateTime(2026, 1, 1),
      );
      final original = jsonEncode({
        'version': 1,
        'entries': [WalletEntryModel.encode(oldEntry)],
      });
      await file.writeAsString(original);
      final repository = LocalWalletRepository(
        WalletFileStore(() async => directory),
      );
      final loaded = await repository.load();
      expect(loaded.entries.single.id, 'legacy');
      expect(loaded.schedules, isEmpty);
      expect(await file.readAsString(), original);
      await ManageRecurringTransactions(repository).upsert(loaded, schedule());
      final reopened = await repository.load();
      expect(reopened.entries.single.amount, 5000000);
      expect(reopened.schedules.single.frequency, RepeatFrequency.monthly);
      expect(jsonDecode(await file.readAsString())['version'], 2);
    },
  );

  test(
    'malformed schedules fail loading and preserve the source file',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'pocket-bad-schedule-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/pocket_wallet.json');
      const contents =
          '{"version":2,"entries":[],"schedules":[{"frequency":"unknown"}]}';
      await file.writeAsString(contents);
      final repository = LocalWalletRepository(
        WalletFileStore(() async => directory),
      );
      await expectLater(repository.load(), throwsA(isA<WalletFailure>()));
      expect(await file.readAsString(), contents);
    },
  );
}
