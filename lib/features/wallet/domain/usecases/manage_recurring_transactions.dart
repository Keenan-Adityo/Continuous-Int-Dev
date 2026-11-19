import '../entities/recurring_transaction.dart';
import '../entities/wallet_data.dart';
import '../entities/wallet_entry.dart';
import '../repositories/wallet_repository.dart';
import 'transaction_validation.dart';

class ManageRecurringTransactions {
  ManageRecurringTransactions(this.repository, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final WalletRepository repository;
  final DateTime Function() clock;

  Future<WalletData> upsert(
    WalletData data,
    RecurringTransaction schedule,
  ) async {
    validateTransactionDetails(
      id: schedule.id,
      title: schedule.title,
      amount: schedule.amount,
      note: schedule.note,
    );
    if (schedule.anchorDate != calendarDate(schedule.anchorDate) ||
        schedule.nextDueDate != calendarDate(schedule.nextDueDate) ||
        schedule.nextDueDate.isBefore(schedule.anchorDate)) {
      throw const WalletFailure('Choose a valid schedule date.');
    }
    return _save(
      data.copyWith(
        schedules: [
          ...data.schedules.where((s) => s.id != schedule.id),
          schedule,
        ],
      ),
    );
  }

  Future<WalletData> remove(WalletData data, String id) => _save(
    data.copyWith(schedules: data.schedules.where((s) => s.id != id).toList()),
  );

  Future<WalletData> toggle(WalletData data, String id) {
    final schedule = _find(data, id);
    return _save(
      data.copyWith(
        schedules: data.schedules
            .map((s) => s.id == id ? s.copyWith(enabled: !schedule.enabled) : s)
            .toList(),
      ),
    );
  }

  /// A due date is the confirmation token. Repeated/stale taps cannot record twice.
  Future<WalletData> resolve(
    WalletData data,
    String id,
    DateTime dueDate, {
    required bool record,
  }) async {
    final schedule = _find(data, id);
    if (!schedule.isDue(clock()) || schedule.nextDueDate != dueDate) {
      throw const WalletFailure(
        'This occurrence has already changed or is not due.',
      );
    }
    final entryId = 'recurring:$id:${dueDate.toIso8601String()}';
    if (record && data.entries.any((entry) => entry.id == entryId)) {
      throw const WalletFailure('This occurrence has already been recorded.');
    }
    final entries = [...data.entries];
    if (record) {
      entries.add(
        WalletEntry(
          id: entryId,
          title: schedule.title,
          amount: schedule.amount,
          type: schedule.type,
          category: schedule.category,
          date: dueDate,
          note: schedule.note,
        ),
      );
    }
    final updated = data.copyWith(
      entries: entries,
      schedules: data.schedules
          .map((s) => s.id == id ? s.copyWith(nextDueDate: s.followingDate) : s)
          .toList(),
    );
    // A single write advances the schedule and records the transaction together.
    return _save(updated);
  }

  RecurringTransaction _find(WalletData data, String id) =>
      data.schedules.firstWhere(
        (s) => s.id == id,
        orElse: () => throw const WalletFailure('Schedule no longer exists.'),
      );

  Future<WalletData> _save(WalletData data) async {
    await repository.save(data);
    return data;
  }
}
