import 'recurring_transaction.dart';
import 'wallet_entry.dart';

class GoalContribution {
  const GoalContribution({
    required this.id,
    required this.amount,
    required this.date,
  });
  final String id;
  final int amount;
  final DateTime date;
}

class SavingsGoal {
  SavingsGoal({
    required this.id,
    required this.title,
    required this.targetAmount,
    this.targetDate,
    List<GoalContribution> contributions = const [],
  }) : contributions = List.unmodifiable(contributions);
  final String id;
  final String title;
  final int targetAmount;
  final DateTime? targetDate;
  final List<GoalContribution> contributions;

  int get savedAmount =>
      contributions.fold(0, (sum, contribution) => sum + contribution.amount);
  int get remainingAmount => targetAmount - savedAmount;
  bool get isComplete => savedAmount >= targetAmount;
  bool isOverdue(DateTime now) =>
      !isComplete &&
      targetDate != null &&
      targetDate!.isBefore(calendarDate(now));
  double get progress => targetAmount > 0 ? savedAmount / targetAmount : 0;

  SavingsGoal withContributions(List<GoalContribution> contributions) =>
      SavingsGoal(
        id: id,
        title: title,
        targetAmount: targetAmount,
        targetDate: targetDate,
        contributions: contributions,
      );

  void validate() {
    if (id.isEmpty || title.trim().isEmpty || title.length > 80) {
      throw const WalletFailure('Enter a goal name of 1–80 characters.');
    }
    if (targetAmount <= 0 || targetAmount > 999999999999) {
      throw const WalletFailure(
        'Enter a target from Rp 1 to Rp 999,999,999,999.',
      );
    }
    if (targetDate != null && targetDate != calendarDate(targetDate!)) {
      throw const WalletFailure('Choose a valid target date.');
    }
    if (contributions.map((c) => c.id).toSet().length != contributions.length ||
        contributions.any(
          (c) => c.id.isEmpty || c.amount <= 0 || c.amount > 999999999999,
        )) {
      throw const WalletFailure('Invalid savings contributions.');
    }
    if (savedAmount > targetAmount) {
      throw const WalletFailure(
        'The target cannot be less than the amount already saved.',
      );
    }
  }
}
