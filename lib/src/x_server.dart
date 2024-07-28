import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:xserver/xserver.dart';

abstract base class XServerBase {
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
      zoneValues: {XServer.requestSymbol: request},
    );
  }

  FutureOr<Response> call(Request request) => handle(request);

  Future<HttpServer> start(
    Object address,
    int port, {
    SecurityContext? securityContext,
    int? backlog,
    bool shared = false,
    String? poweredByHeader = 'Dart with package:shelf',
  }) {
    var handler =
        const Pipeline().addMiddleware(logRequests()).addHandler(handle);
    return serve(
      handler,
      address,
      port,
      securityContext: securityContext,
      backlog: backlog,
      shared: shared,
      poweredByHeader: poweredByHeader,
    );
  }
}
