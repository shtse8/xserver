import 'dart:async';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:xserver/xserver.dart';

class CustomHandler<T> {
  final HandlerFunction<T> handler;
  const CustomHandler(this.handler);
}

HandlerFunction<T> _getResponse<T>(
    FutureOr<T> Function(Request request) handler) {
  return (Request request) async {
    try {
      final result = await handler(request);
      return handleResult(result);
    } catch (e, stackTrace) {
      print('Error in handler: $e');
      print('Stack trace: $stackTrace');
      return Response.internalServerError(
        body: json.encode({
          'error': 'Internal Server Error',
          'message': e.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  };
}

Response handleResult<T>(T result) => switch (result) {
      Response() => result,
      String() => Response.ok(result),
      Stream<Map<String, dynamic>>() => _handleSSE(result.map(json.encode)),
      Stream<String>() => _handleSSE(result),
      Stream<List<int>>() => _handleBinaryStream(result),
      Map<String, dynamic>() => _handleJsonMap(result),
      List<int>() => _handleBinaryList(result),
      List<String>() => Response.ok(result.join('\n')),
      null => Response.ok(''),
      _ => _handleJsonEncodable(result),
    };

Response _handleBinaryStream(Stream<List<int>> stream) {
  return Response.ok(
    stream,
    headers: {
      'Content-Type': 'application/octet-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    },
    context: {'shelf.io.buffer_output': false},
  );
}

Response _handleJsonMap(Map<String, dynamic> map) {
  return Response.ok(
    json.encode(map),
    headers: {'Content-Type': 'application/json'},
  );
}

Response _handleBinaryList(List<int> data) {
  return Response.ok(
    data,
    headers: {'Content-Type': 'application/octet-stream'},
  );
}

Response _handleJsonEncodable(dynamic data) {
  return Response.ok(
    json.encode(data),
    headers: {'Content-Type': 'application/json'},
  );
}

Response _handleSSE(Stream<String> input) {
  final controller = StreamController<List<int>>();

  input.listen(
    (event) => controller.add(utf8.encode('data: $event\n\n')),
    onError: (error) => controller.add(utf8
        .encode('event: error\ndata: ${json.encode(error.toString())}\n\n')),
    onDone: () {
      controller.add(utf8.encode('event: complete\ndata: null\n\n'));
      controller.close();
    },
  );

  return Response.ok(
    controller.stream,
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    },
    context: {'shelf.io.buffer_output': false},
  );
}

CustomHandler<T> defineHandler<T>(
    FutureOr<T> Function(Request request) handler) {
  return CustomHandler(_getResponse(handler));
}
