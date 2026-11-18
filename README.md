# Pocket

An offline everyday wallet for Android and iOS, built with Flutter, BLoC, and feature-first Clean Architecture.

## Features

- Record income and expenses in whole Indonesian rupiah (IDR).
- Edit or delete transactions with title, category, date, and optional note.
- View your all-time balance and monthly income, expenses, and cash flow.
- Browse months, search transaction titles/notes/categories, and filter income or expenses.
- See monthly spending grouped by category.
- Start with an empty wallet; record an opening balance as income if needed.

## Run

Required project toolchain: Flutter 3.44.5, JDK 21, Xcode 26.5 (iOS).
The current development environment and existing CI use Flutter 3.47.9 / Dart 3.13.7;
`pubspec.yaml` currently requires Dart ^3.13.7. Flutter 3.44.5 compatibility has not
been verified. Resolve this toolchain mismatch before relying on that version.

```sh
flutter pub get
flutter run
```

## Checks

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --release --no-codesign
```

CI runs for Flutter source, dependency, asset, localization, and native platform changes on pushes and pull requests to main.

## Structure

`lib/features/wallet/domain` contains entities, repository contracts, and wallet use cases.
`data` implements versioned JSON persistence in the application documents directory.
`presentation` contains the sequential event-driven wallet BLoC, screens, and reusable feature widgets.
`lib/core/presentation` provides shared theme tokens and widgets.
Dependencies are wired in `lib/main.dart`; domain code has no Flutter dependencies.

## Storage

Transactions are saved on this device to `pocket_wallet.json`. Writes flush to a temporary
file before replacing the previous file. Failed reads keep the original data and block
editing; failed writes leave the displayed wallet unchanged. The wallet has no bank
connection, cloud sync, export, or app-level encryption. Removing the app can remove its
local data. System device backups depend on device settings.

No commits are created by the agent; changes remain available for review.
