# Changelog

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
