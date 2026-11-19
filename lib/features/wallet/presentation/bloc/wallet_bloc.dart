import 'package:bloc/bloc.dart';

import '../../domain/entities/recurring_transaction.dart';
import '../../domain/entities/wallet_data.dart';
import '../../domain/entities/wallet_entry.dart';
import '../../domain/entities/savings_goal.dart';
import '../../domain/usecases/manage_recurring_transactions.dart';
import '../../domain/usecases/manage_wallet.dart';
import '../../domain/usecases/manage_savings_goals.dart';

sealed class WalletEvent {}

class WalletOpened extends WalletEvent {}

class WalletClockTicked extends WalletEvent {}

class EntrySaved extends WalletEvent {
  EntrySaved(this.entry);
  final WalletEntry entry;
}

class EntryDeleted extends WalletEvent {
  EntryDeleted(this.id);
  final String id;
}

class ScheduleSaved extends WalletEvent {
  ScheduleSaved(this.schedule);
  final RecurringTransaction schedule;
}

class ScheduleDeleted extends WalletEvent {
  ScheduleDeleted(this.id);
  final String id;
}

class ScheduleToggled extends WalletEvent {
  ScheduleToggled(this.id);
  final String id;
}

class OccurrenceResolved extends WalletEvent {
  OccurrenceResolved(this.id, this.dueDate, {required this.record});
  final String id;
  final DateTime dueDate;
  final bool record;
}

class GoalSaved extends WalletEvent {
  GoalSaved({
    required this.id,
    required this.title,
    required this.targetAmount,
    this.targetDate,
  });
  final String id;
  final String title;
  final int targetAmount;
  final DateTime? targetDate;
}

class GoalDeleted extends WalletEvent {
  GoalDeleted(this.id);
  final String id;
}

class GoalContributionAdded extends WalletEvent {
  GoalContributionAdded(this.goalId, this.contribution);
  final String goalId;
  final GoalContribution contribution;
}

class GoalContributionRemoved extends WalletEvent {
  GoalContributionRemoved(this.goalId, this.contributionId);
  final String goalId;
  final String contributionId;
}

enum WalletStatus { loading, ready, saving, failure }

class WalletState {
  WalletState({
    this.status = WalletStatus.loading,
    WalletData? data,
    this.error,
    this.revision = 0,
  }) : data = data ?? WalletData();
  final WalletStatus status;
  final WalletData data;
  List<WalletEntry> get entries => data.entries;
  List<RecurringTransaction> get schedules => data.schedules;
  List<SavingsGoal> get goals => data.goals;
  final String? error;
  final int revision;
}

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  WalletBloc(this.wallet, this.recurring, this.savings) : super(WalletState()) {
    // All writes share one sequential stream to prevent lost or duplicate records.
    on<WalletEvent>(
      _handle,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
  }
  final ManageWallet wallet;
  final ManageRecurringTransactions recurring;
  final ManageSavingsGoals savings;

  Future<void> _handle(WalletEvent event, Emitter<WalletState> emit) async {
    final previous = state;
    if (event is! WalletOpened && previous.status != WalletStatus.ready) return;
    if (event is WalletClockTicked) {
      emit(
        WalletState(
          status: previous.status,
          data: previous.data,
          revision: previous.revision,
        ),
      );
      return;
    }
    emit(
      WalletState(
        status: event is WalletOpened
            ? WalletStatus.loading
            : WalletStatus.saving,
        data: previous.data,
        revision: previous.revision,
      ),
    );
    try {
      final data = switch (event) {
        WalletOpened() => await wallet.load(),
        EntrySaved(:final entry) => await wallet.upsert(previous.data, entry),
        EntryDeleted(:final id) => await wallet.remove(previous.data, id),
        ScheduleSaved(:final schedule) => await recurring.upsert(
          previous.data,
          schedule,
        ),
        ScheduleDeleted(:final id) => await recurring.remove(previous.data, id),
        ScheduleToggled(:final id) => await recurring.toggle(previous.data, id),
        OccurrenceResolved(:final id, :final dueDate, :final record) =>
          await recurring.resolve(previous.data, id, dueDate, record: record),
        GoalSaved(
          :final id,
          :final title,
          :final targetAmount,
          :final targetDate,
        ) =>
          await savings.upsert(
            previous.data,
            id: id,
            title: title,
            targetAmount: targetAmount,
            targetDate: targetDate,
          ),
        GoalDeleted(:final id) => await savings.remove(previous.data, id),
        GoalContributionAdded(:final goalId, :final contribution) =>
          await savings.contribute(previous.data, goalId, contribution),
        GoalContributionRemoved(:final goalId, :final contributionId) =>
          await savings.removeContribution(
            previous.data,
            goalId,
            contributionId,
          ),
        WalletClockTicked() => previous.data,
      };
      emit(
        WalletState(
          status: WalletStatus.ready,
          data: data,
          revision: previous.revision + 1,
        ),
      );
    } on WalletFailure catch (failure) {
      emit(
        WalletState(
          status: event is WalletOpened
              ? WalletStatus.failure
              : WalletStatus.ready,
          data: previous.data,
          error: failure.message,
          revision: previous.revision,
        ),
      );
    } catch (_) {
      emit(
        WalletState(
          status: event is WalletOpened
              ? WalletStatus.failure
              : WalletStatus.ready,
          data: previous.data,
          error: 'Something went wrong. Please try again.',
          revision: previous.revision,
        ),
      );
    }
  }
}
