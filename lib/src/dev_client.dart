import 'package:xserver/src/annotations.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:http/http.dart' as http;

class DevClient extends BaseClient {
  final XServerBase _server;

  DevClient(this._server);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final shelfRequest = _convertToShelfRequest(request);
    final shelfResponse = await _server.handle(shelfRequest);
    return _convertToHttpResponse(shelfResponse);
  }

  shelf.Request _convertToShelfRequest(http.BaseRequest request) {
    return shelf.Request(
      request.method,
      request.url,
      headers: request.headers,
      body: request.finalize(),
    );
  }

  http.StreamedResponse _convertToHttpResponse(shelf.Response response) {
    return http.StreamedResponse(
      response.read(),
      response.statusCode,
      headers: response.headers,
      contentLength: response.contentLength,
    );
  }
}
