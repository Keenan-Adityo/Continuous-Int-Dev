import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/presentation/app_theme.dart';
import '../../../../core/presentation/widgets/section_card.dart';
import '../../domain/entities/wallet_entry.dart';
import '../../domain/usecases/manage_wallet.dart';
import '../bloc/wallet_bloc.dart';
import '../widgets/entry_sheet.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/wallet_format.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});
  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  int _tab = 0;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  EntryType? _filter;
  String _search = '';

  void _openEntry({WalletEntry? entry, EntryType type = EntryType.expense}) {
    final bloc = context.read<WalletBloc>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: EntrySheet(entry: entry, initialType: type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<WalletBloc, WalletState>(
    listener: (context, state) {
      if (state.error != null && state.status != WalletStatus.failure) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(state.error!)));
      }
    },
    builder: (context, state) => Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.mint,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'pocket',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Tooltip(
              message: 'Saved on this device',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 13),
                    SizedBox(width: 5),
                    Text(
                      'LOCAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: state.status == WalletStatus.loading
          ? const Center(child: CircularProgressIndicator())
          : state.status == WalletStatus.failure
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 48),
                    const SizedBox(height: 16),
                    Text(state.error!, textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () =>
                          context.read<WalletBloc>().add(WalletOpened()),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  key: PageStorageKey('wallet-$_tab'),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                  children: _content(state),
                ),
              ),
            ),
      floatingActionButton: state.status == WalletStatus.ready
          ? FloatingActionButton.extended(
              onPressed: () => _openEntry(),
              backgroundColor: AppColors.ink,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add transaction'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.mint,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_rounded),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.donut_large_rounded),
            label: 'Insights',
          ),
        ],
      ),
    ),
  );

  List<Widget> _content(WalletState state) {
    final summary = WalletSummary(state.entries, _month);
    final entries =
        state.entries
            .where(
              (entry) =>
                  entry.date.year == _month.year &&
                  entry.date.month == _month.month &&
                  (_tab != 1 || _filter == null || entry.type == _filter) &&
                  (_tab != 1 ||
                      ('${entry.title} ${entry.note} ${entry.category.label}')
                          .toLowerCase()
                          .contains(_search.toLowerCase())),
            )
            .toList()
          ..sort((a, b) {
            final date = b.date.compareTo(a.date);
            return date == 0 ? b.id.compareTo(a.id) : date;
          });
    return [
      Text(switch (_tab) {
        0 => 'A little clarity. Every day.',
        1 => 'Your money, in motion.',
        _ => 'Small habits. Bigger picture.',
      }, style: const TextStyle(color: AppColors.muted, fontSize: 14)),
      const SizedBox(height: 6),
      Text(
        [
          'Your everyday wallet',
          'Transaction activity',
          'Spending insights',
        ][_tab],
        style: const TextStyle(
          fontSize: 28,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
      ),
      const SizedBox(height: 24),
      if (_tab == 0) ...[
        SectionCard(
          color: AppColors.ink,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL BALANCE',
                    style: TextStyle(
                      color: AppColors.mint,
                      fontSize: 11,
                      letterSpacing: 1.8,
                    ),
                  ),
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: AppColors.mint,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  money(summary.balance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'All your recorded income, less your expenses.',
                style: TextStyle(color: AppColors.mint, fontSize: 12),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.mint,
                      foregroundColor: AppColors.ink,
                    ),
                    onPressed: state.status == WalletStatus.saving
                        ? null
                        : () => _openEntry(type: EntryType.income),
                    icon: const Icon(Icons.south_west, size: 18),
                    label: const Text('Add income'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.muted),
                      padding: const EdgeInsets.all(16),
                    ),
                    onPressed: state.status == WalletStatus.saving
                        ? null
                        : () => _openEntry(),
                    icon: const Icon(Icons.north_east, size: 18),
                    label: const Text('Add expense'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: () => setState(
              () => _month = DateTime(_month.year, _month.month - 1),
            ),
            icon: const Icon(Icons.chevron_left),
          ),
          Flexible(
            child: Text(
              DateFormat('MMMM yyyy').format(_month),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed:
                _month.year == DateTime.now().year &&
                    _month.month == DateTime.now().month
                ? null
                : () => setState(
                    () => _month = DateTime(_month.year, _month.month + 1),
                  ),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (_tab != 1) ...[
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              _MetricCard(
                label: 'Income',
                amount: summary.income,
                income: true,
              ),
              _MetricCard(
                label: 'Expenses',
                amount: summary.expenses,
                income: false,
              ),
            ];
            return constraints.maxWidth < 340
                ? Column(
                    children: [cards[0], const SizedBox(height: 12), cards[1]],
                  )
                : Row(
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 12),
                      Expanded(child: cards[1]),
                    ],
                  );
          },
        ),
        const SizedBox(height: 24),
      ],
      if (_tab == 2)
        ..._insights(summary)
      else ...[
        if (_tab == 1) ...[
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search transactions',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final type in [null, ...EntryType.values])
                ChoiceChip(
                  label: Text(
                    type == null
                        ? 'All'
                        : type == EntryType.expense
                        ? 'Expenses'
                        : 'Income',
                  ),
                  selected: _filter == type,
                  onSelected: (_) => setState(() => _filter = type),
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _tab == 0 ? 'Recent activity' : '${entries.length} transactions',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            if (_tab == 0)
              TextButton(
                onPressed: () => setState(() {
                  _tab = 1;
                  _filter = null;
                  _search = '';
                }),
                child: const Text('See all'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SectionCard(
          child: entries.isEmpty
              ? _EmptyWallet(
                  onAdd: () => _openEntry(),
                  hasEntries: state.entries.isNotEmpty,
                )
              : Column(
                  children: [
                    for (final entry in (_tab == 0 ? entries.take(5) : entries))
                      TransactionTile(
                        entry: entry,
                        onTap: () => _openEntry(entry: entry),
                      ),
                  ],
                ),
        ),
      ],
      const SizedBox(height: 22),
      const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 14, color: AppColors.muted),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'Your wallet stays on this device.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _insights(WalletSummary summary) {
    final categories = summary.categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Where it went',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your expenses by category this month.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            if (categories.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Add an expense to see your spending breakdown.'),
              ),
            for (final category in categories)
              Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(categoryIcon(category.key), size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text(category.key.label)),
                        Text(
                          money(category.value),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: category.value / summary.expenses,
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(8),
                      backgroundColor: AppColors.mint,
                      color: AppColors.green,
                    ),
                    const SizedBox(height: 5),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${(category.value / summary.expenses * 100).round()}% of spending',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SectionCard(
        color: AppColors.mint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly cash flow',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              money(summary.income - summary.expenses),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text('Income minus expenses for the selected month.'),
          ],
        ),
      ),
    ];
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.amount,
    required this.income,
  });
  final String label;
  final int amount;
  final bool income;
  @override
  Widget build(BuildContext context) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              income ? Icons.south_west : Icons.north_east,
              size: 17,
              color: income ? AppColors.green : AppColors.expense,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            money(amount),
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _EmptyWallet extends StatelessWidget {
  const _EmptyWallet({required this.onAdd, required this.hasEntries});
  final VoidCallback onAdd;
  final bool hasEntries;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Column(
      children: [
        const SizedBox(height: 18),
        const Icon(Icons.savings_outlined, size: 42, color: AppColors.green),
        const SizedBox(height: 14),
        Text(
          hasEntries
              ? 'No matching transactions'
              : 'A fresh start for your money',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          hasEntries
              ? 'Try another month or filter.'
              : 'Add your first income or expense to get going.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 14),
        TextButton(onPressed: onAdd, child: const Text('Add a transaction')),
        const SizedBox(height: 8),
      ],
    ),
  );
}
