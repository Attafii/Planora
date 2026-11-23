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
      progress = (d['progress'] as num?)?.toInt(),
      updatedAt = d['updated_at'] as String?,
      checkedAt = d['progress_checked_at'] as String?,
      progressSource = d['progress_source'] as String? ?? 'none',
      completedCount = (d['completed_count'] as num? ?? 0).toInt(),
      missingTasks = ((d['missing_personal_tasks'] as List?) ?? [])
          .cast<String>(),
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
  final int? progress;
  final int itemCount, completedCount;
  final String progressSource;
  final String? updatedAt, checkedAt;
  final List<String> missingTasks;
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
    if (updatedAt != null) 'expected_updated_at': updatedAt,
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
      ownerId = d['owner_id'] as String?,
      assigneeName = d['assignee_name'] as String?,
      deadline = d['deadline'] as String?,
      personal = d['personal'] == true,
      canEdit = d['can_edit'] != false;
  final String id, title, description, status;
  final int minutes;
  final bool canEdit, personal;
  final String? projectId, assigneeId, ownerId, assigneeName, deadline;
}
