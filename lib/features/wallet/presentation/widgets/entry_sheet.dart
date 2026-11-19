import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/presentation/widgets/money_input_field.dart';

import '../../domain/entities/wallet_entry.dart';
import '../../domain/entities/recurring_transaction.dart';
import '../bloc/wallet_bloc.dart';

class EntrySheet extends StatefulWidget {
  const EntrySheet({
    super.key,
    this.entry,
    this.schedule,
    this.isRecurring = false,
    this.initialType = EntryType.expense,
  });
  final WalletEntry? entry;
  final RecurringTransaction? schedule;
  final bool isRecurring;
  final EntryType initialType;
  @override
  State<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<EntrySheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late EntryType _type;
  late Category _category;
  late DateTime _date;
  bool _submitted = false;
  int _submittedRevision = 0;
  String? _saveError;
  late RepeatFrequency _frequency;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    final schedule = widget.schedule;
    _frequency = schedule?.frequency ?? RepeatFrequency.monthly;
    _title = TextEditingController(text: schedule?.title ?? entry?.title);
    _amount = TextEditingController(
      text: (schedule?.amount ?? entry?.amount)?.toString(),
    );
    _note = TextEditingController(text: schedule?.note ?? entry?.note);
    _type = schedule?.type ?? entry?.type ?? widget.initialType;
    _category =
        schedule?.category ??
        entry?.category ??
        (_type == EntryType.income ? Category.salary : Category.food);
    _date =
        schedule?.nextDueDate ??
        entry?.date ??
        (widget.isRecurring ? calendarDate(DateTime.now()) : DateTime.now());
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: widget.isRecurring
          ? DateTime(DateTime.now().year + 20, 12, 31)
          : DateTime.now(),
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    _submittedRevision = context.read<WalletBloc>().state.revision;
    setState(() {
      _submitted = true;
      _saveError = null;
    });
    if (widget.isRecurring) {
      final previous = widget.schedule;
      final date = calendarDate(_date);
      context.read<WalletBloc>().add(
        ScheduleSaved(
          RecurringTransaction(
            id:
                previous?.id ??
                DateTime.now().microsecondsSinceEpoch.toString(),
            title: _title.text.trim(),
            amount: int.parse(_amount.text),
            type: _type,
            category: _category,
            note: _note.text.trim(),
            frequency: _frequency,
            enabled: previous?.enabled ?? true,
            nextDueDate: date,
            anchorDate:
                previous != null &&
                    date == previous.nextDueDate &&
                    _frequency == previous.frequency
                ? previous.anchorDate
                : date,
          ),
        ),
      );
      return;
    }
    context.read<WalletBloc>().add(
      EntrySaved(
        WalletEntry(
          id:
              widget.entry?.id ??
              DateTime.now().microsecondsSinceEpoch.toString(),
          title: _title.text.trim(),
          amount: int.parse(_amount.text),
          type: _type,
          category: _category,
          date: _date,
          note: _note.text.trim(),
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text(
          'This will remove the transaction and update your balance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      _submittedRevision = context.read<WalletBloc>().state.revision;
      setState(() => _submitted = true);
      context.read<WalletBloc>().add(EntryDeleted(widget.entry!.id));
    }
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<WalletBloc, WalletState>(
    listener: (context, state) {
      if (!_submitted || state.status != WalletStatus.ready) return;
      if (state.revision <= _submittedRevision && state.error == null) return;
      if (state.error == null) {
        Navigator.pop(context);
      } else {
        setState(() {
          _submitted = false;
          _saveError = state.error;
        });
      }
    },
    builder: (context, state) {
      final busy = _submitted || state.status == WalletStatus.saving;
      return PopScope(
        canPop: !busy,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 12,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.isRecurring
                                ? (widget.schedule == null
                                      ? 'New schedule'
                                      : 'Edit schedule')
                                : (widget.entry == null
                                      ? 'New transaction'
                                      : 'Edit transaction'),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: busy ? null : () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SegmentedButton<EntryType>(
                      segments: const [
                        ButtonSegment(
                          value: EntryType.expense,
                          label: Text('Expense'),
                          icon: Icon(Icons.north_east),
                        ),
                        ButtonSegment(
                          value: EntryType.income,
                          label: Text('Income'),
                          icon: Icon(Icons.south_west),
                        ),
                      ],
                      selected: {_type},
                      onSelectionChanged: busy
                          ? null
                          : (value) => setState(() => _type = value.first),
                    ),
                    const SizedBox(height: 20),
                    MoneyInputField(controller: _amount, enabled: !busy),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _title,
                      enabled: !busy,
                      maxLength: 80,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'e.g. Lunch with friends',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Give this transaction a title'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Category>(
                      initialValue: _category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: Category.values
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category.label),
                            ),
                          )
                          .toList(),
                      onChanged: busy
                          ? null
                          : (value) => setState(() => _category = value!),
                    ),
                    if (widget.isRecurring) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<RepeatFrequency>(
                        initialValue: _frequency,
                        decoration: const InputDecoration(labelText: 'Repeat'),
                        items: RepeatFrequency.values
                            .map(
                              (frequency) => DropdownMenuItem(
                                value: frequency,
                                child: Text(frequency.label),
                              ),
                            )
                            .toList(),
                        onChanged: busy
                            ? null
                            : (value) => setState(() => _frequency = value!),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Choose the first or next due date below. You will confirm each occurrence before it affects your balance.',
                      ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: busy ? null : _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(DateFormat('EEEE, d MMM yyyy').format(_date)),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _note,
                      enabled: !busy,
                      maxLength: 240,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    if (_saveError != null) ...[
                      Text(
                        _saveError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    FilledButton(
                      onPressed: busy ? null : _save,
                      child: Text(
                        busy
                            ? 'Saving…'
                            : widget.isRecurring
                            ? 'Save schedule'
                            : 'Save transaction',
                      ),
                    ),
                    if (widget.entry != null)
                      TextButton(
                        onPressed: busy ? null : _delete,
                        child: const Text(
                          'Delete transaction',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
