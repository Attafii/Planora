import { z } from 'zod';
import { one, rows } from './database.mjs';
import { id, now, title, date, uuid, parse, requireThat, goalAccess, taskAccess, projectRole, activity, event, pagination } from './core.mjs';

import { counts, validatePersonalTaskId } from './work_progress.mjs';

export const goalSchema = z.object({title, description:z.string().trim().max(4000).default(''), project_id:uuid.nullable().optional(), start_date:date, target_date:date, status:z.enum(['active','paused','completed','archived']).default('active'), request_id:uuid.optional(), expected_updated_at:z.string().optional()}).strict();
export const milestoneSchema = z.object({title,description:z.string().trim().max(2000).default(''),target_date:date,completed:z.boolean().default(false),position:z.number().int().min(0).optional()}).strict();
export const taskSchema = z.object({title,description:z.string().trim().max(4000).default(''),project_id:uuid.nullable().optional(),milestone_id:uuid.nullable().optional(),estimated_minutes:z.number().int().min(1).max(1440).default(45),deadline:date,priority:z.enum(['low','medium','high','urgent']).default('medium'),request_id:uuid.optional()}).strict();
const validDates = d => requireThat(!d.start_date || !d.target_date || d.start_date<=d.target_date, 'Target date must be on or after the start date.',422);

export async function createGoal(db,user,input) {
  const d=parse(goalSchema,input);validDates(d);
  if(d.project_id)await projectRole(db,d.project_id,user,['owner','admin','collaborator']);
  const key=d.request_id??id(),time=now();
  if(d.request_id){
    const existing=await one(db,'SELECT * FROM goals WHERE id=$1',[key]);
    if(existing){
      requireThat(existing.owner_id===user.id && existing.project_id===(d.project_id??null),'The goal could not be saved with this request.',409);
      requireThat(existing.title===d.title && existing.description===d.description && existing.status===d.status && existing.start_date===(d.start_date??null) && existing.target_date===(d.target_date??null),
        'A previous save already created this goal. Open it to apply your changed draft.',409,'changed_retry');
      return goalDetail(db,key,user);
    }
  }
  requireThat(d.status!=='completed','Save the goal before confirming completion.',422);
  await db.query('INSERT INTO goals(id,owner_id,project_id,title,description,start_date,target_date,status,created_at,updated_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$9)',[key,user.id,d.project_id||null,d.title,d.description,d.start_date||null,d.target_date||null,d.status,time]);
  await activity(db,d.project_id||null,user,'goal_created',`Created goal: ${d.title}`);
  return goalDetail(db,key,user);
}
export async function createMilestone(db,goalId,user,input) {
  const goal=await goalAccess(db,goalId,user,true),d=parse(milestoneSchema,input);
  requireThat(!d.target_date||!goal.target_date||d.target_date<=goal.target_date,'Milestone target must fit within the goal target date.',422);
  const position=d.position??Number((await one(db,'SELECT COALESCE(MAX(position),-1)+1 AS next FROM milestones WHERE goal_id=$1',[goalId])).next);
  const key=id();await db.query('INSERT INTO milestones(id,goal_id,title,description,target_date,position,completed) VALUES($1,$2,$3,$4,$5,$6,$7)',[key,goalId,d.title,d.description,d.target_date||null,position,d.completed]);
  await db.query('UPDATE goals SET updated_at=$2 WHERE id=$1',[goalId,now()]);
  return one(db,'SELECT * FROM milestones WHERE id=$1',[key]);
}
export async function createTask(db,user,input) {
  const d=parse(taskSchema,input);
  if(d.project_id)await projectRole(db,d.project_id,user,['owner','admin','collaborator']);
  if(d.milestone_id){const m=await one(db,'SELECT goal_id FROM milestones WHERE id=$1',[d.milestone_id]);requireThat(m,'Milestone not found.',404);const g=await goalAccess(db,m.goal_id,user,true);requireThat((g.project_id||null)===(d.project_id||null),'Task and milestone must belong to the same workspace.',422);}
  const key=d.request_id??id(),time=now();
  if(d.request_id){
    const existing=await one(db,'SELECT * FROM tasks WHERE id=$1',[key]);
    if(existing){
      requireThat(existing.owner_id===user.id&&existing.project_id===(d.project_id??null),'The task could not be saved with this request.',409);
      requireThat(existing.title===d.title && existing.description===d.description && existing.estimated_minutes===d.estimated_minutes && existing.deadline===(d.deadline??null) && existing.priority===d.priority && existing.milestone_id===(d.milestone_id??null),
        'A previous save already created this task. Open it to review the saved work.',409,'changed_retry');
      return taskAccess(db,key,user);
    }
  }
  await db.query('INSERT INTO tasks(id,owner_id,project_id,milestone_id,title,description,estimated_minutes,deadline,priority,created_at,updated_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$10)',[key,user.id,d.project_id||null,d.milestone_id||null,d.title,d.description,d.estimated_minutes,d.deadline||null,d.priority,time]);
  if(d.project_id)await activity(db,d.project_id,user,'task_created',`Created task: ${d.title}`);
  return taskAccess(db,key,user);
}
export async function goalDetail(db,key,user) {
  const goal=await goalAccess(db,key,user);
  const milestones=await rows(db,'SELECT * FROM milestones WHERE goal_id=$1 ORDER BY position,id',[key]);
  const tasks=await rows(db,'SELECT t.*,a.user_id AS assignee_id,u.name AS assignee_name FROM tasks t JOIN goal_tasks gt ON gt.task_id=t.id LEFT JOIN task_assignments a ON a.task_id=t.id LEFT JOIN users u ON u.id=a.user_id WHERE gt.goal_id=$1 ORDER BY t.created_at',[key]);
  const links=goal.project_id ? [] : await rows(db,'SELECT task_id FROM goal_personal_tasks WHERE goal_id=$1 ORDER BY task_id',[key]);
  const personal=links.flatMap(link=>user.personalTasks?.get(link.task_id) ?? []);
  const missing=links.filter(link=>!user.personalTasks?.has(link.task_id)).map(link=>link.task_id);
  const active=[...tasks,...personal].filter(t=>!['archived','cancelled'].includes(t.status));
  const unavailable=links.length>0 && !user.personalTasks;
  const data=active.length ? counts(active,t=>t.status==='completed') : counts(milestones,m=>m.completed);
  const source=unavailable?'unavailable':active.length?'tasks':milestones.length?'milestones':'none';
  const role=goal.project_id ? await projectRole(db,goal.project_id,user) : null;
  return {
    ...goal,milestones,tasks:[...tasks,...personal],missing_personal_tasks:missing,
    progress:source==='none'||unavailable?null:Math.round(data.completed/data.total*100),
    item_count:data.total,completed_count:data.completed,progress_source:source,progress_checked_at:now(),
    can_edit:!role||['owner','admin'].includes(role)||(role==='collaborator'&&goal.owner_id===user.id),
  };
}

export function registerGoals(route){
 route('get','/goals',async(req,db,user)=>{
  const {limit,offset}=pagination(req),q=String(req.query.search||'').trim().slice(0,160),status=String(req.query.status||''),visibility=String(req.query.visibility||'');
  const order=req.query.sort==='title'?'g.title ASC':'g.updated_at DESC';
  const list=await rows(db,`SELECT g.id FROM goals g WHERE (g.owner_id=$1 AND g.project_id IS NULL OR EXISTS(SELECT 1 FROM project_members pm WHERE pm.project_id=g.project_id AND pm.user_id=$1)) AND ($2='' OR g.title ILIKE '%'||$2||'%') AND ($3='' OR g.status=$3) AND ($4='' OR ($4='personal' AND g.project_id IS NULL) OR ($4='shared' AND g.project_id IS NOT NULL)) ORDER BY ${order},g.id LIMIT $5 OFFSET $6`,[user.id,q,status,visibility,limit+1,offset]);
  return {items:await Promise.all(list.slice(0,limit).map(g=>goalDetail(db,g.id,user))),has_more:list.length>limit,offset};
 });
 route('post','/goals',(req,db,user)=>createGoal(db,user,req.body),{status:201});
 route('get','/goals/personal-tasks',async(req,db,user)=>{
  requireThat(user.personalTasks,'Personal tasks have not synced yet. Sync from Today, then retry.',409,'activity_unavailable');
  const {limit,offset}=pagination(req),search=String(req.query.search??'').trim().toLowerCase();
  const list=[...user.personalTasks.values()].filter(task=>task.title.toLowerCase().includes(search));
  return {items:list.slice(offset,offset+limit),has_more:offset+limit<list.length,offset};
 });
 route('get','/goals/:id',(req,db,user)=>goalDetail(db,req.params.id,user));
 route('patch','/goals/:id',async(req,db,user)=>{
  const g=await goalAccess(db,req.params.id,user,true),d=parse(goalSchema,req.body);validDates(d);
  requireThat((d.project_id||null)===g.project_id,'Move workspaces by creating a new goal; existing linked work cannot change access scope.',422);
  if(d.expected_updated_at && d.expected_updated_at!==g.updated_at){
    const same=g.title===d.title&&g.description===d.description&&g.start_date===(d.start_date??null)&&g.target_date===(d.target_date??null)&&g.status===d.status;
    requireThat(same,'This goal was changed elsewhere. Reopen it and review the latest version.',409,'stale_goal');
    return goalDetail(db,g.id,user);
  }
  if(d.status==='completed' && g.status!=='completed'){
    const detail=await goalDetail(db,g.id,user);
    requireThat(detail.progress_source!=='unavailable'&&(!detail.item_count||detail.completed_count===detail.item_count),'Finish or sync the linked work before completing this goal.',409);
    await event(db,user.id,'goal_completed',g.id);
  }
  await db.query('UPDATE goals SET title=$2,description=$3,start_date=$4,target_date=$5,status=$6,updated_at=$7 WHERE id=$1',[g.id,d.title,d.description,d.start_date||null,d.target_date||null,d.status,now()]);
  await activity(db,g.project_id,user,'goal_updated',`Updated goal: ${d.title}`);return goalDetail(db,g.id,user);
 });
 route('delete','/goals/:id',async(req,db,user)=>{const g=await goalAccess(db,req.params.id,user,true);await activity(db,g.project_id,user,'goal_deleted',`Deleted goal: ${g.title}`);await db.query('DELETE FROM goals WHERE id=$1',[g.id]);return {deleted:true};});
 route('post','/goals/:id/milestones',(req,db,user)=>createMilestone(db,req.params.id,user,req.body),{status:201});
 route('post','/goals/:id/milestones/reorder',async(req,db,user)=>{
  await goalAccess(db,req.params.id,user,true);const d=parse(z.object({ids:z.array(uuid).max(200)}).strict(),req.body);
  const current=await rows(db,'SELECT id FROM milestones WHERE goal_id=$1',[req.params.id]);
  requireThat(new Set(d.ids).size===d.ids.length&&current.length===d.ids.length&&current.every(m=>d.ids.includes(m.id)),'The milestone list changed. Refresh and try again.',409);
  for(let i=0;i<d.ids.length;i++)await db.query('UPDATE milestones SET position=$2 WHERE id=$1',[d.ids[i],i]);return {reordered:true};
 });
 route('patch','/goals/:id/milestones/:milestoneId',async(req,db,user)=>{
  const g=await goalAccess(db,req.params.id,user,true),d=parse(milestoneSchema,req.body);
  const m=await one(db,'SELECT * FROM milestones WHERE id=$1 AND goal_id=$2',[req.params.milestoneId,g.id]);requireThat(m,'Milestone not found.',404);
  requireThat(!d.target_date||!g.target_date||d.target_date<=g.target_date,'Milestone target must fit within the goal target date.',422);
  if(d.completed){const unfinished=await one(db,"SELECT COUNT(*) AS n FROM tasks WHERE milestone_id=$1 AND status NOT IN ('completed','cancelled','archived')",[m.id]);requireThat(Number(unfinished.n)===0,'Complete this milestone’s tasks first.',409);}
  await db.query('UPDATE milestones SET title=$2,description=$3,target_date=$4,completed=$5,position=$6 WHERE id=$1',[m.id,d.title,d.description,d.target_date||null,d.completed,d.position??m.position]);return one(db,'SELECT * FROM milestones WHERE id=$1',[m.id]);
 });
 route('delete','/goals/:id/milestones/:milestoneId',async(req,db,user)=>{await goalAccess(db,req.params.id,user,true);await db.query('DELETE FROM milestones WHERE id=$1 AND goal_id=$2',[req.params.milestoneId,req.params.id]);return {deleted:true};});
 route('post','/goals/:id/personal-tasks',async(req,db,user)=>{
  const g=await goalAccess(db,req.params.id,user,true);
  requireThat(!g.project_id,'Personal tasks can only be linked to personal goals.',422);
  const key=validatePersonalTaskId(req.body?.task_id);
  requireThat(user.personalTasks?.has(key),'This personal task is unavailable. Sync from Today and refresh the task list.',409,'activity_unavailable');
  await db.query('INSERT INTO goal_personal_tasks(goal_id,task_id) VALUES($1,$2) ON CONFLICT DO NOTHING',[g.id,key]);
  return goalDetail(db,g.id,user);
 });
 route('delete','/goals/:id/personal-tasks/:taskId',async(req,db,user)=>{
  const g=await goalAccess(db,req.params.id,user,true);
  requireThat(!g.project_id,'Personal tasks can only be unlinked from personal goals.',422);
  await db.query('DELETE FROM goal_personal_tasks WHERE goal_id=$1 AND task_id=$2',[g.id,validatePersonalTaskId(req.params.taskId)]);
  return {unlinked:true};
 });
 route('post','/goals/:id/tasks',async(req,db,user)=>{
  const g=await goalAccess(db,req.params.id,user,true),d=parse(z.object({task_id:uuid}),req.body),t=await taskAccess(db,d.task_id,user);
  requireThat(g.project_id===t.project_id,'A goal and its linked tasks must share the same access scope.',422);
  await db.query('INSERT INTO goal_tasks(goal_id,task_id) VALUES($1,$2) ON CONFLICT DO NOTHING',[g.id,t.id]);return goalDetail(db,g.id,user);
 });
 route('delete','/goals/:id/tasks/:taskId',async(req,db,user)=>{await goalAccess(db,req.params.id,user,true);await db.query('DELETE FROM goal_tasks WHERE goal_id=$1 AND task_id=$2',[req.params.id,req.params.taskId]);return {unlinked:true};});
 route('get','/tasks',async(req,db,user)=>{
  const {limit,offset}=pagination(req),p=req.query.project_id||null;
  if(p)await projectRole(db,p,user);
  const result=await rows(db,`SELECT t.*,a.user_id AS assignee_id,u.name AS assignee_name FROM tasks t LEFT JOIN task_assignments a ON a.task_id=t.id LEFT JOIN users u ON u.id=a.user_id WHERE (t.owner_id=$1 AND t.project_id IS NULL OR EXISTS(SELECT 1 FROM project_members pm WHERE pm.project_id=t.project_id AND pm.user_id=$1)) AND ($2::text IS NULL OR t.project_id=$2) AND ($3='' OR t.title ILIKE '%'||$3||'%') ORDER BY t.updated_at DESC,t.id LIMIT $4 OFFSET $5`,[user.id,p,String(req.query.search||'').slice(0,160),limit+1,offset]);
  return {items:result.slice(0,limit),has_more:result.length>limit,offset};
 });
 route('post','/tasks',(req,db,user)=>createTask(db,user,req.body),{status:201});
 route('get','/tasks/:id',(req,db,user)=>taskAccess(db,req.params.id,user));
 route('patch','/tasks/:id',async(req,db,user)=>{
  const t=await taskAccess(db,req.params.id,user,true),d=parse(z.object({status:z.enum(['todo','in_progress','blocked','completed','archived','cancelled']),from_plan:z.literal(true).optional()}).strict(),req.body);
  if(d.from_plan){
    requireThat(t.project_id && (t.assignee_id===user.id || (!t.assignee_id && t.owner_id===user.id)),
      'This project task is no longer yours to complete.',403,'assignment_changed');
    requireThat(d.status==='completed' && ['todo','in_progress','completed'].includes(t.status),
      'This project task can no longer be completed from the plan.',409,'stale_task');
  }
  if(t.status===d.status)return t;
  await db.query('UPDATE tasks SET status=$2,updated_at=$3 WHERE id=$1',[t.id,d.status,now()]);
  if(d.status==='completed')await event(db,t.assignee_id||t.owner_id,'task_completed',t.id);
  if(t.project_id)await activity(db,t.project_id,user,'task_updated',`${t.title}: ${d.status.replace('_',' ')}`);
  return taskAccess(db,t.id,user);
 });
}
