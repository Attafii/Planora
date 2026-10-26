import '../../../core/network/api_client.dart';

class Achievement {
  Achievement.fromJson(JsonMap d)
    : id = d['id'] as String,
      title = d['title'] as String,
      description = d['description'] as String,
      kind = d['kind'] as String,
      progress = (d['progress'] as num).toInt(),
      target = (d['target'] as num).toInt(),
      points = (d['points'] as num).toInt(),
      earned = d['earned'] == true,
      earnedAt = d['earned_at'] as String?;
  final String id, title, description, kind;
  final int progress, target, points;
  final bool earned;
  final String? earnedAt;
}

class GamificationSummary {
  GamificationSummary.fromJson(JsonMap d)
    : points = (d['points'] as num).toInt(),
      level = (d['level'] as num).toInt(),
      levelProgress = (d['level_progress'] as num).toInt(),
      streak = (d['streak'] as num).toInt(),
      streakRule = d['streak_rule'] as String,
      achievements = (d['achievements'] as List)
          .map((a) => Achievement.fromJson(a as JsonMap))
          .toList();
  final int points, level, levelProgress, streak;
  final String streakRule;
  final List<Achievement> achievements;
}

class Challenge {
  Challenge.fromJson(JsonMap d)
    : id = d['id'] as String,
      title = d['title'] as String,
      description = d['description'] as String,
      status = d['status'] as String,
      kind = d['kind'] as String,
      progress = (d['progress'] as num).toInt(),
      target = (d['target'] as num).toInt(),
      expiresAt = d['expires_at'] as String?;
  final String id, title, description, status, kind;
  final int progress, target;
  final String? expiresAt;
}
