import '../entities/wallet_entry.dart';

void validateTransactionDetails({
  required String id,
  required String title,
  required int amount,
  required String note,
}) {
  if (id.isEmpty || title.trim().isEmpty || title.length > 80) {
    throw const WalletFailure('Enter a title of 1–80 characters.');
  }
  if (amount <= 0 || amount > 999999999999) {
    throw const WalletFailure(
      'Enter an amount from Rp 1 to Rp 999,999,999,999.',
    );
  }
  if (note.length > 240) {
    throw const WalletFailure('Keep notes to 240 characters or fewer.');
  }
}
