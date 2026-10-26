import '../../../core/network/api_client.dart';

class Goal {
  Goal.fromJson(JsonMap d)
    : id = d['id'] as String,
      title = d['title'] as String,
      description = d['description'] as String? ?? '',
      projectId = d['project_id'] as String?,
      startDate = d['start_date'] as String?,
      targetDate = d['target_date'] as String?,
      status = d['status'] as String,
      progress = (d['progress'] as num? ?? 0).toInt(),
      itemCount = (d['item_count'] as num? ?? 0).toInt(),
      canEdit = d['can_edit'] != false,
      milestones = ((d['milestones'] as List?) ?? [])
          .map((m) => Milestone.fromJson(m as JsonMap))
          .toList(),
      tasks = ((d['tasks'] as List?) ?? [])
          .map((t) => TaskItem.fromJson(t as JsonMap))
          .toList();
  final String id, title, description, status;
  final String? projectId, startDate, targetDate;
  final int progress, itemCount;
  final bool canEdit;
  final List<Milestone> milestones;
  final List<TaskItem> tasks;
  JsonMap toForm({String? newStatus}) => {
    'title': title,
    'description': description,
    'project_id': projectId,
    'start_date': startDate,
    'target_date': targetDate,
    'status': newStatus ?? status,
  };
}

class Milestone {
  Milestone.fromJson(JsonMap d)
    : id = d['id'] as String,
      title = d['title'] as String,
      description = d['description'] as String? ?? '',
      targetDate = d['target_date'] as String?,
      position = (d['position'] as num).toInt(),
      completed = d['completed'] == true;
  final String id, title, description;
  final String? targetDate;
  final int position;
  final bool completed;
  JsonMap toForm({bool? done, int? order}) => {
    'title': title,
    'description': description,
    'target_date': targetDate,
    'position': order ?? position,
    'completed': done ?? completed,
  };
}

class TaskItem {
  TaskItem.fromJson(JsonMap d)
    : id = d['id'] as String,
      title = d['title'] as String,
      description = d['description'] as String? ?? '',
      status = d['status'] as String,
      minutes = (d['estimated_minutes'] as num).toInt(),
      projectId = d['project_id'] as String?,
      assigneeId = d['assignee_id'] as String?,
      assigneeName = d['assignee_name'] as String?,
      deadline = d['deadline'] as String?,
      canEdit = d['can_edit'] != false;
  final String id, title, description, status;
  final int minutes;
  final bool canEdit;
  final String? projectId, assigneeId, assigneeName, deadline;
}
