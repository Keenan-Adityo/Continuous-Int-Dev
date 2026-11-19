import 'package:continous_int_dev/features/wallet/domain/entities/wallet_data.dart';
import 'package:continous_int_dev/features/wallet/domain/entities/wallet_entry.dart';
import 'package:continous_int_dev/features/wallet/domain/repositories/wallet_repository.dart';

class MemoryWallet implements WalletRepository {
  WalletData data = WalletData();
  bool failSaves = false;
  List<WalletEntry> get entries => data.entries;
  set entries(List<WalletEntry> value) => data = data.copyWith(entries: value);
  @override
  Future<WalletData> load() async => data;
  @override
  Future<void> save(WalletData data) async {
    if (failSaves) {
      throw const WalletFailure(
        'Could not save this change. Please try again.',
      );
    }
    this.data = data;
  }
}
