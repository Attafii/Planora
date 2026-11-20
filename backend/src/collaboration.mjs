import { z } from 'zod';
import { one, rows } from './database.mjs';
import { id, now, title, uuid, secret, hash, parse, requireThat, projectRole, taskAccess, activity, pagination, managers } from './core.mjs';
const projectSchema=z.object({title,description:z.string().trim().max(4000).default('')}).strict();
const inviteSchema=z.object({email:z.string().trim().email().max(254).transform(s=>s.toLowerCase()),role:z.enum(['admin','collaborator','viewer']).default('collaborator')}).strict();
export async function projectDetail(db,key,user){
 const role=await projectRole(db,key,user),p=await one(db,'SELECT * FROM projects WHERE id=$1',[key]);
 const members=await rows(db,'SELECT u.id,u.name,u.email,pm.role FROM project_members pm JOIN users u ON u.id=pm.user_id WHERE pm.project_id=$1 ORDER BY u.name',[key]);
 const tasks=await rows(db,'SELECT t.*,a.user_id AS assignee_id,u.name AS assignee_name FROM tasks t LEFT JOIN task_assignments a ON a.task_id=t.id LEFT JOIN users u ON u.id=a.user_id WHERE t.project_id=$1 ORDER BY t.updated_at DESC',[key]);
 const goals=await rows(db,'SELECT id,title,status FROM goals WHERE project_id=$1 ORDER BY updated_at DESC',[key]);
 const active=tasks.filter(t=>!['cancelled','archived'].includes(t.status)),completed=active.filter(t=>t.status==='completed').length;
 return {...p,role,members,tasks,goals,progress:active.length?Math.round(completed/active.length*100):0};
}
export async function assignTask(db,user,taskId,memberId){
 const task=await taskAccess(db,taskId,user);requireThat(task.project_id,'Only shared project tasks can be assigned.',422);
 await projectRole(db,task.project_id,user,managers);
 if(memberId){await projectRole(db,task.project_id,{id:memberId},['owner','admin','collaborator']);await db.query('INSERT INTO task_assignments(task_id,user_id,assigned_by,assigned_at) VALUES($1,$2,$3,$4) ON CONFLICT(task_id) DO UPDATE SET user_id=$2,assigned_by=$3,assigned_at=$4',[taskId,memberId,user.id,now()]);}
 else await db.query('DELETE FROM task_assignments WHERE task_id=$1',[taskId]);
 await activity(db,task.project_id,user,'task_assigned',`Updated assignment for ${task.title}`);return taskAccess(db,taskId,user);
}
export async function addComment(db,user,projectId,input){
 await projectRole(db,projectId,user,['owner','admin','collaborator']);
 const d=parse(z.object({body:z.string().trim().min(1).max(4000),mentions:z.array(uuid).max(20).default([])}).strict(),input);
 for(const m of d.mentions)await projectRole(db,projectId,{id:m});
 const key=id(),time=now();await db.query('INSERT INTO comments(id,project_id,author_id,body,mentions,created_at,updated_at) VALUES($1,$2,$3,$4,$5,$6,$6)',[key,projectId,user.id,d.body,JSON.stringify(d.mentions),time]);
 await activity(db,projectId,user,'comment_added','Added a comment');return one(db,'SELECT c.*,u.name AS author_name FROM comments c JOIN users u ON u.id=c.author_id WHERE c.id=$1',[key]);
}
export function registerCollaboration(route){
 route('get','/projects',async(req,db,user)=>{
  const {limit,offset}=pagination(req),order=req.query.sort==='title'?'p.title':'p.updated_at DESC';
  const items=await rows(db,`SELECT p.*,m.role,(SELECT COUNT(*) FROM project_members pm WHERE pm.project_id=p.id) AS member_count FROM projects p JOIN project_members m ON m.project_id=p.id WHERE m.user_id=$1 AND ($2='' OR p.title ILIKE '%'||$2||'%') ORDER BY ${order},p.id LIMIT $3 OFFSET $4`,[user.id,String(req.query.search||'').slice(0,160),limit+1,offset]);return {items:items.slice(0,limit),has_more:items.length>limit,offset};
 });
 route('post','/projects',async(req,db,user)=>{const d=parse(projectSchema,req.body),key=id(),time=now();await db.query('INSERT INTO projects(id,owner_id,title,description,created_at,updated_at) VALUES($1,$2,$3,$4,$5,$5)',[key,user.id,d.title,d.description,time]);await db.query("INSERT INTO project_members(project_id,user_id,role) VALUES($1,$2,'owner')",[key,user.id]);await activity(db,key,user,'project_created',`Created ${d.title}`);return projectDetail(db,key,user);},{status:201});
 route('get','/projects/:id',(req,db,user)=>projectDetail(db,req.params.id,user));
 route('patch','/projects/:id',async(req,db,user)=>{await projectRole(db,req.params.id,user,managers);const d=parse(projectSchema,req.body);await db.query('UPDATE projects SET title=$2,description=$3,updated_at=$4 WHERE id=$1',[req.params.id,d.title,d.description,now()]);await activity(db,req.params.id,user,'project_updated',`Updated ${d.title}`);return projectDetail(db,req.params.id,user);});
 route('delete','/projects/:id',async(req,db,user)=>{await projectRole(db,req.params.id,user,['owner']);await db.query('DELETE FROM projects WHERE id=$1',[req.params.id]);return {deleted:true};});
 route('get','/projects/:id/members',async(req,db,user)=>(await projectDetail(db,req.params.id,user)).members);
 route('post','/projects/:id/transfer-ownership',async(req,db,user)=>{
  await projectRole(db,req.params.id,user,['owner']);const d=parse(z.object({user_id:uuid}).strict(),req.body);requireThat(d.user_id!==user.id,'Choose another member.',422);await projectRole(db,req.params.id,{id:d.user_id});
  await db.query('SELECT id FROM projects WHERE id=$1 FOR UPDATE',[req.params.id]);
  await db.query("UPDATE project_members SET role='admin' WHERE project_id=$1 AND user_id=$2",[req.params.id,user.id]);
  await db.query("UPDATE project_members SET role='owner' WHERE project_id=$1 AND user_id=$2",[req.params.id,d.user_id]);
  await db.query('UPDATE projects SET owner_id=$2,updated_at=$3 WHERE id=$1',[req.params.id,d.user_id,now()]);await activity(db,req.params.id,user,'ownership_transferred','Transferred project ownership');return projectDetail(db,req.params.id,user);
 });
 route('patch','/projects/:id/members/:memberId',async(req,db,user)=>{
  const role=await projectRole(db,req.params.id,user,managers),target=await projectRole(db,req.params.id,{id:req.params.memberId});
  const d=parse(z.object({role:z.enum(['admin','collaborator','viewer'])}).strict(),req.body);
  requireThat(target!=='owner','Transfer of project ownership requires a separate explicit workflow.',409);
  requireThat(role==='owner'||(target!=='admin'&&d.role!=='admin'),'Only the owner can change admin permissions.',403);
  if(d.role==='viewer')await db.query('DELETE FROM task_assignments WHERE user_id=$1 AND task_id IN (SELECT id FROM tasks WHERE project_id=$2)',[req.params.memberId,req.params.id]);
  await db.query('UPDATE project_members SET role=$3 WHERE project_id=$1 AND user_id=$2',[req.params.id,req.params.memberId,d.role]);await activity(db,req.params.id,user,'role_changed',`Changed member role to ${d.role}`);return {updated:true};
 });
 route('delete','/projects/:id/members/:memberId',async(req,db,user)=>{
  const role=await projectRole(db,req.params.id,user,managers),target=await projectRole(db,req.params.id,{id:req.params.memberId});requireThat(target!=='owner','The project owner cannot be removed.',409);requireThat(role==='owner'||target!=='admin','Only the owner can remove an admin.',403);
  await db.query('DELETE FROM task_assignments WHERE user_id=$1 AND task_id IN (SELECT id FROM tasks WHERE project_id=$2)',[req.params.memberId,req.params.id]);await db.query('DELETE FROM project_members WHERE project_id=$1 AND user_id=$2',[req.params.id,req.params.memberId]);await activity(db,req.params.id,user,'member_removed','Removed a member');return {deleted:true};
 });
 route('post','/projects/:id/leave',async(req,db,user)=>{const role=await projectRole(db,req.params.id,user);requireThat(role!=='owner','The owner must keep the project or delete it.',409);await db.query('DELETE FROM task_assignments WHERE user_id=$1 AND task_id IN (SELECT id FROM tasks WHERE project_id=$2)',[user.id,req.params.id]);await db.query('DELETE FROM project_members WHERE project_id=$1 AND user_id=$2',[req.params.id,user.id]);await activity(db,req.params.id,user,'member_left','Left the project');return {left:true};});
 route('get','/projects/:id/invitations',async(req,db,user)=>{await projectRole(db,req.params.id,user,managers);return rows(db,"SELECT id,email,role,CASE WHEN status='pending' AND expires_at<$2 THEN 'expired' ELSE status END AS status,expires_at,created_at FROM invitations WHERE project_id=$1 ORDER BY created_at DESC",[req.params.id,now()]);});
 route('post','/projects/:id/invitations',async(req,db,user)=>{
  const role=await projectRole(db,req.params.id,user,managers),d=parse(inviteSchema,req.body);requireThat(role==='owner'||d.role!=='admin','Only the owner can invite an admin.',403);
  const member=await one(db,'SELECT 1 FROM project_members pm JOIN users u ON u.id=pm.user_id WHERE pm.project_id=$1 AND u.email=$2',[req.params.id,d.email]);requireThat(!member,'This person is already a project member.',409);
  await db.query("UPDATE invitations SET status='revoked' WHERE project_id=$1 AND email=$2 AND status='pending' AND expires_at<$3",[req.params.id,d.email,now()]);
  const pending=await one(db,"SELECT id FROM invitations WHERE project_id=$1 AND email=$2 AND status='pending'",[req.params.id,d.email]);requireThat(!pending,'A pending invitation already exists. Revoke it before creating another.',409);
  const key=id(),token=secret(),expires=new Date(Date.now()+7*86400000).toISOString();await db.query("INSERT INTO invitations(id,project_id,email,role,token_hash,status,invited_by,expires_at,created_at) VALUES($1,$2,$3,$4,$5,'pending',$6,$7,$8)",[key,req.params.id,d.email,d.role,hash(token),user.id,expires,now()]);await activity(db,req.params.id,user,'invitation_created',`Invited ${d.email}`);return {id:key,token,email:d.email,role:d.role,expires_at:expires};
 },{status:201});
 route('post','/projects/:id/invitations/:invitationId/revoke',async(req,db,user)=>{await projectRole(db,req.params.id,user,managers);const inv=await one(db,'SELECT * FROM invitations WHERE id=$1 AND project_id=$2',[req.params.invitationId,req.params.id]);requireThat(inv,'Invitation not found.',404);requireThat(inv.status==='pending','This invitation has already been handled.',409);await db.query("UPDATE invitations SET status='revoked' WHERE id=$1",[inv.id]);await activity(db,req.params.id,user,'invitation_revoked',`Revoked invitation for ${inv.email}`);return {revoked:true};});
 route('get','/invitations/:token',async(req,db,user)=>{const i=await invitation(db,req.params.token,user);const project=await one(db,'SELECT title FROM projects WHERE id=$1',[i.project_id]);const sender=await one(db,'SELECT name FROM users WHERE id=$1',[i.invited_by]);return {id:i.id,title:project.title,role:i.role,email:i.email,sender:sender.name,status:i.status==='pending'&&i.expires_at<now()?'expired':i.status,expires_at:i.expires_at};});
 route('post','/invitations/:token/respond',async(req,db,user)=>{const i=await invitation(db,req.params.token,user,true),d=parse(z.object({accept:z.boolean()}).strict(),req.body);if(d.accept){await db.query('INSERT INTO project_members(project_id,user_id,role) VALUES($1,$2,$3) ON CONFLICT DO NOTHING',[i.project_id,user.id,i.role]);await activity(db,i.project_id,user,'member_joined','Joined the project');}await db.query('UPDATE invitations SET status=$2 WHERE id=$1',[i.id,d.accept?'accepted':'rejected']);return {project_id:i.project_id,status:d.accept?'accepted':'rejected'};});
 route('post','/projects/:id/assignments',(req,db,user)=>{const d=parse(z.object({task_id:uuid,user_id:uuid.nullable()}).strict(),req.body);return (async()=>{await projectRole(db,req.params.id,user,managers);const t=await taskAccess(db,d.task_id,user);requireThat(t.project_id===req.params.id,'Task belongs to another project.',422);return assignTask(db,user,d.task_id,d.user_id);})();});
 route('get','/projects/:id/comments',async(req,db,user)=>{await projectRole(db,req.params.id,user);const {limit,offset}=pagination(req);const list=await rows(db,'SELECT c.*,u.name AS author_name FROM comments c JOIN users u ON u.id=c.author_id WHERE c.project_id=$1 ORDER BY c.created_at DESC,c.id LIMIT $2 OFFSET $3',[req.params.id,limit+1,offset]);return {items:list.slice(0,limit),has_more:list.length>limit,offset};});
 route('post','/projects/:id/comments',(req,db,user)=>addComment(db,user,req.params.id,req.body),{status:201});
 for(const method of ['patch','delete'])route(method,'/projects/:id/comments/:commentId',async(req,db,user)=>{
  const role=await projectRole(db,req.params.id,user),c=await one(db,'SELECT * FROM comments WHERE id=$1 AND project_id=$2',[req.params.commentId,req.params.id]);requireThat(c,'Comment not found.',404);requireThat(role!=='viewer'&&(c.author_id===user.id||managers.includes(role)),'You cannot change this comment.',403);
  if(method==='delete'){await db.query('DELETE FROM comments WHERE id=$1',[c.id]);await activity(db,req.params.id,user,'comment_deleted','Deleted a comment');return {deleted:true};}
  const d=parse(z.object({body:z.string().trim().min(1).max(4000)}).strict(),req.body);await db.query('UPDATE comments SET body=$2,updated_at=$3 WHERE id=$1',[c.id,d.body,now()]);return {updated:true};
 });
 route('get','/projects/:id/activity',async(req,db,user)=>{await projectRole(db,req.params.id,user);const {limit,offset}=pagination(req);const list=await rows(db,'SELECT a.*,u.name AS actor_name FROM activity a JOIN users u ON u.id=a.actor_id WHERE a.project_id=$1 ORDER BY a.created_at DESC,a.id LIMIT $2 OFFSET $3',[req.params.id,limit+1,offset]);return {items:list.slice(0,limit),has_more:list.length>limit,offset};});
}
async function invitation(db,token,user,pending=false){
 requireThat(token.length<128,'Invalid invitation.',422);const i=await one(db,'SELECT * FROM invitations WHERE token_hash=$1 FOR UPDATE',[hash(token)]);requireThat(i,'Invitation not found.',404);requireThat(i.email===user.email,'Sign in with the email address this invitation was sent to.',403,'wrong_account');
 if(pending){requireThat(i.status==='pending','This invitation has already been handled.',409);requireThat(i.expires_at>now(),'This invitation expired. Ask the project owner for a new link.',410);}
 return i;
}
