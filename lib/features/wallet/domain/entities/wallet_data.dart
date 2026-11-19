import 'recurring_transaction.dart';
import 'wallet_entry.dart';

/// Transactions and schedules are persisted together as one atomic snapshot.
class WalletData {
  WalletData({
    List<WalletEntry> entries = const [],
    List<RecurringTransaction> schedules = const [],
  }) : entries = List.unmodifiable(entries),
       schedules = List.unmodifiable(schedules);
  final List<WalletEntry> entries;
  final List<RecurringTransaction> schedules;

  WalletData copyWith({
    List<WalletEntry>? entries,
    List<RecurringTransaction>? schedules,
  }) => WalletData(
    entries: entries ?? this.entries,
    schedules: schedules ?? this.schedules,
  );
}
