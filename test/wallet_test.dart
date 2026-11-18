import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:continous_int_dev/features/wallet/data/datasources/wallet_file_store.dart';
import 'package:continous_int_dev/features/wallet/data/repositories/local_wallet_repository.dart';
import 'package:continous_int_dev/features/wallet/domain/entities/wallet_entry.dart';
import 'package:continous_int_dev/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:continous_int_dev/features/wallet/domain/usecases/manage_wallet.dart';
import 'package:continous_int_dev/features/wallet/presentation/bloc/wallet_bloc.dart';

WalletEntry entry(
  String id,
  int amount, {
  EntryType type = EntryType.expense,
  DateTime? date,
}) => WalletEntry(
  id: id,
  title: 'Lunch',
  amount: amount,
  type: type,
  category: Category.food,
  date: date ?? DateTime(2026, 1, 4),
);

class FailingWallet implements WalletRepository {
  @override
  Future<List<WalletEntry>> load() async => [entry('existing', 100)];
  @override
  Future<void> save(List<WalletEntry> entries) async =>
      throw const WalletFailure('Save failed');
}

void main() {
  test('summary uses all-time balance and selected-month totals', () {
    final summary = WalletSummary([
      entry('1', 1000, type: EntryType.income, date: DateTime(2025, 12, 1)),
      entry('2', 250),
      entry('3', 100),
      entry('4', 200, type: EntryType.income),
    ], DateTime(2026, 1));
    expect(summary.balance, 850);
    expect(summary.income, 200);
    expect(summary.expenses, 350);
    expect(summary.categories[Category.food], 350);
  });

  test('file repository survives reopening, edits, and deletions', () async {
    final directory = await Directory.systemTemp.createTemp('pocket-test-');
    addTearDown(() => directory.delete(recursive: true));
    LocalWalletRepository repository() =>
        LocalWalletRepository(WalletFileStore(() async => directory));
    final wallet = ManageWallet(repository());
    expect(await wallet.load(), isEmpty);
    final first = await wallet.upsert([], entry('1', 500));
    await wallet.upsert(first, entry('1', 750));
    final loaded = await repository().load();
    expect(loaded.single.amount, 750);
    await wallet.remove(loaded, '1');
    expect(await repository().load(), isEmpty);
  });

  test(
    'corrupted storage fails without overwriting the original data',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'pocket-corrupt-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/pocket_wallet.json');
      await file.writeAsString('damaged data');
      final repository = LocalWalletRepository(
        WalletFileStore(() async => directory),
      );
      await expectLater(repository.load(), throwsA(isA<WalletFailure>()));
      expect(await file.readAsString(), 'damaged data');
    },
  );

  test('invalid amounts are rejected before persistence', () async {
    final wallet = ManageWallet(FailingWallet());
    await expectLater(
      wallet.upsert([], entry('1', 0)),
      throwsA(isA<WalletFailure>()),
    );
    await expectLater(
      wallet.upsert([], entry('1', -1)),
      throwsA(isA<WalletFailure>()),
    );
  });

  test('bloc retains entries and reports failed writes', () async {
    final bloc = WalletBloc(ManageWallet(FailingWallet()));
    final loaded = bloc.stream.firstWhere(
      (s) => s.status == WalletStatus.ready,
    );
    bloc.add(WalletOpened());
    await loaded;
    final failed = bloc.stream.firstWhere((s) => s.error != null);
    bloc.add(EntrySaved(entry('new', 200)));
    final state = await failed;
    expect(state.entries.single.id, 'existing');
    expect(state.status, WalletStatus.ready);
    expect(state.error, 'Save failed');
    await bloc.close();
  });

  test('queued saves preserve both transactions', () async {
    final directory = await Directory.systemTemp.createTemp('pocket-queue-');
    addTearDown(() => directory.delete(recursive: true));
    final repository = LocalWalletRepository(
      WalletFileStore(() async => directory),
    );
    final bloc = WalletBloc(ManageWallet(repository));
    final loaded = bloc.stream.firstWhere(
      (s) => s.status == WalletStatus.ready,
    );
    bloc.add(WalletOpened());
    await loaded;
    final saved = bloc.stream.firstWhere(
      (s) => s.entries.length == 2 && s.status == WalletStatus.ready,
    );
    bloc.add(EntrySaved(entry('1', 100)));
    bloc.add(EntrySaved(entry('2', 200)));
    await saved;
    expect((await repository.load()).length, 2);
    await bloc.close();
  });
}
