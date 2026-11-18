# Agent instructions

These rules apply to all work in this repository.

## Toolchain

- Use Flutter **3.44.5** and the Dart SDK bundled with that Flutter version.
- Use **JDK 21** for Android tooling and builds.
- Use **Xcode 26.5** for iOS tooling and builds.
- Check the active tool versions before toolchain-dependent work. Report mismatches; do not silently upgrade or downgrade the project toolchain.
- Keep project configuration and CI consistent with these versions. JDK 21 is the build runtime; do not change Java/Kotlin bytecode targets solely to match it.

## Architecture

- Implement Clean Architecture with a feature-first structure:

  ```text
  lib/
    core/                     # Shared infrastructure and cross-feature utilities
    features/
      <feature>/
        domain/
          entities/
          repositories/       # Repository contracts
          usecases/
        data/
          datasources/
          models/
          repositories/       # Repository implementations
        presentation/
          bloc/
          pages/
          widgets/
  ```

- Keep domain code independent of Flutter, presentation, data implementations, and external service SDKs.
- Put business rules in domain use cases and entities. Define repository contracts in domain and implement them in data.
- Keep serialization, API calls, persistence, and conversions between models and domain entities in data.
- Keep widgets focused on rendering and user interaction. Do not access data sources or implement business rules in widgets.
- Inject dependencies through constructors and wire implementations at the application composition root. Avoid hidden global dependencies.
- Add abstractions and shared code when they serve a concrete need; avoid speculative layers and unrelated refactors.

## Reusable components

- Check existing widgets and components before creating new UI. Reuse or extend an existing component when it meets the requirement.
- Extract repeated UI into reusable widgets instead of duplicating implementations across screens.
- Place widgets shared across features in `lib/core/presentation/widgets/`; keep feature-specific reusable widgets in that feature's `presentation/widgets/` directory.
- Use clear, typed parameters and callbacks to support required variations. Keep shared widgets independent of feature-specific BLoCs and business logic.
- Use the application theme and shared design tokens for consistent colors, typography, spacing, and shapes.
- Keep component APIs focused on actual use cases; avoid adding speculative configuration.

## State management

- Use **BLoC**, with `bloc` and `flutter_bloc`, for application state management.
- Model feature behavior with explicit events and immutable states. Keep BLoCs focused on their feature and invoke domain use cases for business operations.
- Represent loading, success, empty, and failure states where applicable.
- Use `BlocBuilder` or `BlocSelector` for rendering and `BlocListener` for navigation, dialogs, and other UI side effects.
- Keep widget-local controllers and ephemeral UI mechanics local; do not introduce another application state management framework.
- Close owned BLoCs, subscriptions, and controllers according to their lifecycle.

## Code quality

- Follow Dart formatting, the repository's analyzer configuration, and idiomatic null-safe Dart.
- Prefer small, cohesive classes and functions, clear names, immutable data, and `const` constructors where appropriate.
- Handle expected failures explicitly and translate infrastructure errors at the data boundary. Do not swallow exceptions or expose raw errors to users.
- Add dependencies only when needed and verify compatibility with the pinned toolchain.
- Never hardcode secrets or log credentials, tokens, or sensitive user data.
- Preserve existing user changes and keep edits focused on the requested task. Do not edit generated files manually.

## Verification

- For Dart changes, format the changed files with `dart format` and run `flutter analyze`.
- Run relevant `flutter test` checks for behavior changes. Cover domain behavior, BLoC transitions, and widget interactions at the appropriate level.
- Run platform builds when platform configuration or native code changes warrant them and the required tooling is available.
- Report what changed, which checks ran, and any checks that could not run. Do not claim checks passed without running them.

## Git

- **Do not create commits.** Leave changes in the working tree for the user to review and commit.
- Do not push, amend commits, rewrite history, or discard user changes.
