# Agent Guidelines for pos_system_legphel Flutter POS App

## Commands
- Build: `flutter build apk` or `flutter build --release`
- Run: `flutter run` (debug), `flutter run --release` (release)
- Test: `flutter test` (all tests), `flutter test test/specific_test.dart` (single test)
- Lint: `flutter analyze` (static analysis)
- Format: `dart format .` or `dart format lib/`
- Clean: `flutter clean` (clean build artifacts)
- Dependencies: `flutter pub get` (install), `flutter pub upgrade` (update)

## Architecture
- **Pattern**: BLoC architecture using flutter_bloc for state management
- **Database**: SQLite via sqflite for local data storage
- **Structure**: Modular organization with separate BLoCs for each feature
- **Key directories**: `lib/bloc/` (business logic), `lib/models/` (data models), `lib/views/` (UI), `lib/services/` (external services), `lib/SQL/` (database)
- **Main features**: POS system with menu management, order processing, bill generation, table management, room reservations

## Code Style
- **Imports**: Group imports (dart, flutter, package, relative) with single blank lines between groups
- **Naming**: snake_case for files/directories, camelCase for variables/functions, PascalCase for classes
- **State management**: Use BLoC pattern with events, states, and proper separation of concerns
- **Error handling**: Use try-catch blocks and proper state management for error states
- **Formatting**: Follow flutter_lints rules, prefer single quotes for strings
- **Assets**: Store in `assets/images/`, `assets/icons/`, `assets/app_icon/`
