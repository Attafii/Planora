import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/services/storage_service.dart';
import '../features/goals/data/goal_repository.dart';
import '../features/collaboration/data/collaboration_repository.dart';
import '../features/assistant/data/assistant_repository.dart';
import '../features/gamification/data/gamification_repository.dart';

class AuthUser {
  AuthUser.fromJson(JsonMap d)
    : id = d['id'] as String,
      name = d['name'] as String,
      email = d['email'] as String,
      timezone = d['timezone'] as String;
  final String id, name, email, timezone;
}

class AppSession extends ChangeNotifier {
  AppSession(this.api, this.tokens) {
    api.onUnauthorized = _expired;
  }
  final ApiClient api;
  final TokenStore tokens;
  AuthUser? user;
  bool loading = true;
  String? error;
  Future<void> initialize() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      api.token = await tokens.read();
      if (api.token != null) {
        user = AuthUser.fromJson(await api.get('/auth/me'));
      }
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> authenticate({
    required String email,
    required String password,
    String? name,
  }) async {
    final d = await api.post(name == null ? '/auth/login' : '/auth/register', {
      'email': email.trim(),
      'password': password,
      if (name != null) 'name': name.trim(),
    });
    final token = d['token'] as String;
    await tokens.write(token);
    api.token = token;
    user = AuthUser.fromJson(d['user'] as JsonMap);
    error = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    await api.post('/auth/logout');
    await tokens.clear();
    api.token = null;
    user = null;
    notifyListeners();
  }

  void _expired() {
    api.token = null;
    user = null;
    error = 'Your session expired. Please sign in again.';
    tokens.clear();
    notifyListeners();
  }
}

class AppServices {
  AppServices({ApiClient? client, TokenStore? tokens})
    : api = client ?? ApiClient() {
    session = AppSession(api, tokens ?? SecureTokenStore());
    goals = GoalRepository(api);
    collaboration = CollaborationRepository(api);
    assistant = AssistantRepository(api);
    gamification = GamificationRepository(api);
  }
  final ApiClient api;
  late final AppSession session;
  late final GoalRepository goals;
  late final CollaborationRepository collaboration;
  late final AssistantRepository assistant;
  late final GamificationRepository gamification;
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});
  final AppServices services;
  static AppServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.services;
  @override
  bool updateShouldNotify(AppScope oldWidget) => oldWidget.services != services;
}
