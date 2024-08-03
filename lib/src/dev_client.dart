import 'package:xserver/src/annotations.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:http/http.dart' as http;

class DevClient extends BaseClient {
  final XServerBase _server;

  DevClient(this._server);

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final shelfRequest = shelf.Request(
      request.method,
      request.url,
      headers: request.headers,
      body: request.finalize(),
    );
    final response = await _server.handle(shelfRequest);
    return http.StreamedResponse(
      response.read(),
      response.statusCode,
      headers: response.headers,
    );
  }
}
