import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/wallet_entry.dart';
import '../bloc/wallet_bloc.dart';

class EntrySheet extends StatefulWidget {
  const EntrySheet({
    super.key,
    this.entry,
    this.initialType = EntryType.expense,
  });
  final WalletEntry? entry;
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

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _title = TextEditingController(text: entry?.title);
    _amount = TextEditingController(text: entry?.amount.toString());
    _note = TextEditingController(text: entry?.note);
    _type = entry?.type ?? widget.initialType;
    _category =
        entry?.category ??
        (_type == EntryType.income ? Category.salary : Category.food);
    _date = entry?.date ?? DateTime.now();
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
      lastDate: DateTime.now(),
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    setState(() => _submitted = true);
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
      setState(() => _submitted = true);
      context.read<WalletBloc>().add(EntryDeleted(widget.entry!.id));
    }
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<WalletBloc, WalletState>(
    listener: (context, state) {
      if (!_submitted || state.status != WalletStatus.ready) return;
      if (state.error == null) {
        Navigator.pop(context);
      } else {
        setState(() => _submitted = false);
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
                            widget.entry == null
                                ? 'New transaction'
                                : 'Edit transaction',
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
                    TextFormField(
                      controller: _amount,
                      enabled: !busy,
                      decoration: const InputDecoration(
                        labelText: 'Amount (IDR)',
                        prefixText: 'Rp ',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        final amount = int.tryParse(value ?? '');
                        return amount == null ||
                                amount <= 0 ||
                                amount > 999999999999
                            ? 'Enter a whole amount from 1 to 999,999,999,999'
                            : null;
                      },
                    ),
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
                    FilledButton(
                      onPressed: busy ? null : _save,
                      child: Text(busy ? 'Saving…' : 'Save transaction'),
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
