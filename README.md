# xserver

xserver is a Dart-based web server framework that leverages source generation for automatic handler registration, making it easier to manage and expand your web server's endpoints.

## Features

- **Automatic Handler Registration**: Utilize annotations to auto-register handlers.
- **Flexible Response Types**: Return various response types including `Future<T>`, `Stream<T>`, and more.
- **Type-safe Parameter Handling**: Use annotations to handle query parameters, body, headers, and path parameters.
- **Client Generation**: Automatically generate client code for easy API consumption.
- **Async Context Management**: Access the current request context asynchronously with `XServer.currentRequest`.

## Getting Started

### Installation

Add xserver as a dependency in your `pubspec.yaml`:

```yaml
dependencies:
  xserver: ^0.2.0
```

Run `pub get` to install the package.

### Usage

#### Define the Server

Create a class for your server and annotate it with `@xServer`.

```dart
import 'package:xserver/xserver.dart';

part 'app_server.g.dart';

@xServer
class AppServer extends _$AppServer {
}
```

#### Define Handlers

Define your handlers within the `AppServer` class. Use annotations to specify the HTTP method and path.

```dart
@xServer
class AppServer extends _$AppServer {
  @get
  Future<String> test({
    @query required String query,
    @body required Data body,
    @query required int query2,
    @header required String header,
    @header required int header2,
  }) async {
    return 'test';
  }

  @Get('/user/<id>')
  Future<String> user(@path String id) async {
    return 'User: $id';
  }

  @Post('/data')
  Future<Data> data() async {
    return const Data(
      query: 'query',
      body: 'body',
      query2: 1,
      header: 'header',
      header2: 2,
    );
  }

  @Get('/stream')
  Stream<String> stream() async* {
    for (var i = 0; i < 100; i++) {
      yield 'stream $i';
      await Future.delayed(const Duration(seconds: 1));
    }
  }
}
```

#### Generate Handlers

Run the build command to generate the handler registration code:

```bash
dart run build_runner build
```

#### Start the Server

You can start the server in your main function:

```dart
import 'package:xserver/xserver.dart';

void main() async {
  final server = AppServer();
  await server.start('localhost', 8080);
  print('Server listening on port 8080');
}
```

## Handler Annotations

- `@All(path)`: Handles all HTTP methods
- `@Get(path)`: Handles GET requests
- `@Post(path)`: Handles POST requests

## Parameter Annotations

- `@Query([name])`: Extracts query parameters. If name is omitted, uses the parameter name.
- `@Body()`: Extracts the request body
- `@Header([name])`: Extracts headers. If name is omitted, uses the parameter name.
- `@Path([name])`: Extracts path parameters. If name is omitted, uses the parameter name.

## Response Types

Handlers can return various types:

- `Future<T>`: For asynchronous responses
- `Stream<T>`: For server-sent events or streaming responses
- `T`: For synchronous responses (will be automatically wrapped in a Future)

Where `T` can be:

- `String`: For text responses
- `Map<String, dynamic>`: For JSON responses
- Custom classes with `toJson()` method: Will be serialized to JSON

## Client Generation

The generator also creates a client class that can be used to make requests to your server:

```dart
final client = AppServerClient('http://localhost:8080');
final result = await client.test(
  query: 'example',
  body: Data(...),
  query2: 42,
  header: 'some-header',
  header2: 123
);
print(result);
```

This client handles serialization and deserialization of requests and responses, making it easy to interact with your server from other parts of your application.

## Async Context Management

xserver uses zoned contexts to manage asynchronous requests. You can access the current request at any time without passing it explicitly:

```dart
import 'package:xserver/xserver.dart';

@Get('/example')
Future<String> exampleHandler() async {
  final currentRequest = XServer.currentRequest;
  // Use the currentRequest as needed
  return 'Handled asynchronously!';
}
```

## Documentation

Detailed documentation and examples can be found in the documentation directory.

## Contributing

Contributions are welcome! Please read our contributing guide to get started.

## License

This project is licensed under the MIT License. See the LICENSE file for details.