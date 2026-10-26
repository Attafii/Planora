import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiFailure implements Exception {
  final String message;
  final Map<String, dynamic> fields;
  final int status;
  const ApiFailure(this.message, {this.fields = const {}, this.status = 0});
  @override
  String toString() => message;
}

class Account {
  final String id, name, email, timezone, language, theme;
  final bool emailVerified, cloudAi;
  Account.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      name = json['name'] as String,
      email = json['email'] as String,
      timezone = json['timezone'] as String,
      language = json['language'] as String,
      emailVerified = json['email_verified_at'] != null,
      theme = json['preferences']['theme'] as String,
      cloudAi = json['preferences']['cloud_ai'] == true;
}

/// Shared identity, timezone and AI-consent source for all feature owners.
/// All authenticated feature requests must use [request].
class AppSession extends ChangeNotifier {
  final http.Client client;
  final FlutterSecureStorage storage;
  final String baseUrl;
  Account? account;
  bool restoring = true;
  String? restoreError;
  String? _token;
  Timer? _expiry;
  static const tokenKey = 'planify.session';
  AppSession({
    http.Client? client,
    FlutterSecureStorage? storage,
    String? baseUrl,
  }) : client = client ?? http.Client(),
       storage = storage ?? const FlutterSecureStorage(),
       baseUrl =
           baseUrl ??
           const String.fromEnvironment(
             'API_BASE_URL',
             defaultValue: 'http://localhost:3000',
           );

  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    try {
      final req = http.Request(method, Uri.parse('$baseUrl$path'));
      req.headers['Content-Type'] = 'application/json';
      if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
      if (body != null) req.body = jsonEncode(body);
      final streamed = await client
          .send(req)
          .timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        if (response.statusCode == 401 && path.startsWith('/users/')) {
          await _clear();
        }
        final error = data['error'] as Map<String, dynamic>;
        throw ApiFailure(
          error['message'] as String,
          fields: (error['fields'] as Map<String, dynamic>?) ?? {},
          status: response.statusCode,
        );
      }
      return data;
    } on ApiFailure {
      rethrow;
    } on TimeoutException {
      throw const ApiFailure('The connection took too long. Please try again.');
    } catch (_) {
      throw const ApiFailure(
        'Could not connect to Planify. Check your connection and try again.',
      );
    }
  }

  Future<void> restore() async {
    restoring = true;
    restoreError = null;
    notifyListeners();
    try {
      final saved = await storage.read(key: tokenKey);
      if (saved != null) {
        final data = jsonDecode(saved) as Map<String, dynamic>;
        final expiry = DateTime.parse(data['expires_at'] as String);
        if (!expiry.isAfter(DateTime.now())) {
          await _clear();
        } else {
          _token = data['token'] as String;
          account = Account.fromJson(await request('GET', '/users/me'));
          _schedule(expiry);
        }
      }
    } on ApiFailure catch (e) {
      if (e.status != 401) restoreError = e.message;
    } catch (_) {
      await _clear();
    }
    restoring = false;
    notifyListeners();
  }

  Future<void> authenticate({
    required bool register,
    required String email,
    required String password,
    String? name,
  }) async {
    final data = await request(
      'POST',
      register ? '/auth/register' : '/auth/login',
      {
        'email': email.trim(),
        'password': password,
        if (register) ...{
          'name': name!.trim(),
          'timezone': 'Africa/Tunis',
          'language': 'en',
        },
      },
    );
    try {
      await storage.write(
        key: tokenKey,
        value: jsonEncode({
          'token': data['token'],
          'expires_at': data['expires_at'],
        }),
      );
    } catch (_) {
      _token = data['token'] as String;
      try {
        await request('POST', '/auth/logout', {});
      } catch (_) {}
      _token = null;
      throw const ApiFailure(
        'Secure storage is unavailable. Please enable device storage and try again.',
      );
    }
    _token = data['token'] as String;
    account = Account.fromJson(data['user'] as Map<String, dynamic>);
    _schedule(DateTime.parse(data['expires_at'] as String));
    notifyListeners();
  }

  void _schedule(DateTime until) {
    _expiry?.cancel();
    _expiry = Timer(until.difference(DateTime.now()), () {
      unawaited(_clear());
    });
  }

  Future<void> _clear() async {
    _expiry?.cancel();
    _token = null;
    account = null;
    notifyListeners();
    await storage.delete(key: tokenKey);
  }

  Future<bool> signOut() async {
    bool revoked = true;
    try {
      await request('POST', '/auth/logout', {});
    } catch (_) {
      revoked = false;
    } finally {
      await _clear();
    }
    return revoked;
  }

  Future<void> saveProfile(String name) async {
    account = Account.fromJson(
      await request('PATCH', '/users/me', {'name': name}),
    );
    notifyListeners();
  }

  Future<void> savePreferences(Map<String, dynamic> changes) async {
    account = Account.fromJson(
      await request('PATCH', '/users/me/preferences', changes),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _expiry?.cancel();
    client.close();
    super.dispose();
  }
}
