import '../entities/savings_goal.dart';
import '../entities/wallet_data.dart';
import '../entities/wallet_entry.dart';
import '../repositories/wallet_repository.dart';

class ManageSavingsGoals {
  ManageSavingsGoals(this.repository, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final WalletRepository repository;
  final DateTime Function() clock;

  Future<WalletData> upsert(
    WalletData data, {
    required String id,
    required String title,
    required int targetAmount,
    DateTime? targetDate,
  }) async {
    final existing = data.goals.where((goal) => goal.id == id).firstOrNull;
    // Always preserve the current contributions, including edits queued after a deposit.
    final goal = SavingsGoal(
      id: id,
      title: title.trim(),
      targetAmount: targetAmount,
      targetDate: targetDate,
      contributions: existing?.contributions ?? [],
    );
    goal.validate();
    return _save(
      data.copyWith(goals: [...data.goals.where((g) => g.id != id), goal]),
    );
  }

  Future<WalletData> remove(WalletData data, String id) async {
    _find(data, id);
    return _save(
      data.copyWith(goals: data.goals.where((g) => g.id != id).toList()),
    );
  }

  Future<WalletData> contribute(
    WalletData data,
    String goalId,
    GoalContribution contribution,
  ) async {
    final goal = _find(data, goalId);
    if (contribution.date.isAfter(clock())) {
      throw const WalletFailure(
        'Choose today or an earlier contribution date.',
      );
    }
    if (goal.contributions.any((c) => c.id == contribution.id)) {
      throw const WalletFailure('This contribution has already been recorded.');
    }
    if (contribution.amount > goal.remainingAmount) {
      throw const WalletFailure(
        'The contribution cannot exceed the amount left to reach this goal.',
      );
    }
    final updated = goal.withContributions([
      ...goal.contributions,
      contribution,
    ]);
    updated.validate();
    return _replace(data, updated);
  }

  Future<WalletData> removeContribution(
    WalletData data,
    String goalId,
    String contributionId,
  ) async {
    final goal = _find(data, goalId);
    if (!goal.contributions.any((c) => c.id == contributionId)) {
      throw const WalletFailure('Contribution no longer exists.');
    }
    return _replace(
      data,
      goal.withContributions(
        goal.contributions.where((c) => c.id != contributionId).toList(),
      ),
    );
  }

  SavingsGoal _find(WalletData data, String id) => data.goals.firstWhere(
    (goal) => goal.id == id,
    orElse: () => throw const WalletFailure('Goal no longer exists.'),
  );

  Future<WalletData> _replace(WalletData data, SavingsGoal goal) => _save(
    data.copyWith(
      goals: data.goals.map((g) => g.id == goal.id ? goal : g).toList(),
    ),
  );

  Future<WalletData> _save(WalletData data) async {
    await repository.save(data);
    return data;
  }
}
