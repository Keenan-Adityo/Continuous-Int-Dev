import 'wallet_entry.dart';

enum RepeatFrequency {
  daily('Daily'),
  weekly('Weekly'),
  monthly('Monthly'),
  yearly('Yearly');

  const RepeatFrequency(this.label);
  final String label;
}

DateTime calendarDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);

class RecurringTransaction {
  const RecurringTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.anchorDate,
    required this.nextDueDate,
    required this.frequency,
    this.note = '',
    this.enabled = true,
  });
  final String id;
  final String title;
  final int amount;
  final EntryType type;
  final Category category;
  final String note;

  /// Original day/month stays stable across short months and leap years.
  final DateTime anchorDate;
  final DateTime nextDueDate;
  final RepeatFrequency frequency;
  final bool enabled;

  bool isDue(DateTime now) =>
      enabled && !calendarDate(nextDueDate).isAfter(calendarDate(now));

  DateTime get followingDate {
    final due = nextDueDate;
    return switch (frequency) {
      RepeatFrequency.daily => DateTime(due.year, due.month, due.day + 1),
      RepeatFrequency.weekly => DateTime(due.year, due.month, due.day + 7),
      RepeatFrequency.monthly => _clampedDate(
        due.year,
        due.month + 1,
        anchorDate.day,
      ),
      RepeatFrequency.yearly => _clampedDate(
        due.year + 1,
        anchorDate.month,
        anchorDate.day,
      ),
    };
  }

  static DateTime _clampedDate(int year, int month, int day) {
    final first = DateTime(year, month);
    final last = DateTime(first.year, first.month + 1, 0).day;
    return DateTime(first.year, first.month, day > last ? last : day);
  }

  RecurringTransaction copyWith({DateTime? nextDueDate, bool? enabled}) =>
      RecurringTransaction(
        id: id,
        title: title,
        amount: amount,
        type: type,
        category: category,
        anchorDate: anchorDate,
        nextDueDate: nextDueDate ?? this.nextDueDate,
        frequency: frequency,
        note: note,
        enabled: enabled ?? this.enabled,
      );
}
