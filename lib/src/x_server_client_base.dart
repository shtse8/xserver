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
  final String baseUrl;
  final Client _client = Client();
  final Map<String, String> defaultHeaders;

  XServerClientBase(
    this.baseUrl, {
    this.defaultHeaders = const {},
  });

  Future<StreamedResponse> _sendRequest(
    String method,
    String path, {
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
    dynamic body,
    Map<String, String>? headers,
  }) async {
    var updatedPath = path;
    if (pathParams != null) {
      pathParams.forEach((key, value) {
        updatedPath = updatedPath.replaceAll('<$key>', value.toString());
      });
    }

    final uri =
        Uri.parse('$baseUrl$updatedPath').replace(queryParameters: queryParams);
    final request = Request(method.toUpperCase(), uri);

    final combinedHeaders = {...defaultHeaders, ...?headers};
    request.headers.addAll(combinedHeaders);

    if (body != null) {
      request.headers[HttpHeaders.contentTypeHeader] = 'application/json';
      request.body = json.encode(body);
    }

    log('Sending request: ${request.method} ${request.url} ${request.headers}');
    final response = await _client.send(request);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Request failed with status: ${response.statusCode}');
    }

    return response;
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

    final eventStream = _parseSSEStream(response.stream);

    await for (final sseResponse in eventStream) {
      switch (sseResponse) {
        case SSEResponseNext(data: var eventData):
          yield parseResponse(eventData);
        case SSEResponseError(message: var errorMessage):
          throw Exception(errorMessage);
        case SSEResponseComplete():
          return; // End the stream
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

        if (eventMap.containsKey('event')) {
          switch (eventMap['event']) {
            case 'error':
              yield SSEResponse.error(eventMap['data'] ?? 'Unknown error');
            case 'complete':
              yield SSEResponse.complete();
              return;
            default:
              if (eventMap.containsKey('data')) {
                yield SSEResponse.next(eventMap['data']!);
              }
          }
        } else if (eventMap.containsKey('data')) {
          yield SSEResponse.next(eventMap['data']!);
        }
      }
    }
  }

  void dispose() {
    _client.close();
  }
}
