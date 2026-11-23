import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
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

class AppSession extends ChangeNotifier {
  final http.Client client;
  final FlutterSecureStorage storage;
  final String baseUrl;
  Account? account;
  bool restoring = true;
  String? restoreError;
  String? sessionMessage;
  bool secureClearFailed = false;
  String? _token;
  String? get accessToken => _token;
  DateTime? _expires;
  Timer? _expiry;
  Future<void>? _restoring;
  Future<void> _storageWrites = Future.value();
  Map<String, dynamic>? _profile;
  int _generation = 0;
  int _profileChange = 0;
  int _profileEdits = 0;
  bool _disposed = false;

  static const tokenKey = 'planify.session';
  static const ended = 'Your session has ended. Please sign in again.';

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
    final expiry = _expires;
    if (path != '/auth/logout' &&
        expiry != null &&
        !expiry.isAfter(DateTime.now())) {
      await invalidateSession();
      throw const ApiFailure(ended, status: 401);
    }
    final generation = _generation;
    final token = _token;
    final publicAuth =
        path == '/auth/register' ||
        path == '/auth/login' ||
        path.startsWith('/auth/password-reset');
    try {
      final req = http.Request(method, Uri.parse('$baseUrl$path'));
      req.headers['Content-Type'] = 'application/json';
      if (token != null && !publicAuth) {
        req.headers['Authorization'] = 'Bearer $token';
      }
      if (body != null) req.body = jsonEncode(body);
      final response = await client
          .send(req)
          .then(http.Response.fromStream)
          .timeout(Duration(seconds: path.endsWith('-assist') ? 75 : 10));
      if (path != '/auth/logout' && (_disposed || generation != _generation)) {
        throw const ApiFailure(ended, status: 401);
      }
      if (response.statusCode == 401 &&
          token != null &&
          !publicAuth &&
          path != '/auth/logout') {
        await invalidateSession();
        throw const ApiFailure(ended, status: 401);
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
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
    } on http.ClientException {
      throw const ApiFailure(
        'Could not connect to Planify. Check your connection and try again.',
      );
    } on FormatException {
      throw const ApiFailure(
        'Planify returned an unreadable response.',
        status: 502,
      );
    } on TypeError {
      throw const ApiFailure(
        'Planify returned an invalid response.',
        status: 502,
      );
    }
  }

  Future<void> restore() => _restoring ??= _restore().whenComplete(() {
    _restoring = null;
  });

  Future<void> _restore() async {
    final generation = _generation;
    restoring = true;
    restoreError = null;
    notifyListeners();
    try {
      await _storageWrites;
      final saved = await storage.read(key: tokenKey);
      if (_disposed || generation != _generation || saved == null) return;
      final data = jsonDecode(saved) as Map<String, dynamic>;
      final expiry = DateTime.parse(data['expires_at'] as String);
      if (!expiry.isAfter(DateTime.now())) {
        await invalidateSession();
        return;
      }
      if (data['server'] != null && data['server'] != baseUrl) {
        await _clear();
        return;
      }
      _token = data['token'] as String;
      _schedule(expiry);
      if (data['server'] == baseUrl && data['user'] is Map<String, dynamic>) {
        _profile = data['user'] as Map<String, dynamic>;
        account = Account.fromJson(_profile!);
        // Verify promptly online while allowing the device copy to open when
        // the server cannot be reached. A late 401 still ends the session.
        try {
          await refreshAccount().timeout(const Duration(seconds: 2));
        } on TimeoutException {
          // The outstanding request continues to check the session.
        } on ApiFailure {
          // With a valid cached session, connection failures keep it usable.
        }
        return;
      }
      await refreshAccount();
    } on ApiFailure catch (error) {
      if (error.status != 401) restoreError = error.message;
    } on FormatException {
      await _clear();
    } catch (_) {
      restoreError = 'Could not open secure session storage. Try again.';
    } finally {
      restoring = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<String> _registrationTimezone() async {
    try {
      final zone = await FlutterTimezone.getLocalTimezone().timeout(
        const Duration(seconds: 2),
      );
      if (tz.timeZoneDatabase.locations.containsKey(zone.identifier)) {
        return zone.identifier;
      }
    } catch (_) {
      // Some hosts expose no usable IANA zone.
    }
    return 'UTC';
  }

  Future<void> authenticate({
    required bool register,
    required String email,
    required String password,
    String? name,
  }) async {
    final generation = ++_generation;
    final timezone = register ? await _registrationTimezone() : null;
    if (_disposed || generation != _generation) return;
    final data = await request(
      'POST',
      register ? '/auth/register' : '/auth/login',
      {
        'email': email.trim(),
        'password': password,
        if (register) ...{
          'name': name!.trim(),
          'timezone': timezone,
          'language': 'en',
        },
      },
    );
    final profile = data['user'] as Map<String, dynamic>;
    final user = Account.fromJson(profile);
    final expiry = DateTime.parse(data['expires_at'] as String);
    final token = data['token'] as String;
    try {
      await _save(token, expiry, profile);
    } catch (_) {
      throw const ApiFailure(
        'Secure storage is unavailable. Please enable device storage and try again.',
      );
    }
    if (_disposed || generation != _generation) return;
    _token = token;
    _profile = profile;
    account = user;
    sessionMessage = null;
    secureClearFailed = false;
    restoreError = null;
    _schedule(expiry);
    notifyListeners();
  }

  void _schedule(DateTime until) {
    _expires = until;
    _expiry?.cancel();
    _expiry = Timer(until.difference(DateTime.now()), () {
      unawaited(invalidateSession());
    });
  }

  Future<void> _secureWrite(Future<void> Function() operation) {
    final write = _storageWrites.then((_) => operation());
    _storageWrites = write.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return write;
  }

  Future<void> _save(
    String token,
    DateTime expires,
    Map<String, dynamic> profile,
  ) => _secureWrite(
    () => storage.write(
      key: tokenKey,
      value: jsonEncode({
        'token': token,
        'expires_at': expires.toIso8601String(),
        'server': baseUrl,
        'user': profile,
      }),
    ),
  );

  Future<void> invalidateSession() => _clear(message: ended);

  Future<void> retryLocalSignOut() => _clear();

  Future<void> _clear({String? message}) async {
    final generation = ++_generation;
    _expiry?.cancel();
    _expires = null;
    _token = null;
    _profile = null;
    account = null;
    sessionMessage = message;
    secureClearFailed = false;
    restoreError = null;
    final deletion = _secureWrite(() => storage.delete(key: tokenKey));
    if (!_disposed) notifyListeners();
    try {
      await deletion;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      secureClearFailed = true;
      sessionMessage =
          'Planify could not clear the saved session from this device.';
      notifyListeners();
    }
  }

  Future<bool> signOut() async {
    final revocation = _token == null
        ? Future.value(false)
        : request(
            'POST',
            '/auth/logout',
            {},
          ).then((_) => true, onError: (Object _, StackTrace _) => false);
    await _clear();
    final generation = _generation;
    final revoked = await revocation;
    if (!revoked &&
        !_disposed &&
        generation == _generation &&
        sessionMessage == null) {
      sessionMessage =
          'Signed out on this device. Server sign-out could not be confirmed.';
      notifyListeners();
    }
    return revoked;
  }

  Future<void> refreshAccount() async {
    if (_token == null || _profileEdits != 0) return;
    final version = _profileChange;
    final profile = await request('GET', '/users/me');
    if (_profileChange == version) await _updateAccount(profile);
  }

  Future<void> saveProfile(String name) =>
      _patchAccount('/users/me', {'name': name});

  Future<void> savePreferences(Map<String, dynamic> changes) =>
      _patchAccount('/users/me/preferences', changes);

  Future<void> _patchAccount(String path, Map<String, dynamic> changes) async {
    _profileChange++;
    _profileEdits++;
    try {
      await _updateAccount(await request('PATCH', path, changes));
    } finally {
      _profileEdits--;
    }
  }

  Future<void> _updateAccount(Map<String, dynamic> profile) async {
    final token = _token;
    final expires = _expires;
    if (_disposed || jsonEncode(profile) == jsonEncode(_profile)) {
      return;
    }
    final user = Account.fromJson(profile);
    if (account != null && account!.id != user.id) {
      await invalidateSession();
      throw const ApiFailure(ended, status: 401);
    }
    final generation = _generation;
    try {
      if (token != null && expires != null) {
        await _save(token, expires, profile);
      }
    } catch (_) {
      // The server accepted the change. Keep the live profile authoritative.
    }
    if (_disposed || generation != _generation) return;
    _profile = profile;
    account = user;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _expiry?.cancel();
    client.close();
    super.dispose();
  }
}
