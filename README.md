# xserver

`xserver` is a Dart-based web server framework that leverages source generation for automatic handler registration, making it easier to manage and expand your web server's endpoints.

## Features

- **Automatic Handler Registration**: Utilize file structure conventions to auto-register handlers.
- **Flexible Response Types**: Return various response types including `Response`, `String`, `Stream`, `Map`, and more.
- **Nested Routes**: Support for nested routes and dynamic parameters.
- **Async Context Management**: Access the current request context asynchronously with `XServer.currentRequest`.

## Getting Started

### Installation

Add `xserver` as a dependency in your `pubspec.yaml`:

```yaml
dependencies:
  xserver: ^0.1.3
```

Run `pub get` to install the package.

### Usage

1. **Define the Server**:

   Create a class for your server and annotate it with `@XServer`, specifying the root directory for your handlers.

   ```dart
   import 'package:xserver/xserver.dart';

   @XServer('server')
   final class AppServer extends _$AppServer {
   }
   ```

2. **Organize Handlers**:

   Organize your handlers according to the file structure. Handlers should be placed in the directory specified in `@XServer`.

   For example:

   ```plaintext
   ./server/hello.dart
   ./server/get.get.dart
   ./server/get.post.dart
   ./server/nested/hello.dart
   ./server/[id].dart
   ./server/nested/index.dart
   ```

3. **Define Handlers**:

   Define your handlers in the respective files.

   **`./server/hello.dart`**:
   ```dart
   import 'package:xserver/xserver.dart';

   part 'hello.g.dart';
 
   @all
   String hello(Request req) {
     return 'Hello';
   }
   ```

   **`./server/multiple.dart`**:
   ```dart
   import 'package:xserver/xserver.dart';

   part 'multiple.g.dart';
 
   @get
   String get_(Request req) {
     return 'get';
   }
   
   @post
   String post_(Request req) {
     return 'post';
   }
   ```

   **`./server/nested/hello.dart`**:
   ```dart
   import 'package:xserver/xserver.dart';

   part 'hello.g.dart';
 
   @all
   String hello(Request req) {
     return 'Nested Hello';
   }
   ```

   **`./server/[id].dart`**:
   ```dart
   import 'package:xserver/xserver.dart';

   part 'id.g.dart'; 

   @all
   String id(Request req) {
     final id = req.params['id'];
     return 'Hello, $id!';
   }
   ```

   **`./server/nested/index.dart`**:
   ```dart
   import 'package:xserver/xserver.dart';
   
   part 'index.g.dart';  
   @all
   String index(Request req) {
     return 'Nested Index';
   }
   ```

4. **Generate Handlers**:

   Run the build command to generate the handler registration code:

   ```shell
   dart run build_runner build
   ```

5. **Start the Server**:

   You can start the server directly using the `start` method:

   ```dart
   import 'package:xserver/xserver.dart';

   void main() async {
     await AppServer.start('localhost', 8080);
     print('Server listening on port 8080');
   }
   ```

   Or use it as a router:

   ```dart
   import 'package:xserver/xserver.dart';
   import 'package:shelf/shelf.dart';
   import 'package:shelf/shelf_io.dart' as io;

   void main() async {
     final handler = const Pipeline()
         .addMiddleware(logRequests())
         .addHandler(AppServer.handle);

     final server = await io.serve(handler, 'localhost', 8080);
     print('Server listening on port ${server.port}');
   }
   ```

### Response Types

The `defineHandler` function can return various types, and `xserver` will handle them appropriately:

- `Response`: Directly return a `shelf` response.
- `String`: Return a string as a plain text response.
- `Stream<Map<String, dynamic>>`: Handle server-sent events with JSON streams.
- `Stream<String>`: Handle server-sent events with string streams.
- `Stream<List<int>>`: Handle binary streams.
- `Map<String, dynamic>`: Return a JSON map.
- `List<int>`: Return a binary list.
- `List<String>`: Return a list of strings joined by newline.
- `null`: Return an empty response.
- Any other type: Return as JSON encodable.

### Async Context Management

`xserver` uses zoned contexts to manage asynchronous requests. You can access the current request at any time without passing it explicitly:

```dart
import 'package:xserver/xserver.dart';

final export = defineHandler((request) async {
  final currentRequest = XServer.currentRequest;
  // Use the currentRequest as needed
  return 'Handled asynchronously!';
});
```

## Documentation

Detailed documentation and examples can be found in the [documentation](docs/) directory.

## Contributing

Contributions are welcome! Please read our [contributing guide](CONTRIBUTING.md) to get started.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
