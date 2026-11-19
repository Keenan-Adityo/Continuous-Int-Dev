import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/wallet_bloc.dart';

/// Shared save lifecycle and error feedback for wallet editing forms.
class WalletActionSheet extends StatefulWidget {
  const WalletActionSheet({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.contentBuilder,
    required this.eventBuilder,
  });
  final String title;
  final String submitLabel;
  final Widget Function(BuildContext context, bool busy) contentBuilder;
  final WalletEvent? Function() eventBuilder;
  @override
  State<WalletActionSheet> createState() => _WalletActionSheetState();
}

class _WalletActionSheetState extends State<WalletActionSheet> {
  bool _submitted = false;
  int _revision = 0;
  String? _error;

  void _submit() {
    final event = widget.eventBuilder();
    if (event == null) return;
    _revision = context.read<WalletBloc>().state.revision;
    setState(() {
      _submitted = true;
      _error = null;
    });
    context.read<WalletBloc>().add(event);
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<WalletBloc, WalletState>(
    listener: (context, state) {
      if (!_submitted || state.status != WalletStatus.ready) return;
      if (state.error == null && state.revision <= _revision) return;
      if (state.error == null) {
        Navigator.pop(context);
      } else {
        setState(() {
          _submitted = false;
          _error = state.error;
        });
      }
    },
    builder: (context, state) {
      final busy = _submitted || state.status != WalletStatus.ready;
      return PopScope(
        canPop: !busy,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: busy ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  widget.contentBuilder(context, busy),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: busy ? null : _submit,
                    child: Text(busy ? 'Saving…' : widget.submitLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
