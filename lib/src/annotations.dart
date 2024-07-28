import 'dart:async';

import 'package:shelf/shelf.dart';
export 'package:shelf_router/shelf_router.dart';

// Re-export XServer base class
export 'x_server.dart';

/// Annotation for XServer classes
class XServer {
  static const Symbol requestSymbol = #_currentRequest;

  static Request get currentRequest {
    final request = Zone.current[requestSymbol] as Request?;
    if (request == null) {
      throw StateError('No request found in current Zone. '
          'Ensure this is called within a request handler.');
    }
    return request;
  }

  final String basePath;

  const XServer(this.basePath);
}

// You might want to include some commonly used types here for convenience
typedef HandlerFunction<T> = FutureOr<Response> Function(Request request);
