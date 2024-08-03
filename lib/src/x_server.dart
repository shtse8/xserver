import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:xserver/xserver.dart';

abstract class XServerBase {
  Router get router;

  Future<Response> handle(Request request) async {
    return runZoned(
      () => router(request),
      zoneValues: {XServer.requestSymbol: request},
    );
  }

  FutureOr<Response> call(Request request) => handle(request);
}
