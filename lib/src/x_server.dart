import 'dart:async';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

abstract base class XServerBase {
  static const Symbol _requestSymbol = #_currentRequest;

  final Router router = Router();

  XServerBase() {
    _setupRoutes();
  }

  void registerHandlers(Router router);

  void _setupRoutes() {
    registerHandlers(router);
  }

  Future<Response> handle(Request request) async {
    return runZoned(
      () => router(request),
      zoneValues: {_requestSymbol: request},
    );
  }

  static Request get currentRequest {
    final request = Zone.current[_requestSymbol] as Request?;
    if (request == null) {
      throw StateError('No request found in current Zone. '
          'Ensure this is called within a request handler.');
    }
    return request;
  }
}
