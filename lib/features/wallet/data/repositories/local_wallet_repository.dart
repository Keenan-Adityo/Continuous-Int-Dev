import 'dart:convert';

import '../../domain/entities/wallet_entry.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../datasources/wallet_file_store.dart';
import '../models/wallet_entry_model.dart';

class LocalWalletRepository implements WalletRepository {
  const LocalWalletRepository(this.store);
  final WalletFileStore store;

  @override
  Future<List<WalletEntry>> load() async {
    try {
      final contents = await store.read();
      if (contents == null) return [];
      final json = jsonDecode(contents) as Map<String, dynamic>;
      if (json['version'] != 1) {
        throw const FormatException('Unsupported version');
      }
      final entries = (json['entries'] as List)
          .map((e) => WalletEntryModel.decode(e as Map<String, dynamic>))
          .toList();
      if (entries.map((e) => e.id).toSet().length != entries.length) {
        throw const FormatException('Duplicate entries');
      }
      return entries;
    } catch (_) {
      throw const WalletFailure(
        'Your wallet could not be opened. Your saved data has been kept. Please try again.',
      );
    }
  }

  @override
  Future<void> save(List<WalletEntry> entries) async {
    try {
      await store.write(
        jsonEncode({
          'version': 1,
          'entries': entries.map(WalletEntryModel.encode).toList(),
        }),
      );
    } catch (_) {
      throw const WalletFailure(
        'Could not save this change. Please try again.',
      );
    }
  }
}
