import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/presentation/app_theme.dart';
import '../../../../core/presentation/widgets/section_card.dart';
import '../../domain/entities/savings_goal.dart';
import '../bloc/wallet_bloc.dart';
import 'wallet_format.dart';

class GoalsSummary extends StatelessWidget {
  const GoalsSummary({super.key, required this.goals, required this.onView});
  final List<SavingsGoal> goals;
  final VoidCallback onView;
  @override
  Widget build(BuildContext context) => SectionCard(
    color: AppColors.mint,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tracked savings',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            money(goals.fold(0, (sum, goal) => sum + goal.savedAmount)),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${goals.where((goal) => goal.isComplete).length} of ${goals.length} goals achieved',
        ),
        TextButton(onPressed: onView, child: const Text('View savings goals')),
      ],
    ),
  );
}

class GoalProgress extends StatelessWidget {
  const GoalProgress({super.key, required this.goal});
  final SavingsGoal goal;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          '${money(goal.savedAmount)} of ${money(goal.targetAmount)}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      const SizedBox(height: 14),
      LinearProgressIndicator(
        value: goal.progress.clamp(0.0, 1.0),
        minHeight: 9,
        borderRadius: BorderRadius.circular(8),
        color: AppColors.green,
        backgroundColor: AppColors.mint,
        semanticsLabel: '${goal.title} progress',
      ),
      const SizedBox(height: 10),
      Text(
        goal.isComplete
            ? 'Goal achieved!'
            : '${(goal.progress * 100).floor()}% saved · ${money(goal.remainingAmount)} to go',
        style: const TextStyle(
          color: AppColors.green,
          fontWeight: FontWeight.w600,
        ),
      ),
      if (goal.targetDate != null) ...[
        const SizedBox(height: 8),
        Text(
          '${goal.isOverdue(DateTime.now()) ? 'Target date passed' : 'Target date'}: ${DateFormat('d MMM yyyy').format(goal.targetDate!)}',
          style: TextStyle(
            color: goal.isOverdue(DateTime.now())
                ? AppColors.expense
                : AppColors.muted,
          ),
        ),
      ],
    ],
  );
}

class GoalsPanel extends StatelessWidget {
  const GoalsPanel({
    super.key,
    required this.goals,
    required this.busy,
    required this.onEdit,
    required this.onContribute,
    required this.onHistory,
    required this.onDelete,
  });
  final List<SavingsGoal> goals;
  final bool busy;
  final ValueChanged<SavingsGoal> onEdit, onContribute, onHistory, onDelete;
  @override
  Widget build(BuildContext context) {
    final groups = {
      'In progress': goals.where((g) => !g.isComplete).toList(),
      'Achieved': goals.where((g) => g.isComplete).toList(),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Set a target and track the money you set aside. Contributions do not change your wallet balance.',
        ),
        const SizedBox(height: 24),
        if (goals.isEmpty)
          const SectionCard(
            child: Column(
              children: [
                Icon(Icons.flag_outlined, size: 42, color: AppColors.green),
                SizedBox(height: 14),
                Text(
                  'Give your savings a purpose',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Start with an emergency fund, a holiday, or something that matters to you.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        for (final group in groups.entries)
          if (group.value.isNotEmpty) ...[
            Text(
              group.key,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            for (final goal in group.value)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              goal.title,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit goal',
                            onPressed: busy ? null : () => onEdit(goal),
                            icon: const Icon(Icons.edit_outlined, size: 20),
                          ),
                          IconButton(
                            tooltip: 'Delete goal',
                            onPressed: busy ? null : () => onDelete(goal),
                            icon: const Icon(Icons.delete_outline, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      GoalProgress(goal: goal),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (!goal.isComplete)
                            FilledButton.icon(
                              onPressed: busy ? null : () => onContribute(goal),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add contribution'),
                            ),
                          TextButton(
                            onPressed: busy ? null : () => onHistory(goal),
                            child: const Text('Contribution history'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
      ],
    );
  }
}

class GoalHistorySheet extends StatelessWidget {
  const GoalHistorySheet({
    super.key,
    required this.goalId,
    required this.onRemove,
  });
  final String goalId;
  final void Function(SavingsGoal goal, GoalContribution contribution) onRemove;
  @override
  Widget build(BuildContext context) => BlocBuilder<WalletBloc, WalletState>(
    builder: (context, state) {
      final goal = state.goals.where((g) => g.id == goalId).firstOrNull;
      final contributions = [...?goal?.contributions]
        ..sort((a, b) => b.date.compareTo(a.date));
      final busy = state.status != WalletStatus.ready;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Contribution history',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (goal == null)
                  const Text('Goal no longer exists.')
                else ...[
                  Text(
                    goal.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GoalProgress(goal: goal),
                  const SizedBox(height: 20),
                  if (contributions.isEmpty)
                    const Text('No contributions yet.'),
                  for (final contribution in contributions)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  money(contribution.amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  DateFormat('d MMM yyyy')
                                      .format(contribution.date),
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Undo contribution',
                            onPressed: busy
                                ? null
                                : () => onRemove(goal, contribution),
                            icon: const Icon(Icons.undo_rounded),
                          ),
                        ],
                      ),
                    ),
                ],
                if (state.error != null)
                  Text(
                    state.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
