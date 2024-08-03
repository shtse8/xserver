import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:http/http.dart';

sealed class SSEResponse {
  factory SSEResponse.next(String data) = SSEResponseNext;
  factory SSEResponse.error(String message) = SSEResponseError;
  factory SSEResponse.complete() = SSEResponseComplete;
}

final class SSEResponseNext implements SSEResponse {
  final String data;
  SSEResponseNext(this.data);
}

final class SSEResponseError implements SSEResponse {
  final String message;
  SSEResponseError(this.message);
}

final class SSEResponseComplete implements SSEResponse {}

abstract class XServerClientBase {
  final Client _client;
  final Map<String, String> _headers;
  final String _baseUrl;

  XServerClientBase(this._baseUrl,
      {Client? client, Map<String, String>? headers})
      : _client = client ?? Client(),
        _headers = headers ?? {};

  Future<StreamedResponse> _sendRequest(
    String method,
    String path, {
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
    dynamic body,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, pathParams, queryParams);
    final request = Request(method.toUpperCase(), uri);

    request.headers.addAll(_headers);
    if (headers != null) request.headers.addAll(headers);

    if (body != null) {
      request.headers[HttpHeaders.contentTypeHeader] = 'application/json';
      request.body = json.encode(body);
    }

    final response = await _client.send(request);
    _logRequest(request, response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Request failed with status: ${response.statusCode}');
    }

    return response;
  }

  Uri _buildUri(String path, Map<String, dynamic>? pathParams,
      Map<String, dynamic>? queryParams) {
    var updatedPath = path;
    if (pathParams != null) {
      for (var entry in pathParams.entries) {
        final placeholder = RegExp('{${entry.key}(?::([^}]+))?}');
        updatedPath = updatedPath.replaceAllMapped(placeholder, (match) {
          final value = entry.value.toString();
          final constraint = match.group(1);
          if (constraint != null) {
            // Here you could add validation based on the constraint
            // For now, we'll just return the value
          }
          return Uri.encodeComponent(value);
        });
      }
    }
    return Uri.parse('$_baseUrl$updatedPath')
        .replace(queryParameters: queryParams);
  }

  void _logRequest(Request request, StreamedResponse response) {
    print('Request: ${request.method} ${request.url}');
    print('Headers: ${request.headers}');
    print('Response status: ${response.statusCode}');
  }

  Future<T> request<T>(
    String method,
    String path, {
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
    dynamic body,
    Map<String, String>? headers,
    required T Function(String) parseResponse,
  }) async {
    final response = await _sendRequest(
      method,
      path,
      pathParams: pathParams,
      queryParams: queryParams,
      body: body,
      headers: headers,
    );
    final responseBody = await response.stream.bytesToString();
    return parseResponse(responseBody);
  }

  Stream<T> eventSourceRequest<T>(
    String method,
    String path, {
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
    dynamic body,
    Map<String, String>? headers,
    required T Function(String) parseResponse,
  }) async* {
    headers = {...?headers, 'Accept': 'text/event-stream'};
    final response = await _sendRequest(
      method,
      path,
      pathParams: pathParams,
      queryParams: queryParams,
      body: body,
      headers: headers,
    );

    await for (final sseResponse in _parseSSEStream(response.stream)) {
      switch (sseResponse) {
        case SSEResponseNext(data: var eventData):
          yield parseResponse(eventData);
        case SSEResponseError(message: var errorMessage):
          throw Exception(errorMessage);
        case SSEResponseComplete():
          return;
      }
    }
  }

  Stream<SSEResponse> _parseSSEStream(Stream<List<int>> byteStream) async* {
    String buffer = '';
    await for (final chunk in byteStream.transform(utf8.decoder)) {
      buffer += chunk;
      final events = buffer.split('\n\n');
      buffer = events.removeLast();

      for (final event in events) {
        final eventMap = _parseEventData(event);
        yield _createSSEResponse(eventMap);
      }
    }
  }

  Map<String, String> _parseEventData(String event) {
    final lines = event.split('\n');
    final eventMap = <String, String>{};

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final colonIndex = line.indexOf(':');
      if (colonIndex > 0) {
        final key = line.substring(0, colonIndex).trim();
        final value = line.substring(colonIndex + 1).trim();
        eventMap[key] = value;
      }
    }

    return eventMap;
  }

  SSEResponse _createSSEResponse(Map<String, String> eventMap) {
    if (eventMap.containsKey('event')) {
      switch (eventMap['event']) {
        case 'error':
          return SSEResponse.error(eventMap['data'] ?? 'Unknown error');
        case 'complete':
          return SSEResponse.complete();
        default:
          if (eventMap.containsKey('data')) {
            return SSEResponse.next(eventMap['data']!);
          }
      }
    } else if (eventMap.containsKey('data')) {
      return SSEResponse.next(eventMap['data']!);
    }
    throw Exception('Invalid SSE event format');
  }

  void dispose() {
    _client.close();
  }
}
