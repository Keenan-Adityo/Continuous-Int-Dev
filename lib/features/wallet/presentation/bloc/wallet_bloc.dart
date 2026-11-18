import 'package:bloc/bloc.dart';

import '../../domain/entities/wallet_entry.dart';
import '../../domain/usecases/manage_wallet.dart';

sealed class WalletEvent {}

class WalletOpened extends WalletEvent {}

class EntrySaved extends WalletEvent {
  EntrySaved(this.entry);
  final WalletEntry entry;
}

class EntryDeleted extends WalletEvent {
  EntryDeleted(this.id);
  final String id;
}

enum WalletStatus { loading, ready, saving, failure }

class WalletState {
  WalletState({
    this.status = WalletStatus.loading,
    List<WalletEntry> entries = const [],
    this.error,
    this.revision = 0,
  }) : entries = List.unmodifiable(entries);
  final WalletStatus status;
  final List<WalletEntry> entries;
  final String? error;
  final int revision;
}

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  WalletBloc(this.wallet) : super(WalletState()) {
    // A single sequential event stream prevents overlapping writes and lost entries.
    on<WalletEvent>(
      _handle,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
  }
  final ManageWallet wallet;

  Future<void> _handle(WalletEvent event, Emitter<WalletState> emit) async {
    final previous = state;
    if (event is! WalletOpened && previous.status != WalletStatus.ready) return;
    emit(
      WalletState(
        status: event is WalletOpened
            ? WalletStatus.loading
            : WalletStatus.saving,
        entries: previous.entries,
        revision: previous.revision,
      ),
    );
    try {
      final entries = switch (event) {
        WalletOpened() => await wallet.load(),
        EntrySaved(:final entry) => await wallet.upsert(
          previous.entries,
          entry,
        ),
        EntryDeleted(:final id) => await wallet.remove(previous.entries, id),
      };
      emit(
        WalletState(
          status: WalletStatus.ready,
          entries: entries,
          revision: previous.revision + 1,
        ),
      );
    } on WalletFailure catch (failure) {
      emit(
        WalletState(
          status: event is WalletOpened
              ? WalletStatus.failure
              : WalletStatus.ready,
          entries: previous.entries,
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
          entries: previous.entries,
          error: 'Something went wrong. Please try again.',
          revision: previous.revision,
        ),
      );
    }
  }
}
