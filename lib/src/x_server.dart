import 'dart:async';
import 'package:xserver/src/x_server_context.dart';
import 'package:xserver/xserver.dart';

abstract class XServerBase {
  Router get router;

  FutureOr<Response> call(Request request) => XServerContext.createZone(
        request,
        router,
      );
}
