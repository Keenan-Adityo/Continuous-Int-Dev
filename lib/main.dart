import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

import 'core/presentation/app_theme.dart';
import 'features/wallet/data/datasources/wallet_file_store.dart';
import 'features/wallet/data/repositories/local_wallet_repository.dart';
import 'features/wallet/domain/repositories/wallet_repository.dart';
import 'features/wallet/domain/usecases/manage_wallet.dart';
import 'features/wallet/domain/usecases/manage_savings_goals.dart';
import 'features/wallet/domain/usecases/manage_recurring_transactions.dart';
import 'features/wallet/presentation/bloc/wallet_bloc.dart';
import 'features/wallet/presentation/pages/wallet_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    PocketApp(
      repository: LocalWalletRepository(
        WalletFileStore(getApplicationDocumentsDirectory),
      ),
    ),
  );
}

class PocketApp extends StatelessWidget {
  const PocketApp({super.key, required this.repository});
  final WalletRepository repository;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => WalletBloc(
      ManageWallet(repository),
      ManageRecurringTransactions(repository),
      ManageSavingsGoals(repository),
    )..add(WalletOpened()),
    child: MaterialApp(
      title: 'Pocket',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const WalletPage(),
    ),
  );
}
