import '../../domain/entities/wallet_entry.dart';

abstract final class WalletEntryModel {
  static Map<String, dynamic> encode(WalletEntry entry) => {
    'id': entry.id,
    'title': entry.title,
    'amount': entry.amount,
    'type': entry.type.name,
    'category': entry.category.name,
    'date': entry.date.toIso8601String(),
    'note': entry.note,
  };

  static WalletEntry decode(Map<String, dynamic> json) {
    final entry = WalletEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: json['amount'] as int,
      type: EntryType.values.byName(json['type'] as String),
      category: Category.values.byName(json['category'] as String),
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String,
    );
    if (entry.id.isEmpty || entry.title.trim().isEmpty || entry.amount <= 0) {
      throw const FormatException('Invalid wallet entry');
    }
    return entry;
  }
}
