import 'recurring_transaction.dart';
import 'wallet_entry.dart';
import 'savings_goal.dart';

/// Transactions, schedules, and savings goals share one atomic snapshot.
class WalletData {
  WalletData({
    List<WalletEntry> entries = const [],
    List<RecurringTransaction> schedules = const [],
    List<SavingsGoal> goals = const [],
  }) : entries = List.unmodifiable(entries),
       schedules = List.unmodifiable(schedules),
       goals = List.unmodifiable(goals);
  final List<WalletEntry> entries;
  final List<RecurringTransaction> schedules;
  final List<SavingsGoal> goals;

  WalletData copyWith({
    List<WalletEntry>? entries,
    List<RecurringTransaction>? schedules,
    List<SavingsGoal>? goals,
  }) => WalletData(
    entries: entries ?? this.entries,
    schedules: schedules ?? this.schedules,
    goals: goals ?? this.goals,
  );
}
