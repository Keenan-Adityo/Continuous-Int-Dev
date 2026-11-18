import '../entities/wallet_entry.dart';

abstract interface class WalletRepository {
  Future<List<WalletEntry>> load();
  Future<void> save(List<WalletEntry> entries);
}
