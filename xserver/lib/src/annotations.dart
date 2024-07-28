import 'dart:async';

import 'package:shelf/shelf.dart';
export 'package:shelf_router/shelf_router.dart';

// Re-export XServer base class
export 'x_server.dart';

/// Annotation for XServer classes
class XServer {
  const XServer();
}

// You might want to include some commonly used types here for convenience
typedef HandlerFunction<T> = FutureOr<Response> Function(Request request);
