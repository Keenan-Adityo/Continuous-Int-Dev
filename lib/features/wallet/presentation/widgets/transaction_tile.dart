import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/presentation/app_theme.dart';
import '../../domain/entities/wallet_entry.dart';
import 'wallet_format.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.entry, required this.onTap});
  final WalletEntry entry;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final income = entry.type == EntryType.income;
    final amount = Text(
      '${income ? '+' : '−'}${money(entry.amount)}',
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: income ? AppColors.green : AppColors.ink,
      ),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 360;
            return Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: income ? AppColors.mint : const Color(0xFFF4EDE3),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    categoryIcon(entry.category),
                    color: AppColors.ink,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${entry.category.label} · ${DateFormat('d MMM').format(entry.date)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                      if (compact) ...[
                        const SizedBox(height: 5),
                        FittedBox(fit: BoxFit.scaleDown, child: amount),
                      ],
                    ],
                  ),
                ),
                if (!compact) ...[const SizedBox(width: 12), amount],
              ],
            );
          },
        ),
      ),
    );
  }
}
