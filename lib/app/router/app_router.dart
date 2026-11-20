import 'package:flutter/material.dart';

import '../../core/widgets/product_widgets.dart';
import '../../features/goals/presentation/goals_page.dart';
import '../../features/goals/presentation/goal_editor.dart';
import '../../features/goals/presentation/goal_detail_page.dart';
import '../../features/goals/presentation/goal_route_pages.dart';
import '../../features/goals/presentation/task_surfaces.dart';
import '../../features/collaboration/presentation/projects_page.dart';
import '../../features/collaboration/presentation/project_editor.dart';
import '../../features/collaboration/presentation/project_workspace.dart';
import '../../features/collaboration/presentation/members_invitations.dart';
import '../../features/assistant/presentation/conversations_page.dart';
import '../../features/assistant/presentation/chat_page.dart';
import '../../features/assistant/presentation/proposal_page.dart';
import '../../features/assistant/presentation/history_page.dart';
import '../../features/gamification/presentation/achievements_page.dart';
import '../../features/gamification/presentation/challenges_page.dart';

abstract final class AppRouter {
  static Route<void> route(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? '/'), p = uri.pathSegments;
    Widget page;
    if (p.isEmpty) {
      page = const GoalsPage();
    } else if (p[0] == 'goals') {
      page = p.length == 1
          ? const GoalsPage()
          : p[1] == 'new'
          ? const GoalEditor()
          : p.length==3&&p[2]=='edit'
          ? GoalEditRoute(id:p[1])
          : p.length==3&&p[2]=='decomposition'
          ? GoalDecompositionRoute(id:p[1])
          : GoalDetailPage(id: p[1]);
    } else if (p[0] == 'tasks' && p.length == 2) {
      page = LinkedTaskPage(id: p[1]);
    } else if (p[0] == 'projects') {
      page = p.length == 1
          ? const ProjectsPage()
          : p[1] == 'new'
          ? const ProjectEditor()
          : p.length == 3 && p[2] == 'members'
          ? MembersPage(id: p[1])
          : p.length == 3 && p[2] == 'invitations'
          ? InvitationsPage(id: p[1])
          : ProjectWorkspace(id: p[1]);
    } else if (p[0] == 'invitations' && p.length == 2) {
      page = InvitationResponsePage(token: p[1]);
    } else if (p[0] == 'assistant') {
      page = p.length == 3 && p[1] == 'conversations'
          ? ChatPage(id: p[2])
          : p.length == 3 && (p[1] == 'actions'||p[1]=='proposals')
          ? ProposalPage(id: p[2])
          : p.length == 2 && p[1] == 'actions'
          ? const ActionHistoryPage()
          : const ConversationsPage();
    } else if (p[0] == 'achievements') {
      page = p.length == 1
          ? const AchievementsPage()
          : AchievementDetailPage(id: p[1]);
    } else if (p[0] == 'challenges') {
      page = const ChallengesPage();
    } else {
      page = Scaffold(
        appBar: AppBar(),
        body: const StateMessage(
          title: 'Page not found',
          message: 'Return to your workspace and choose a view.',
        ),
      );
    }
    return MaterialPageRoute<void>(settings: settings, builder: (_) => page);
  }
}
