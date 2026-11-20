import '../../../core/models/paged.dart';
import '../../../core/network/api_client.dart';
import '../models/project.dart';

class CollaborationRepository {
  CollaborationRepository(this.api);
  final ApiClient api;
  Future<Paged<Project>> list({
    String search = '',
    String sort = '',
    int offset = 0,
  }) async => Paged.fromJson(
    await api.get(
      '/projects',
      query: {'search': search, 'sort': sort, 'offset': '$offset'},
    ),
    Project.fromJson,
  );
  Future<Project> detail(String id) async =>
      Project.fromJson(await api.get('/projects/$id'));
  Future<Project> save(JsonMap data, {String? id}) async => Project.fromJson(
    id == null
        ? await api.post('/projects', data)
        : await api.patch('/projects/$id', data),
  );
  Future<void> delete(String id) => api.delete('/projects/$id');
  Future<void> leave(String id) async {
    await api.post('/projects/$id/leave');
  }

  Future<List<Invitation>> invitations(String id) async =>
      (await api.getList('/projects/$id/invitations'))
          .map(Invitation.fromJson)
          .toList();
  Future<JsonMap> invite(String id, String email, String role) =>
      api.post('/projects/$id/invitations', {'email': email, 'role': role});
  Future<void> revoke(String id, String invitationId) async {
    await api.post('/projects/$id/invitations/$invitationId/revoke');
  }

  Future<JsonMap> invitation(String token) =>
      api.get('/invitations/${Uri.encodeComponent(token)}');
  Future<JsonMap> respond(String token, bool accept) => api.post(
    '/invitations/${Uri.encodeComponent(token)}/respond',
    {'accept': accept},
  );
  Future<void> setRole(String id, String memberId, String role) async {
    await api.patch('/projects/$id/members/$memberId', {'role': role});
  }

  Future<void> removeMember(String id, String memberId) =>
      api.delete('/projects/$id/members/$memberId');
  Future<void> transferOwnership(String id,String memberId) async {
    await api.post('/projects/$id/transfer-ownership', {'user_id':memberId});
  }
  Future<void> assign(String id, String taskId, String? memberId) async {
    await api.post('/projects/$id/assignments', {
      'task_id': taskId,
      'user_id': memberId,
    });
  }

  Future<Paged<ProjectComment>> comments(String id, {int offset = 0}) async =>
      Paged.fromJson(
        await api.get('/projects/$id/comments', query: {'offset': '$offset'}),
        ProjectComment.fromJson,
      );
  Future<void> comment(String id, String body, List<String> mentions) async {
    await api.post('/projects/$id/comments', {
      'body': body,
      'mentions': mentions,
    });
  }

  Future<void> editComment(String id, String commentId, String body) async {
    await api.patch('/projects/$id/comments/$commentId', {'body': body});
  }

  Future<void> deleteComment(String id, String commentId) =>
      api.delete('/projects/$id/comments/$commentId');
  Future<Paged<ActivityEntry>> activity(String id, {int offset = 0}) async =>
      Paged.fromJson(
        await api.get('/projects/$id/activity', query: {'offset': '$offset'}),
        ActivityEntry.fromJson,
      );
}
