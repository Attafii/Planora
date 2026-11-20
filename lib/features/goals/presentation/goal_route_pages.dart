import 'package:flutter/material.dart';
import '../../../app/app_services.dart';
import '../../../core/widgets/product_widgets.dart';
import '../../assistant/models/conversation.dart';
import '../../assistant/presentation/proposal_page.dart';
import '../models/goal.dart';
import 'goal_editor.dart';

class GoalEditRoute extends StatelessWidget {
  const GoalEditRoute({super.key,required this.id});final String id;
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(),body:AsyncView<Goal>(load:()=>AppScope.of(context).goals.detail(id),builder:(ctx,goal,_)=>GoalEditor(goal:goal)));
}
class GoalDecompositionRoute extends StatelessWidget {
  const GoalDecompositionRoute({super.key,required this.id});final String id;
  @override Widget build(BuildContext context)=>Scaffold(body:AsyncView<AgentProposal>(load:()=>AppScope.of(context).assistant.decompose(id),builder:(ctx,proposal,_)=>ProposalPage(id:proposal.id)));
}
