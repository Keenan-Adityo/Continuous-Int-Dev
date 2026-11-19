import '../../domain/entities/recurring_transaction.dart';
import '../../domain/entities/wallet_entry.dart';
import '../../domain/usecases/transaction_validation.dart';

abstract final class RecurringTransactionModel {
  static Map<String, dynamic> encode(RecurringTransaction schedule) => {
    'id': schedule.id,
    'title': schedule.title,
    'amount': schedule.amount,
    'type': schedule.type.name,
    'category': schedule.category.name,
    'note': schedule.note,
    'anchorDate': schedule.anchorDate.toIso8601String(),
    'nextDueDate': schedule.nextDueDate.toIso8601String(),
    'frequency': schedule.frequency.name,
    'enabled': schedule.enabled,
  };

  static RecurringTransaction decode(Map<String, dynamic> json) {
    final schedule = RecurringTransaction(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: json['amount'] as int,
      type: EntryType.values.byName(json['type'] as String),
      category: Category.values.byName(json['category'] as String),
      note: json['note'] as String,
      enabled: json['enabled'] as bool,
      anchorDate: DateTime.parse(json['anchorDate'] as String),
      nextDueDate: DateTime.parse(json['nextDueDate'] as String),
      frequency: RepeatFrequency.values.byName(json['frequency'] as String),
    );
    validateTransactionDetails(
      id: schedule.id,
      title: schedule.title,
      amount: schedule.amount,
      note: schedule.note,
    );
    if (schedule.anchorDate != calendarDate(schedule.anchorDate) ||
        schedule.nextDueDate != calendarDate(schedule.nextDueDate) ||
        schedule.nextDueDate.isBefore(schedule.anchorDate)) {
      throw const FormatException('Invalid schedule dates');
    }
    return schedule;
  }
}
