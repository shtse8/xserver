# Changelog

## [0.2.0] - 2024-08-05

### New Features
- Introduced a new design for path handling and validation in the XServerGenerator.
- Added support for nested optional path segments (e.g., `/user[/<id>[/<name>]]`).

### Improvements
- Enhanced path parameter validation to correctly handle required and optional parameters.
- Improved handling of nullable (`String?`) path parameters, treating them as optional.

### Changes
- Modified the `_validatePath` method to focus on validating required parameters in the required part of the path.
- Introduced `_extractRequiredPath` method to handle complex nested optional path structures.

### Fixes
- Resolved issues with false positives in path validation for nested optional segments.
- Fixed incorrect handling of nullable parameters in path validation.

### Developer Experience
- Simplified the process of defining complex routes with optional parameters.
- Improved error messages for invalid path definitions, providing more context for easier debugging.

### Performance
- Optimized path validation process, reducing unnecessary checks on optional parameters.

### Documentation
- Updated README with examples of new path definition capabilities.
- Added more comprehensive documentation for path parameter usage and best practices.

## How to Upgrade
To upgrade to this version, update your `pubspec.yaml`:

```yaml
dependencies:
  xserver: ^0.2.0
```

Then run:
```
dart pub get
```

Ensure to review your existing route definitions, particularly those with optional parameters, as the new validation logic may catch previously undetected issues.

## [0.1.3] - 2024-07-31

### Added
- Introduced a new annotation-based handler design.
  - Handlers can now be defined using `@get`, `@post`, and `@all` annotations.
  - Support for specifying multiple handlers in a single file.
  - Added new handler annotations in `annotations.dart`.

### Changed
- Updated `build.yaml` to include the new handler builder configuration.
- Modified `endpoint_util.dart` to support new handler annotations.
- Fixed method string generation in `handler_generator.dart` to use `Handler`.
- Renamed `_processResult` to `handleResult` in `handler_utils.dart`.
- Exported `Request` and `Response` from `shelf` in `xserver.dart`.

### Fixed
- Various improvements and bug fixes to ensure compatibility with the new handler design.

### Migration
- Updated handler design:
  - **Previous design**:
    ```dart
    import 'package:xserver/xserver.dart';

    final export = defineHandler((request) {
      return 'GET Hello!';
    });
    ```

  - **New design**:
    ```dart
    import 'package:shelf/shelf.dart';
    import 'package:xserver/xserver.dart';

    part 'get.g.dart';

    @get
    String get_(Request req) {
      return 'get';
    }
    ```

    ```dart
    import 'package:some_project/server/composables.dart';
    import 'package:xserver/xserver.dart';

    part 'auth.g.dart';

    @all
    Future<String> getUid(Request req) async {
      final auth = await useAuth();
      return auth.uid;
    }
    ```

You can specify multiple handlers in one file instead of using `[endpoint].[method].dart`.

## 0.1.0

- Initial release of xserver.
- Added basic server setup with request handling.
- Implemented automatic handler registration based on file structure.
- Added support for GET and POST methods.
- Included example usage and documentation.
