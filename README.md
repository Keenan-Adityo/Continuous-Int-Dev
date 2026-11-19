# Pocket

An offline everyday wallet for Android and iOS, built with Flutter, BLoC, and feature-first Clean Architecture.

## Features

- Record income and expenses in whole Indonesian rupiah (IDR).
- Edit or delete transactions with title, category, date, and optional note.
- View your all-time balance and monthly income, expenses, and cash flow.
- Browse months, search transaction titles/notes/categories, and filter income or expenses.
- See monthly spending grouped by category.
- Schedule daily, weekly, monthly, or yearly income and expenses.
- Review in-app due reminders; confirm or skip each occurrence, and pause, edit, or delete schedules.
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

CI starts on every push and pull request to main. A lightweight change detector runs
Flutter tests and builds only for source, dependency, asset, localization, native,
or CI configuration changes. The final `Flutter CI required` check succeeds only
when those builds pass or when no relevant changes require a build.

To enforce merging rules in GitHub, create an active branch ruleset for `main`,
require pull requests, and require the `Flutter CI required` status check from
GitHub Actions. Enable requiring branches to be up to date and leave bypasses
empty if the rule should apply to everyone. Run the workflow once so the check
is available to select. The YAML alone does not enforce branch protection.
Avoid skip-CI commit messages on PRs: they prevent even the required check from
running. If a merge queue is introduced, add `merge_group` support before enabling it.

## Structure

`lib/features/wallet/domain` contains entities, repository contracts, and wallet use cases.
`data` implements versioned JSON persistence in the application documents directory.
`presentation` contains the sequential event-driven wallet BLoC, screens, and reusable feature widgets.
`lib/core/presentation` provides shared theme tokens and widgets.
Dependencies are wired in `lib/main.dart`; domain code has no Flutter dependencies.

## Storage

Transactions and recurring schedules are saved together on this device to `pocket_wallet.json`. Writes flush to a temporary
file before replacing the previous file. Failed reads keep the original data and block
editing; failed writes leave the displayed wallet unchanged. The wallet has no bank
connection, cloud sync, export, or app-level encryption. Removing the app can remove its
local data. System device backups depend on device settings.

No commits are created by the agent; changes remain available for review.

## Distribution templates

Manual testing-upload examples and their credential/signing setup are documented
in [.github/workflow-templates/README.md](.github/workflow-templates/README.md):

- [TestFlight iOS IPA upload](.github/workflow-templates/testflight.yml)
- [Firebase Android APK distribution](.github/workflow-templates/firebase.yml)

Copy a configured template into `.github/workflows/` to activate it. These
examples are inactive and no distribution credentials are stored in the repository.

## Recurring transactions

Open **Recurring → Add schedule** to enter an amount, title, category, repeat
frequency, first due date, and optional note. Schedules do not change the balance.
Due reminders appear on Overview and in Recurring, and refresh when the app
resumes or while it remains open. This version uses in-app reminders only.

Use **Record occurrence → Confirm record** to record a transaction on its due
date and advance to the next date in one saved change. **Skip occurrence** advances
one date without recording money. Missed occurrences are reviewed individually;
future and paused occurrences cannot be recorded. Monthly dates retain the
original day after a short month; yearly February 29 schedules regain that date
in leap years. Pause/resume keeps the next unreviewed date. Deleting a schedule
keeps transactions already recorded. Editing the next due date or frequency
starts a new date anchor; editing other details preserves it.

Existing version 1 wallet files load without modification and gain an empty
schedule list. The next successful save writes version 2, including transactions
and schedules. Older app versions cannot read version 2 files. Invalid wallet
files remain untouched and cannot be overwritten through the UI.
