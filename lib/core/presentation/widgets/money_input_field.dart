import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MoneyInputField extends StatelessWidget {
  const MoneyInputField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.label = 'Amount (IDR)',
    this.maxAmount = 999999999999,
  });
  final TextEditingController controller;
  final bool enabled;
  final String label;
  final int maxAmount;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    enabled: enabled,
    decoration: InputDecoration(labelText: label, prefixText: 'Rp '),
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    validator: (value) {
      final amount = int.tryParse(value ?? '');
      return amount == null || amount <= 0 || amount > maxAmount
          ? 'Enter a whole amount from 1 to $maxAmount'
          : null;
    },
  );
}
