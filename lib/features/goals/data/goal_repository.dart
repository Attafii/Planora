import '../../../core/models/paged.dart';
import '../../../core/network/api_client.dart';
import '../models/goal.dart';

class GoalRepository {
  GoalRepository(this.api);
  final ApiClient api;
  Future<Paged<Goal>> list({
    String search = '',
    String status = '',
    String visibility = '',
    String sort = '',
    int offset = 0,
  }) async => Paged.fromJson(
    await api.get(
      '/goals',
      query: {
        'search': search,
        'status': status,
        'visibility': visibility,
        'sort': sort,
        'offset': '$offset',
      },
    ),
    Goal.fromJson,
  );
  Future<Goal> detail(String id) async =>
      Goal.fromJson(await api.get('/goals/$id'));
  Future<Goal> save(JsonMap data, {String? id}) async => Goal.fromJson(
    id == null
        ? await api.post('/goals', data)
        : await api.patch('/goals/$id', data),
  );
  Future<void> delete(String id) => api.delete('/goals/$id');
  Future<void> saveMilestone(String goalId, JsonMap data, {String? id}) async {
    if (id == null) {
      await api.post('/goals/$goalId/milestones', data);
    } else {
      await api.patch('/goals/$goalId/milestones/$id', data);
    }
  }

  Future<void> deleteMilestone(String goalId, String id) =>
      api.delete('/goals/$goalId/milestones/$id');
  Future<void> reorderMilestones(String goalId, List<String> ids) async {
    await api.post('/goals/$goalId/milestones/reorder', {'ids': ids});
  }

  Future<Paged<TaskItem>> tasks({
    String search = '',
    String? projectId,
    int offset = 0,
  }) async => Paged.fromJson(
    await api.get(
      '/tasks',
      query: {'search': search, 'offset': '$offset', 'project_id': ?projectId},
    ),
    TaskItem.fromJson,
  );
  Future<TaskItem> createTask(JsonMap data) async =>
      TaskItem.fromJson(await api.post('/tasks', data));
  Future<TaskItem> task(String id) async =>
      TaskItem.fromJson(await api.get('/tasks/$id'));
  Future<void> updateTask(String id, String status) async {
    await api.patch('/tasks/$id', {'status': status});
  }

  Future<void> link(String id, String taskId) async {
    await api.post('/goals/$id/tasks', {'task_id': taskId});
  }

  Future<void> unlink(String id, String taskId) =>
      api.delete('/goals/$id/tasks/$taskId');
}
