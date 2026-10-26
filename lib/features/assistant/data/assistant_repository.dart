import '../../../core/models/paged.dart';
import '../../../core/network/api_client.dart';
import '../models/conversation.dart';

class AssistantRepository {
  AssistantRepository(this.api);
  final ApiClient api;
  Future<Paged<Conversation>> conversations({
    String search = '',
    int offset = 0,
  }) async => Paged.fromJson(
    await api.get(
      '/assistant/conversations',
      query: {'search': search, 'offset': '$offset'},
    ),
    Conversation.fromJson,
  );
  Future<Conversation> create({
    String? goalId,
    String? projectId,
    String? title,
  }) async => Conversation.fromJson(
    await api.post('/assistant/conversations', {
      'title': title ?? 'A new conversation',
      'goal_id': goalId,
      'project_id': projectId,
    }),
  );
  Future<Conversation> conversation(String id) async =>
      Conversation.fromJson(await api.get('/assistant/conversations/$id'));
  Future<void> deleteConversation(String id) =>
      api.delete('/assistant/conversations/$id');
  Future<JsonMap> send(String id, String message, {bool cloud = false}) =>
      api.post('/assistant/messages', {
        'conversation_id': id,
        'message': message,
        'use_cloud': cloud,
      }, cloud ? const Duration(seconds: 75) : const Duration(seconds: 35));
  Future<AgentProposal> decompose(String id, {int steps = 4}) async =>
      AgentProposal.fromJson(
        await api.post('/goals/$id/ai-decomposition', {'steps': steps}),
      );
  Future<Paged<AgentProposal>> history({
    String status = '',
    int offset = 0,
  }) async => Paged.fromJson(
    await api.get(
      '/assistant/actions',
      query: {'status': status, 'offset': '$offset'},
    ),
    AgentProposal.fromJson,
  );
  Future<AgentProposal> proposal(String id) async =>
      AgentProposal.fromJson(await api.get('/assistant/actions/$id'));
  Future<AgentProposal> edit(AgentProposal p, List<JsonMap> actions) async =>
      AgentProposal.fromJson(
        await api.patch('/assistant/actions/${p.id}', {
          'revision': p.revision,
          'actions': actions,
        }),
      );
  Future<AgentProposal> approve(AgentProposal p) async =>
      AgentProposal.fromJson(
        await api.post('/assistant/actions/${p.id}/approve', {
          'revision': p.revision,
        }),
      );
  Future<void> reject(String id) async {
    await api.post('/assistant/actions/$id/reject');
  }

  Future<JsonMap> capabilities() => api.get('/assistant/capabilities');
}
