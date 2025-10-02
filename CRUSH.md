# Fieldawy Store - Development Guide

## Build & Development Commands
- `flutter run` - Run app on connected device
- `flutter build apk --release` - Build Android release APK
- `flutter build ios --release` - Build iOS release
- `flutter analyze` - Run static analysis and linting
- `flutter test` - Run all tests
- `flutter test test/widget_test.dart` - Run specific test file
- `flutter pub run build_runner build` - Generate code (Hive adapters)
- `flutter pub run build_runner watch` - Watch for changes and regenerate

## Code Style Guidelines
- **Architecture**: Clean Architecture with Riverpod state management
- **Naming**: snake_case for files/folders, CamelCase for classes/widgets
- **Imports**: Group imports (Flutter, packages, local) with blank lines
- **State Management**: Riverpod for global state, hooks for local state
- **Error Handling**: Use try/catch with proper error messages
- **Localization**: Use `.tr()` for all user-facing strings
- **Models**: HiveType annotation with proper typeIds
- **File Structure**: Feature-first organization with data/domain/presentation
- **Theming**: Use AppTheme.lightTheme/darkTheme for consistent styling

## Key Dependencies
- Riverpod/Hooks Riverpod - State management
- Supabase - Backend services
- Hive - Local storage
- EasyLocalization - Multi-language support
- Cloudinary - Image management
- Google ML Kit - OCR functionality

## Testing
- Widget tests use `testWidgets` with `WidgetTester`
- Mock dependencies using Riverpod overrides
- Test both light and dark themes

## Code Generation
- Run `build_runner` after adding HiveType annotations
- Generated files end with `.g.dart` suffix