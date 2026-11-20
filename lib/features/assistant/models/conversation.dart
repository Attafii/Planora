import '../../../core/network/api_client.dart';

class Conversation {
  Conversation.fromJson(JsonMap d)
    : id = d['id'] as String,
      title = d['title'] as String,
      goalId = d['goal_id'] as String?,
      projectId = d['project_id'] as String?,
      messages = ((d['messages'] as List?) ?? [])
          .map((m) => AgentMessage.fromJson(m as JsonMap))
          .toList(),
      proposals = ((d['proposals'] as List?) ?? [])
          .map((p) => AgentProposal.fromJson(p as JsonMap))
          .toList();
  final String id, title;
  final String? goalId, projectId;
  final List<AgentMessage> messages;
  final List<AgentProposal> proposals;
}

class AgentMessage {
  AgentMessage.fromJson(JsonMap d)
    : id = d['id'] as String,
      role = d['role'] as String,
      body = d['body'] as String;
  final String id, role, body;
}

class AgentProposal {
  AgentProposal.fromJson(JsonMap d)
    : id = d['id'] as String,
      title = d['title'] as String,
      explanation = d['explanation'] as String,
      status = d['status'] as String,
      expiresAt = d['expires_at'] as String,
      revision = (d['revision'] as num).toInt(),
      actions = (d['actions'] as List)
          .map((a) => ProposedAction.fromJson(a as JsonMap))
          .toList(),
      result = (d['result'] as List?)?.cast<JsonMap>(),
      error = d['error'] as String?,
      audit = ((d['audit'] as List?) ?? []).cast<JsonMap>();
  final String id, title, explanation, status, expiresAt;
  final int revision;
  final List<ProposedAction> actions;
  final List<JsonMap>? result;
  final String? error;
  final List<JsonMap> audit;
  bool get canApprove =>
      status == 'pending' && DateTime.parse(expiresAt).isAfter(DateTime.now());
}

class ProposedAction {
  ProposedAction.fromJson(JsonMap d)
    : kind = d['kind'] as String,
      reason = d['reason'] as String,
      risk = d['risk'] as String? ?? 'medium',
      payload = Map<String, dynamic>.from(d['payload'] as JsonMap);
  final String kind, reason, risk;
  final JsonMap payload;
  JsonMap toJson() => {'kind': kind, 'reason': reason, 'payload': payload};
}
