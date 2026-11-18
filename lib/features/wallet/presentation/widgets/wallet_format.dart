import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/wallet_entry.dart';

String money(int amount) => NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
).format(amount);

IconData categoryIcon(Category category) => switch (category) {
  Category.food => Icons.restaurant_rounded,
  Category.transport => Icons.directions_bus_rounded,
  Category.shopping => Icons.shopping_bag_outlined,
  Category.bills => Icons.receipt_long_rounded,
  Category.health => Icons.favorite_border_rounded,
  Category.leisure => Icons.headphones_rounded,
  Category.salary => Icons.work_outline_rounded,
  Category.other => Icons.more_horiz_rounded,
};
