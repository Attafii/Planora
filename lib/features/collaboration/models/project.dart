import '../../../core/network/api_client.dart';
import '../../goals/models/goal.dart';

class Project {
  Project.fromJson(JsonMap d)
    : id = d['id'] as String,
      title = d['title'] as String,
      description = d['description'] as String? ?? '',
      role = d['role'] as String,
      progress = (d['progress'] as num? ?? 0).toInt(),
      memberCount = int.tryParse('${d['member_count'] ?? 0}') ?? 0,
      members = ((d['members'] as List?) ?? [])
          .map((x) => Member.fromJson(x as JsonMap))
          .toList(),
      tasks = ((d['tasks'] as List?) ?? [])
          .map((x) => TaskItem.fromJson(x as JsonMap))
          .toList(),
      goals = ((d['goals'] as List?) ?? []).cast<JsonMap>();
  final String id, title, description, role;
  final int progress, memberCount;
  final List<Member> members;
  final List<TaskItem> tasks;
  final List<JsonMap> goals;
  bool get canManage => role == 'owner' || role == 'admin';
  bool get canWrite => role != 'viewer';
}

class Member {
  Member.fromJson(JsonMap d)
    : id = d['id'] as String,
      name = d['name'] as String,
      email = d['email'] as String,
      role = d['role'] as String;
  final String id, name, email, role;
}

class Invitation {
  Invitation.fromJson(JsonMap d)
    : id = d['id'] as String,
      email = d['email'] as String,
      role = d['role'] as String,
      status = d['status'] as String,
      expiresAt = d['expires_at'] as String;
  final String id, email, role, status, expiresAt;
}

class ProjectComment {
  ProjectComment.fromJson(JsonMap d)
    : id = d['id'] as String,
      authorId = d['author_id'] as String,
      authorName = d['author_name'] as String,
      body = d['body'] as String,
      createdAt = d['created_at'] as String,
      mentions = ((d['mentions'] as List?) ?? []).cast<String>();
  final String id, authorId, authorName, body, createdAt;
  final List<String> mentions;
}

class ActivityEntry {
  ActivityEntry.fromJson(JsonMap d)
    : id = d['id'] as String,
      actorName = d['actor_name'] as String,
      message = d['message'] as String,
      kind = d['kind'] as String,
      createdAt = d['created_at'] as String;
  final String id, actorName, message, kind, createdAt;
}
