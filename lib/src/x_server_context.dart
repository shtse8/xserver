import 'dart:async';

import 'package:shelf/shelf.dart';

class XServerContext {
  static const Symbol requestSymbol = #_currentRequest;

  static Request get currentRequest {
    final request = Zone.current[requestSymbol] as Request?;
    if (request == null) {
      throw StateError('No request found in current Zone. '
          'Ensure this is called within a request handler.');
    }
    return request;
  }

  static T createZone<T>(Request request, T Function(Request) callback) {
    return runZoned(
      () => callback(request),
      zoneValues: {requestSymbol: request},
    );
  }
}
