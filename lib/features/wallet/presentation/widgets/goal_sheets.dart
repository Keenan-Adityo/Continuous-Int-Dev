import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/presentation/widgets/money_input_field.dart';
import '../../domain/entities/recurring_transaction.dart';
import '../../domain/entities/savings_goal.dart';
import '../bloc/wallet_bloc.dart';
import 'wallet_action_sheet.dart';
import 'wallet_format.dart';

class GoalEditorSheet extends StatefulWidget {
  const GoalEditorSheet({super.key, this.goal});
  final SavingsGoal? goal;
  @override
  State<GoalEditorSheet> createState() => _GoalEditorSheetState();
}

class _GoalEditorSheetState extends State<GoalEditorSheet> {
  final _form = GlobalKey<FormState>();
  late final String _id;
  late final TextEditingController _title;
  late final TextEditingController _target;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    _id = widget.goal?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    _title = TextEditingController(text: widget.goal?.title);
    _target = TextEditingController(text: widget.goal?.targetAmount.toString());
    _date = widget.goal?.targetDate;
  }

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = calendarDate(DateTime.now());
    final initial = _date ?? today;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: initial.isBefore(today) ? initial : today,
      lastDate: DateTime(today.year + 50, 12, 31),
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  @override
  Widget build(BuildContext context) => WalletActionSheet(
    title: widget.goal == null ? 'New savings goal' : 'Edit savings goal',
    submitLabel: 'Save goal',
    eventBuilder: () {
      if (!_form.currentState!.validate()) return null;
      return GoalSaved(
        id: _id,
        title: _title.text.trim(),
        targetAmount: int.parse(_target.text),
        targetDate: _date,
      );
    },
    contentBuilder: (context, busy) => Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _title,
            enabled: !busy,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Goal name',
              hintText: 'e.g. Emergency fund',
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Give your goal a name'
                : null,
          ),
          const SizedBox(height: 12),
          MoneyInputField(
            controller: _target,
            enabled: !busy,
            label: 'Target amount (IDR)',
          ),
          if (widget.goal != null) ...[
            const SizedBox(height: 10),
            Text(
              'Already saved: ${money(widget.goal!.savedAmount)}. Contributions will be kept.',
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: busy ? null : _pickDate,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(
              _date == null
                  ? 'Set target date (optional)'
                  : 'Target: ${DateFormat('d MMM yyyy').format(_date!)}',
            ),
          ),
          if (_date != null)
            TextButton(
              onPressed: busy ? null : () => setState(() => _date = null),
              child: const Text('Remove target date'),
            ),
          const SizedBox(height: 12),
          const Text(
            'Track money you set aside for this goal. Contributions do not change your wallet balance.',
          ),
        ],
      ),
    ),
  );
}

class GoalContributionSheet extends StatefulWidget {
  const GoalContributionSheet({super.key, required this.goal});
  final SavingsGoal goal;
  @override
  State<GoalContributionSheet> createState() => _GoalContributionSheetState();
}

class _GoalContributionSheetState extends State<GoalContributionSheet> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _id = DateTime.now().microsecondsSinceEpoch.toString();
  DateTime _date = calendarDate(DateTime.now());

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  @override
  Widget build(BuildContext context) => WalletActionSheet(
    title: 'Add contribution',
    submitLabel: 'Save contribution',
    eventBuilder: () {
      if (!_form.currentState!.validate()) return null;
      return GoalContributionAdded(
        widget.goal.id,
        GoalContribution(id: _id, amount: int.parse(_amount.text), date: _date),
      );
    },
    contentBuilder: (context, busy) => Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.goal.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            '${money(widget.goal.remainingAmount)} left to reach your goal.',
          ),
          const SizedBox(height: 20),
          MoneyInputField(
            controller: _amount,
            enabled: !busy,
            maxAmount: widget.goal.remainingAmount,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: busy ? null : _pickDate,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(DateFormat('d MMM yyyy').format(_date)),
          ),
          const SizedBox(height: 12),
          const Text(
            'Record savings you have already set aside. Your wallet balance stays the same.',
          ),
        ],
      ),
    ),
  );
}
