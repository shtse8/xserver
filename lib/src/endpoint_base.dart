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

abstract class EndpointBase {
  final String baseUrl;
  final Client _client = Client();
  final Map<String, String> defaultHeaders;

  EndpointBase(
    this.baseUrl, {
    this.defaultHeaders = const {},
  });

  String get path;

  Future<StreamedResponse> _sendRequest(
    String method, {
    Map<String, dynamic>? query,
    dynamic data,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final request = Request(method.toUpperCase(), uri);

    // Combine default headers with request-specific headers
    final combinedHeaders = {...defaultHeaders, ...?headers};
    request.headers.addAll(combinedHeaders);

    request.headers[HttpHeaders.acceptHeader] = 'text/event-stream';
    log('Sending request: ${request.headers}');
    if (data != null) {
      request.headers[HttpHeaders.contentTypeHeader] = 'application/json';
      request.body = json.encode(data);
    }

    final response = await _client.send(request);

    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Failed to load data: ${response.statusCode}');
    }

    return response;
  }

  Future<T> request<T>(
    String method, {
    Map<String, dynamic>? query,
    dynamic data,
    Map<String, String>? headers,
    required T Function(String) parseResponse,
  }) async {
    final response =
        await _sendRequest(method, query: query, data: data, headers: headers);
    final responseBody = await response.stream.bytesToString();
    return parseResponse(responseBody);
  }

  Stream<T> eventSourceRequest<T>(
    String method, {
    Map<String, dynamic>? query,
    dynamic data,
    Map<String, String>? headers,
    required T Function(String) parseResponse,
  }) async* {
    final response =
        await _sendRequest(method, query: query, data: data, headers: headers);
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
    // ... (rest of the _parseSSEStream method remains unchanged)
  }

  void dispose() {
    _client.close();
  }
}
