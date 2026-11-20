import '../../../core/network/api_client.dart';
import '../models/achievement.dart';

class GamificationRepository {
  GamificationRepository(this.api);
  final ApiClient api;
  Future<GamificationSummary> summary() async =>
      GamificationSummary.fromJson(await api.get('/gamification/summary'));
  Future<Achievement> achievement(String id) async =>
      Achievement.fromJson(await api.get('/achievements/$id'));
  Future<List<Challenge>> challenges() async =>
      (await api.getList('/challenges')).map(Challenge.fromJson).toList();
  Future<void> join(String id) async {
    await api.post('/challenges/$id/join');
  }

  Future<void> leave(String id) async {
    await api.post('/challenges/$id/leave');
  }
}
