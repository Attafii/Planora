import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../errors/exceptions.dart';

typedef JsonMap = Map<String, dynamic>;

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl =
          (baseUrl ??
                  const String.fromEnvironment(
                    'API_BASE_URL',
                    defaultValue: '',
                  ))
              .isNotEmpty
          ? (baseUrl ?? const String.fromEnvironment('API_BASE_URL'))
                .replaceFirst(RegExp(r'/$'), '')
          : (!kIsWeb && defaultTargetPlatform == TargetPlatform.android
                ? 'http://10.0.2.2:4100'
                : 'http://127.0.0.1:4100');
  final http.Client _client;
  final String baseUrl;
  String? token;
  VoidCallback? onUnauthorized;

  Future<Object?> request(
    String method,
    String path, {
    JsonMap? body,
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 35),
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
      final request = http.Request(method, uri)
        ..headers.addAll({
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        });
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed)
          .timeout(timeout);
      final Object? data;
      try {
        data = jsonDecode(response.body);
      } on FormatException {
        throw const ApiException(
          'The server returned an unreadable response. Refresh to check the result.',
          status: 502,
        );
      }
      if (response.statusCode >= 400) {
        if (response.statusCode == 401 && token != null) onUnauthorized?.call();
        final error = data is JsonMap ? data['error'] as JsonMap? : null;
        throw ApiException(
          error?['message'] as String? ??
              'The request failed. Please try again.',
          status: response.statusCode,
          code: error?['code'] as String? ?? 'request_failed',
        );
      }
      return data;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        'The server took too long to respond. Refresh before retrying a change.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Cannot connect to Planify. Check your connection and API address, then retry.',
      );
    }
  }

  Future<JsonMap> get(String path, {Map<String, String>? query}) async =>
      (await request('GET', path, query: query)) as JsonMap;
  Future<List<JsonMap>> getList(String path) async =>
      ((await request('GET', path)) as List).cast<JsonMap>();
  Future<JsonMap> post(
    String path, [
    JsonMap body = const {},
    Duration timeout = const Duration(seconds: 35),
  ]) async =>
      (await request('POST', path, body: body, timeout: timeout)) as JsonMap;
  Future<JsonMap> patch(String path, JsonMap body) async =>
      (await request('PATCH', path, body: body)) as JsonMap;
  Future<void> delete(String path) async {
    await request('DELETE', path);
  }

  void close() => _client.close();
}
