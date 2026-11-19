import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/presentation/app_theme.dart';
import '../../../../core/presentation/widgets/section_card.dart';
import '../../domain/entities/recurring_transaction.dart';
import '../../domain/entities/wallet_entry.dart';
import 'wallet_format.dart';

class RecurringReminder extends StatelessWidget {
  const RecurringReminder({
    super.key,
    required this.count,
    required this.onReview,
  });
  final int count;
  final VoidCallback onReview;
  @override
  Widget build(BuildContext context) => SectionCard(
    color: AppColors.mint,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.event_repeat_rounded),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$count recurring ${count == 1 ? 'transaction needs' : 'transactions need'} your review',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Confirm due income or expenses to update your balance.'),
        TextButton(
          onPressed: onReview,
          child: const Text('Review due transactions'),
        ),
      ],
    ),
  );
}

class RecurringPanel extends StatelessWidget {
  const RecurringPanel({
    super.key,
    required this.schedules,
    required this.today,
    required this.busy,
    required this.onEdit,
    required this.onRecord,
    required this.onSkip,
    required this.onToggle,
    required this.onDelete,
  });
  final List<RecurringTransaction> schedules;
  final DateTime today;
  final bool busy;
  final ValueChanged<RecurringTransaction> onEdit;
  final ValueChanged<RecurringTransaction> onRecord;
  final ValueChanged<RecurringTransaction> onSkip;
  final ValueChanged<RecurringTransaction> onToggle;
  final ValueChanged<RecurringTransaction> onDelete;

  @override
  Widget build(BuildContext context) {
    final ordered = [...schedules]
      ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
    final groups = <String, List<RecurringTransaction>>{
      'Due now': ordered.where((s) => s.isDue(today)).toList(),
      'Upcoming': ordered.where((s) => s.enabled && !s.isDue(today)).toList(),
      'Paused': ordered.where((s) => !s.enabled).toList(),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Plan rent, subscriptions, and salary. Confirm each due occurrence before it is recorded. Reminders appear inside Pocket.',
        ),
        const SizedBox(height: 20),
        if (schedules.isEmpty)
          const SectionCard(
            child: Column(
              children: [
                Icon(
                  Icons.event_repeat_rounded,
                  color: AppColors.green,
                  size: 40,
                ),
                SizedBox(height: 12),
                Text(
                  'Make room for the regular things',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                SizedBox(height: 8),
                Text(
                  'Add a schedule for an expense or income you expect again.',
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
            for (final schedule in group.value)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _ScheduleCard(
                  schedule: schedule,
                  today: today,
                  busy: busy,
                  onEdit: () => onEdit(schedule),
                  onRecord: () => onRecord(schedule),
                  onSkip: () => onSkip(schedule),
                  onToggle: () => onToggle(schedule),
                  onDelete: () => onDelete(schedule),
                ),
              ),
          ],
        const SizedBox(height: 8),
        const Text(
          'Missed more than one occurrence? Review or skip each one in order. Pausing keeps the next due date; resuming may show it as overdue.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.schedule,
    required this.today,
    required this.busy,
    required this.onEdit,
    required this.onRecord,
    required this.onSkip,
    required this.onToggle,
    required this.onDelete,
  });
  final RecurringTransaction schedule;
  final DateTime today;
  final bool busy;
  final VoidCallback onEdit, onRecord, onSkip, onToggle, onDelete;

  @override
  Widget build(BuildContext context) {
    final due = schedule.isDue(today);
    final overdue = due && schedule.nextDueDate.isBefore(calendarDate(today));
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  schedule.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Edit schedule',
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
              IconButton(
                tooltip: 'Delete schedule',
                onPressed: busy ? null : onDelete,
                icon: const Icon(Icons.delete_outline, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${schedule.type == EntryType.income ? '+' : '−'}${money(schedule.amount)}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${schedule.frequency.label} · ${schedule.category.label} · ${schedule.type == EntryType.income ? 'Income' : 'Expense'}',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          Text(
            '${!schedule.enabled
                ? 'Paused · Next'
                : overdue
                ? 'Overdue'
                : 'Due'} ${DateFormat('d MMM yyyy').format(schedule.nextDueDate)}',
            style: TextStyle(
              color: overdue ? AppColors.expense : AppColors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (schedule.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(schedule.note),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (due) ...[
                FilledButton(
                  onPressed: busy ? null : onRecord,
                  child: const Text('Record occurrence'),
                ),
                TextButton(
                  onPressed: busy ? null : onSkip,
                  child: const Text('Skip occurrence'),
                ),
              ],
              TextButton.icon(
                onPressed: busy ? null : onToggle,
                icon: Icon(
                  schedule.enabled
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  size: 18,
                ),
                label: Text(schedule.enabled ? 'Pause' : 'Resume'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
