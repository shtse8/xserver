import 'dart:async';
import 'package:meta/meta_meta.dart';

import 'package:shelf/shelf.dart';
export 'package:shelf_router/shelf_router.dart';
export 'package:http/http.dart' hide Request, Response;
export 'dart:convert';

// Re-export XServer base class
export 'x_server.dart';
export 'x_server_parser.dart';
export 'x_server_response_handler.dart';
export 'x_server_client_base.dart';
export 'composables.dart';
export 'dev_client.dart';

/// Annotation for XServer classes
@Target({TargetKind.classType})
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

  const XServer();
}

const xServer = XServer();

// You might want to include some commonly used types here for convenience
typedef HandlerFunction<T> = FutureOr<Response> Function(Request request);

@Target({TargetKind.method})
class All {
  final String path;
  const All(this.path);
}

@Target({TargetKind.method})
class Get {
  final String path;
  const Get(this.path);
}

@Target({TargetKind.method})
class Post {
  final String path;
  const Post(this.path);
}

@Target({TargetKind.parameter})
class Query {
  final String? name;
  const Query([this.name]);
}

@Target({TargetKind.parameter})
class Body {
  const Body();
}

@Target({TargetKind.parameter})
class Header {
  final String? name;
  const Header([this.name]);
}

@Target({TargetKind.parameter})
class Path {
  final String? name;
  const Path([this.name]);
}

const query = Query();
const header = Header();
const body = Body();
const path = Path();
