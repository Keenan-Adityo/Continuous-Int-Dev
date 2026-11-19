import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:continous_int_dev/features/wallet/domain/entities/recurring_transaction.dart';
import 'package:continous_int_dev/features/wallet/domain/entities/savings_goal.dart';
import 'package:continous_int_dev/features/wallet/domain/entities/wallet_data.dart';
import 'package:continous_int_dev/features/wallet/domain/entities/wallet_entry.dart';
import 'package:continous_int_dev/features/wallet/domain/usecases/manage_savings_goals.dart';
import 'package:continous_int_dev/features/wallet/domain/usecases/manage_recurring_transactions.dart';
import 'package:continous_int_dev/features/wallet/domain/usecases/manage_wallet.dart';
import 'package:continous_int_dev/features/wallet/data/datasources/wallet_file_store.dart';
import 'package:continous_int_dev/features/wallet/data/models/recurring_transaction_model.dart';
import 'package:continous_int_dev/features/wallet/data/models/savings_goal_model.dart';
import 'package:continous_int_dev/features/wallet/data/models/wallet_entry_model.dart';
import 'package:continous_int_dev/features/wallet/data/repositories/local_wallet_repository.dart';
import 'package:continous_int_dev/features/wallet/presentation/bloc/wallet_bloc.dart';

import 'support/memory_wallet.dart';

GoalContribution deposit(String id, int amount) =>
    GoalContribution(id: id, amount: amount, date: DateTime(2026, 1, 1));
SavingsGoal goal({List<GoalContribution> contributions = const []}) =>
    SavingsGoal(
      id: 'goal',
      title: 'Emergency fund',
      targetAmount: 1000000,
      targetDate: DateTime(2026, 12, 31),
      contributions: contributions,
    );
WalletEntry salary() => WalletEntry(
  id: 'salary',
  title: 'Salary',
  amount: 5000000,
  type: EntryType.income,
  category: Category.salary,
  date: DateTime(2026, 1, 1),
);
RecurringTransaction rent() => RecurringTransaction(
  id: 'rent',
  title: 'Rent',
  amount: 500000,
  type: EntryType.expense,
  category: Category.bills,
  anchorDate: DateTime(2026, 1, 1),
  nextDueDate: DateTime(2026, 1, 1),
  frequency: RepeatFrequency.monthly,
);

void main() {
  test(
    'progress, completion, and overdue status reflect tracked contributions',
    () {
      final partial = goal(contributions: [deposit('1', 250000)]);
      expect(partial.savedAmount, 250000);
      expect(partial.remainingAmount, 750000);
      expect(partial.progress, 0.25);
      expect(partial.isComplete, isFalse);
      expect(partial.isOverdue(DateTime(2026, 12, 31, 23)), isFalse);
      expect(partial.isOverdue(DateTime(2027)), isTrue);
      final complete = goal(contributions: [deposit('1', 1000000)]);
      expect(complete.isComplete, isTrue);
      expect(complete.isOverdue(DateTime(2027)), isFalse);
    },
  );

  test(
    'goal edits preserve contributions, transactions, and recurring schedules',
    () async {
      final repository = MemoryWallet();
      final savings = ManageSavingsGoals(repository);
      final before = WalletData(
        entries: [salary()],
        schedules: [rent()],
        goals: [
          goal(contributions: [deposit('1', 250000)]),
        ],
      );
      final edited = await savings.upsert(
        before,
        id: 'goal',
        title: ' Holiday ',
        targetAmount: 2000000,
      );
      expect(edited.goals.single.title, 'Holiday');
      expect(edited.goals.single.savedAmount, 250000);
      expect(edited.goals.single.targetDate, isNull);
      expect(edited.entries.single.id, 'salary');
      expect(edited.schedules.single.id, 'rent');
      expect(WalletSummary(edited.entries, DateTime(2026, 1)).balance, 5000000);
    },
  );

  test(
    'empty names, invalid targets, and reducing below savings are rejected',
    () async {
      final savings = ManageSavingsGoals(MemoryWallet());
      for (final target in [0, -1, 1000000000000]) {
        await expectLater(
          savings.upsert(
            WalletData(),
            id: 'goal',
            title: 'Goal',
            targetAmount: target,
          ),
          throwsA(isA<WalletFailure>()),
        );
      }
      await expectLater(
        savings.upsert(WalletData(), id: 'goal', title: ' ', targetAmount: 100),
        throwsA(isA<WalletFailure>()),
      );
      await expectLater(
        savings.upsert(
          WalletData(
            goals: [
              goal(contributions: [deposit('1', 100)]),
            ],
          ),
          id: 'goal',
          title: 'Goal',
          targetAmount: 99,
        ),
        throwsA(isA<WalletFailure>()),
      );
    },
  );

  test(
    'contributions do not affect wallet balances and can complete a goal',
    () async {
      final savings = ManageSavingsGoals(MemoryWallet());
      final before = WalletData(entries: [salary()], goals: [goal()]);
      final updated = await savings.contribute(
        before,
        'goal',
        deposit('1', 1000000),
      );
      expect(updated.goals.single.isComplete, isTrue);
      expect(updated.entries.single, same(before.entries.single));
      expect(
        WalletSummary(updated.entries, DateTime(2026, 1)).balance,
        5000000,
      );
      await expectLater(
        savings.contribute(updated, 'goal', deposit('2', 1)),
        throwsA(isA<WalletFailure>()),
      );
    },
  );

  test('zero, negative, over-target, future and repeated contributions are rejected', () async {
    final savings = ManageSavingsGoals(
      MemoryWallet(),
      clock: () => DateTime(2026, 1, 2),
    );
    final data = WalletData(goals: [goal()]);
    for (final amount in [0, -1, 1000001]) {
      await expectLater(
        savings.contribute(data, 'goal', deposit('1', amount)),
        throwsA(isA<WalletFailure>()),
      );
    }
    await expectLater(
      savings.contribute(
        data,
        'goal',
        GoalContribution(id: 'future', amount: 100, date: DateTime(2026, 1, 3)),
      ),
      throwsA(isA<WalletFailure>()),
    );
    final updated = await savings.contribute(data, 'goal', deposit('1', 100));
    await expectLater(
      savings.contribute(updated, 'goal', deposit('1', 100)),
      throwsA(isA<WalletFailure>()),
    );
    expect(updated.goals.single.savedAmount, 100);
  });

  test('undoing a contribution reopens a completed goal without changing transactions', () async {
    final savings = ManageSavingsGoals(MemoryWallet());
    final before = WalletData(
      entries: [salary()],
      goals: [
        goal(contributions: [deposit('1', 1000000)]),
      ],
    );
    final updated = await savings.removeContribution(before, 'goal', '1');
    expect(updated.goals.single.savedAmount, 0);
    expect(updated.goals.single.isComplete, isFalse);
    expect(updated.entries.length, 1);
    await expectLater(
      savings.removeContribution(updated, 'goal', '1'),
      throwsA(isA<WalletFailure>()),
    );
  });

  test('deleting a goal removes only its tracked savings', () async {
    final savings = ManageSavingsGoals(MemoryWallet());
    final before = WalletData(
      entries: [salary()],
      schedules: [rent()],
      goals: [
        goal(contributions: [deposit('1', 100)]),
      ],
    );
    final removed = await savings.remove(before, 'goal');
    expect(removed.goals, isEmpty);
    expect(removed.entries.single.id, 'salary');
    expect(removed.schedules.single.id, 'rent');
    await expectLater(
      savings.contribute(removed, 'goal', deposit('2', 100)),
      throwsA(isA<WalletFailure>()),
    );
  });

  test(
    'transaction and recurring writes preserve existing goal contributions',
    () async {
      final repository = MemoryWallet();
      final before = WalletData(
        goals: [
          goal(contributions: [deposit('1', 250000)]),
        ],
        schedules: [rent()],
      );
      final withSalary = await ManageWallet(repository)
          .upsert(before, salary());
      final withRent = await ManageRecurringTransactions(repository)
          .resolve(withSalary, 'rent', DateTime(2026, 1, 1), record: true);
      expect(withRent.goals.single.savedAmount, 250000);
      expect(withRent.entries.length, 2);
    },
  );

  test('goals and contribution dates survive reopening', () async {
    final directory = await Directory.systemTemp.createTemp('pocket-goals-');
    addTearDown(() => directory.delete(recursive: true));
    final repository = LocalWalletRepository(
      WalletFileStore(() async => directory),
    );
    await repository.save(
      WalletData(
        entries: [salary()],
        schedules: [rent()],
        goals: [
          goal(contributions: [deposit('1', 250000)]),
        ],
      ),
    );
    final reopened = await repository.load();
    expect(reopened.goals.single.savedAmount, 250000);
    expect(reopened.goals.single.targetDate, DateTime(2026, 12, 31));
    expect(
      reopened.goals.single.contributions.single.date,
      DateTime(2026, 1, 1),
    );
    expect(reopened.schedules.single.id, 'rent');
    expect(reopened.entries.single.id, 'salary');
  });

  test('version 1 and 2 files migrate without changing existing transactions or schedules', () async {
    for (final version in [1, 2]) {
      final directory = await Directory.systemTemp.createTemp(
        'pocket-goals-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/pocket_wallet.json');
      final original = jsonEncode({
        'version': version,
        'entries': [WalletEntryModel.encode(salary())],
        if (version == 2)
          'schedules': [RecurringTransactionModel.encode(rent())],
      });
      await file.writeAsString(original);
      final repository = LocalWalletRepository(
        WalletFileStore(() async => directory),
      );
      final loaded = await repository.load();
      expect(loaded.goals, isEmpty);
      expect(await file.readAsString(), original);
      await ManageSavingsGoals(repository)
          .upsert(loaded, id: 'goal', title: 'Holiday', targetAmount: 1000000);
      final migrated = await repository.load();
      expect(migrated.entries.single.id, 'salary');
      expect(migrated.schedules.length, version == 2 ? 1 : 0);
      expect(migrated.goals.single.title, 'Holiday');
      expect(jsonDecode(await file.readAsString())['version'], 3);
    }
  });

  test('corrupt goal data cannot overwrite the existing file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pocket-invalid-goals-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/pocket_wallet.json');
    final invalid = SavingsGoalModel.encode(
      goal(
        contributions: [deposit('duplicate', 100), deposit('duplicate', 100)],
      ),
    );
    final original = jsonEncode({
      'version': 3,
      'entries': [],
      'schedules': [],
      'goals': [invalid],
    });
    await file.writeAsString(original);
    final repository = LocalWalletRepository(
      WalletFileStore(() async => directory),
    );
    await expectLater(repository.load(), throwsA(isA<WalletFailure>()));
    expect(await file.readAsString(), original);
  });

  test(
    'failed contribution writes leave progress and persisted data unchanged',
    () async {
      final repository = MemoryWallet()
        ..data = WalletData(goals: [goal()])
        ..failSaves = true;
      final bloc = WalletBloc(
        ManageWallet(repository),
        ManageRecurringTransactions(repository),
        ManageSavingsGoals(repository),
      );
      addTearDown(bloc.close);
      final loaded = bloc.stream.firstWhere(
        (s) => s.status == WalletStatus.ready,
      );
      bloc.add(WalletOpened());
      await loaded;
      final failed = bloc.stream.firstWhere((s) => s.error != null);
      bloc.add(GoalContributionAdded('goal', deposit('1', 100)));
      final state = await failed;
      expect(state.goals.single.savedAmount, 0);
      expect(state.revision, 1);
      expect(repository.data.goals.single.savedAmount, 0);
    },
  );

  test(
    'queued duplicates and edits preserve a contribution exactly once',
    () async {
      final repository = MemoryWallet()..data = WalletData(goals: [goal()]);
      final bloc = WalletBloc(
        ManageWallet(repository),
        ManageRecurringTransactions(repository),
        ManageSavingsGoals(repository),
      );
      addTearDown(bloc.close);
      final loaded = bloc.stream.firstWhere(
        (s) => s.status == WalletStatus.ready,
      );
      bloc.add(WalletOpened());
      await loaded;
      final edited = bloc.stream.firstWhere(
        (s) => s.revision == 3 && s.status == WalletStatus.ready,
      );
      bloc.add(GoalContributionAdded('goal', deposit('1', 250000)));
      bloc.add(GoalContributionAdded('goal', deposit('1', 250000)));
      bloc.add(GoalSaved(id: 'goal', title: 'Holiday', targetAmount: 1500000));
      final state = await edited;
      expect(state.goals.single.contributions.length, 1);
      expect(state.goals.single.savedAmount, 250000);
      expect(state.goals.single.title, 'Holiday');
    },
  );
}
