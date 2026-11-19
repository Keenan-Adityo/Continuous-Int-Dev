import 'dart:convert';

import '../../domain/entities/wallet_data.dart';
import '../../domain/entities/wallet_entry.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../datasources/wallet_file_store.dart';
import '../models/recurring_transaction_model.dart';
import '../models/wallet_entry_model.dart';
import '../models/savings_goal_model.dart';

class LocalWalletRepository implements WalletRepository {
  const LocalWalletRepository(this.store);
  final WalletFileStore store;

  @override
  Future<WalletData> load() async {
    try {
      final contents = await store.read();
      if (contents == null) return WalletData();
      final json = jsonDecode(contents) as Map<String, dynamic>;
      if (![1, 2, 3].contains(json['version'])) {
        throw const FormatException('Unsupported version');
      }
      final entries = (json['entries'] as List)
          .map((e) => WalletEntryModel.decode(e as Map<String, dynamic>))
          .toList();
      final data = WalletData(
        entries: entries,
        goals: json['version'] == 3
            ? (json['goals'] as List)
                  .map(
                    (g) => SavingsGoalModel.decode(g as Map<String, dynamic>),
                  )
                  .toList()
            : [],
        schedules: json['version'] == 1
            ? []
            : (json['schedules'] as List)
                  .map(
                    (s) => RecurringTransactionModel.decode(
                      s as Map<String, dynamic>,
                    ),
                  )
                  .toList(),
      );
      if (entries.map((e) => e.id).toSet().length != entries.length ||
          data.schedules.map((s) => s.id).toSet().length !=
              data.schedules.length ||
          data.goals.map((g) => g.id).toSet().length != data.goals.length) {
        throw const FormatException('Duplicate records');
      }
      return data;
    } catch (_) {
      throw const WalletFailure(
        'Your wallet could not be opened. Your saved data has been kept. Please try again.',
      );
    }
  }

  @override
  Future<void> save(WalletData data) async {
    try {
      await store.write(
        jsonEncode({
          'version': 3,
          'goals': data.goals.map(SavingsGoalModel.encode).toList(),
          'entries': data.entries.map(WalletEntryModel.encode).toList(),
          'schedules': data.schedules
              .map(RecurringTransactionModel.encode)
              .toList(),
        }),
      );
    } catch (_) {
      throw const WalletFailure(
        'Could not save this change. Please try again.',
      );
    }
  }
}
