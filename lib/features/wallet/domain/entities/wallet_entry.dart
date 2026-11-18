enum EntryType { expense, income }

enum Category {
  food('Food & drinks'),
  transport('Transport'),
  shopping('Shopping'),
  bills('Bills'),
  health('Health'),
  leisure('Leisure'),
  salary('Salary'),
  other('Other');

  const Category(this.label);
  final String label;
}

class WalletEntry {
  const WalletEntry({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.note = '',
  });
  final String id;
  final String title;

  /// Whole Indonesian rupiah. Integer arithmetic avoids rounding errors.
  final int amount;
  final EntryType type;
  final Category category;
  final DateTime date;
  final String note;
}

class WalletFailure implements Exception {
  const WalletFailure(this.message);
  final String message;
}
