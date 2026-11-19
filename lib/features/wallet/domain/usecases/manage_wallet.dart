import '../entities/wallet_data.dart';
import '../entities/wallet_entry.dart';
import '../repositories/wallet_repository.dart';
import 'transaction_validation.dart';

class ManageWallet {
  const ManageWallet(this.repository);
  final WalletRepository repository;
  Future<WalletData> load() => repository.load();

  Future<WalletData> upsert(WalletData data, WalletEntry entry) async {
    validateTransactionDetails(
      id: entry.id,
      title: entry.title,
      amount: entry.amount,
      note: entry.note,
    );
    if (entry.date.isAfter(DateTime.now())) {
      throw const WalletFailure('Choose today or an earlier date.');
    }
    final updated = data.copyWith(
      entries: [...data.entries.where((e) => e.id != entry.id), entry],
    );
    await repository.save(updated);
    return updated;
  }

  Future<WalletData> remove(WalletData data, String id) async {
    final updated = data.copyWith(
      entries: data.entries.where((e) => e.id != id).toList(),
    );
    await repository.save(updated);
    return updated;
  }
}

class WalletSummary {
  WalletSummary(List<WalletEntry> entries, DateTime month) {
    for (final entry in entries) {
      balance += entry.type == EntryType.income ? entry.amount : -entry.amount;
      if (entry.date.year != month.year || entry.date.month != month.month) {
        continue;
      }
      if (entry.type == EntryType.income) {
        income += entry.amount;
      } else {
        expenses += entry.amount;
        categories.update(
          entry.category,
          (value) => value + entry.amount,
          ifAbsent: () => entry.amount,
        );
      }
    }
  }
  int balance = 0;
  int income = 0;
  int expenses = 0;
  final Map<Category, int> categories = {};
}
