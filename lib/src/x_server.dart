import 'dart:async';

import 'package:shelf/shelf.dart';
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
}
