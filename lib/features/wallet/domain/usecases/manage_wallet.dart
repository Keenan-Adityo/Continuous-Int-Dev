import '../entities/wallet_entry.dart';
import '../repositories/wallet_repository.dart';

class ManageWallet {
  const ManageWallet(this.repository);
  final WalletRepository repository;
  Future<List<WalletEntry>> load() => repository.load();

  Future<List<WalletEntry>> upsert(
    List<WalletEntry> entries,
    WalletEntry entry,
  ) async {
    if (entry.title.trim().isEmpty || entry.title.length > 80) {
      throw const WalletFailure('Enter a title of 1–80 characters.');
    }
    if (entry.amount <= 0 || entry.amount > 999999999999) {
      throw const WalletFailure(
        'Enter an amount from Rp 1 to Rp 999,999,999,999.',
      );
    }
    if (entry.date.isAfter(DateTime.now())) {
      throw const WalletFailure('Choose today or an earlier date.');
    }
    final updated = [...entries.where((e) => e.id != entry.id), entry];
    await repository.save(updated);
    return updated;
  }

  Future<List<WalletEntry>> remove(List<WalletEntry> entries, String id) async {
    final updated = entries.where((e) => e.id != id).toList();
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
