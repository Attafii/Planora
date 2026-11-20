import { z } from 'zod';
import { cloudAnswer } from './cloud_ai.mjs';
import { one, rows } from './database.mjs';
import { id, now, title, date, uuid, parse, requireThat, goalAccess, projectRole, taskAccess, activity, pagination, ApiError } from './core.mjs';
import { createGoal, createMilestone, createTask, goalDetail, goalSchema, taskSchema } from './goals.mjs';
import { assignTask, addComment } from './collaboration.mjs';

const stepSchema=z.object({title,estimated_minutes:z.number().int().min(1).max(1440),selected:z.boolean().default(true)}).strict();
const planSchema=z.object({title,goal_id:uuid.optional(),project_id:uuid.nullable().optional(),target_date:date,max_daily_minutes:z.number().int().min(15).max(720).default(120),steps:z.array(stepSchema).min(1).max(20)}).strict();
const schemas={
 create_task:taskSchema,
 create_goal:goalSchema,
 build_goal_plan:planSchema,
 create_milestones:z.object({goal_id:uuid,titles:z.array(title).min(1).max(20)}).strict(),
 assign_task:z.object({task_id:uuid,user_id:uuid}).strict(),
 add_comment:z.object({project_id:uuid,body:z.string().trim().min(1).max(4000),mentions:z.array(uuid).default([])}).strict(),
 archive_task:z.object({task_id:uuid}).strict(),
 update_task:z.object({task_id:uuid,title:title.optional(),deadline:date,estimated_minutes:z.number().int().min(1).max(1440).optional()}).strict(),
 generate_schedule:z.object({date:date}).strict(),
 replan_schedule:z.object({date:date,reason:z.string().trim().min(1).max(500)}).strict(),
};
export function validateActions(input){
 const items=parse(z.array(z.object({kind:z.enum(Object.keys(schemas)),payload:z.record(z.string(),z.unknown()),reason:z.string().min(1).max(1000),risk:z.enum(['medium','high']).optional()}).strict()).min(1).max(20),input);
 return items.map(a=>({...a,payload:parse(schemas[a.kind],a.payload),risk:['assign_task','archive_task'].includes(a.kind)?'high':'medium'}));
}
async function authorizeAction(db,user,a){
 const p=a.payload;
 if(p.project_id)await projectRole(db,p.project_id,user,['owner','admin','collaborator']);
 if(p.goal_id)await goalAccess(db,p.goal_id,user,true);
 if(p.task_id)await taskAccess(db,p.task_id,user,true);
 if(a.kind==='assign_task'){const t=await taskAccess(db,p.task_id,user);requireThat(t.project_id,'Task must be shared.',422);await projectRole(db,t.project_id,user,['owner','admin']);await projectRole(db,t.project_id,{id:p.user_id},['owner','admin','collaborator']);}
 if(['generate_schedule','replan_schedule'].includes(a.kind))requireThat(process.env.PLANNING_API_URL,'Calendar planning is not connected. You can still create and organize the work.',503,'integration_unavailable');
}
export async function proposal(db,user,{conversationId=null,goalId=null,title:heading,explanation,actions}){
 const checked=validateActions(actions);for(const a of checked)await authorizeAction(db,user,a);
 const key=id(),time=now(),expires=new Date(Date.now()+30*60000).toISOString();
 await db.query("INSERT INTO proposals(id,conversation_id,owner_id,goal_id,title,explanation,actions,status,created_at,expires_at) VALUES($1,$2,$3,$4,$5,$6,$7,'pending',$8,$9)",[key,conversationId,user.id,goalId,heading,explanation,JSON.stringify(checked),time,expires]);
 await audit(db,user,key,'proposed','Prepared a validated proposal; no product records changed.');return one(db,'SELECT * FROM proposals WHERE id=$1',[key]);
}
async function audit(db,user,key,type,details){await db.query('INSERT INTO agent_audit(id,owner_id,proposal_id,event,details,created_at) VALUES($1,$2,$3,$4,$5,$6)',[id(),user.id,key,type,details,now()]);}
async function ownedProposal(db,key,user,lock=false){const p=await one(db,`SELECT * FROM proposals WHERE id=$1${lock?' FOR UPDATE':''}`,[key]);requireThat(p&&p.owner_id===user.id,'This action is not available to your account.',404);return p;}
async function context(db,c,user){if(c.goal_id)await goalAccess(db,c.goal_id,user);if(c.project_id)await projectRole(db,c.project_id,user);}
async function execute(db,user,a,key){
 const p=a.payload;await authorizeAction(db,user,a);
 if(a.kind==='create_task')return createTask(db,user,p);
 if(a.kind==='create_goal')return createGoal(db,user,p);
 if(a.kind==='create_milestones'){const result=[];for(const heading of p.titles)result.push(await createMilestone(db,p.goal_id,user,{title:heading}));return {milestones:result};}
 if(a.kind==='build_goal_plan'){
  const steps=p.steps.filter(s=>s.selected);requireThat(steps.length,'Select at least one step.',422);
  const g=p.goal_id?await goalAccess(db,p.goal_id,user,true):await createGoal(db,user,{title:p.title,target_date:p.target_date||null,project_id:p.project_id||null});
  if(g.target_date&&p.target_date)requireThat(p.target_date<=g.target_date,'The proposed tasks exceed the goal target date.',422);
  for(const s of steps){const m=await createMilestone(db,g.id,user,{title:s.title,target_date:p.target_date||g.target_date||null});const t=await createTask(db,user,{title:s.title,project_id:g.project_id,milestone_id:m.id,estimated_minutes:s.estimated_minutes,deadline:p.target_date||g.target_date||null});await db.query('INSERT INTO goal_tasks(goal_id,task_id) VALUES($1,$2)',[g.id,t.id]);}
  return {goal_id:g.id,title:g.title,created_tasks:steps.length,max_daily_minutes:p.max_daily_minutes,message:'Created unscheduled work. Calendar placement requires the planning engine.'};
 }
 if(a.kind==='assign_task')return assignTask(db,user,p.task_id,p.user_id);
 if(a.kind==='add_comment')return addComment(db,user,p.project_id,{body:p.body,mentions:p.mentions});
 if(a.kind==='archive_task'){await db.query("UPDATE tasks SET status='archived',updated_at=$2 WHERE id=$1",[p.task_id,now()]);return {task_id:p.task_id,archived:true};}
 if(a.kind==='update_task'){const t=await taskAccess(db,p.task_id,user,true);await db.query('UPDATE tasks SET title=$2,deadline=$3,estimated_minutes=$4,updated_at=$5 WHERE id=$1',[t.id,p.title??t.title,p.deadline===undefined?t.deadline:p.deadline,p.estimated_minutes??t.estimated_minutes,now()]);return taskAccess(db,t.id,user);}
 if(['generate_schedule','replan_schedule'].includes(a.kind)){
  const response=await fetch(`${process.env.PLANNING_API_URL.replace(/\/$/,'')}/planning/${a.kind==='generate_schedule'?'generate':'replan'}`,{method:'POST',headers:{'Content-Type':'application/json','Idempotency-Key':key,'X-User-Id':user.id,...(process.env.INTEGRATION_TOKEN?{Authorization:`Bearer ${process.env.INTEGRATION_TOKEN}`}:{})},body:JSON.stringify(p),signal:AbortSignal.timeout(15000)});
  requireThat(response.ok,'The planning service could not prepare a proposal.',502);return {planning_proposal:await response.json(),message:'A planning proposal was prepared. It still requires calendar approval.'};
 }
 throw new ApiError(422,'Unsupported action.');
}
function localDate(user){return new Intl.DateTimeFormat('en-CA',{timeZone:user.timezone,year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());}
function deadline(text,user){
 const exact=text.match(/\b(\d{4}-\d{2}-\d{2})\b/);if(exact)return parse(date,exact[1]);
 const days=['sunday','monday','tuesday','wednesday','thursday','friday','saturday'];
 const d=days.findIndex(day=>new RegExp(`\\b${day}\\b`,'i').test(text));
 const current=new Date(localDate(user)+'T12:00:00Z');
 if(d>=0){current.setUTCDate(current.getUTCDate()+((d-current.getUTCDay()+7)%7||7));return current.toISOString().slice(0,10);}
 if(/\btomorrow\b/i.test(text)){current.setUTCDate(current.getUTCDate()+1);return current.toISOString().slice(0,10);}
 if(/\btoday\b/i.test(text))return localDate(user);return null;
}
async function answer(db,user,message,c,useCloud){
 const goals=await rows(db,"SELECT g.id,g.title,g.target_date FROM goals g WHERE (g.owner_id=$1 AND g.project_id IS NULL OR EXISTS(SELECT 1 FROM project_members pm WHERE pm.project_id=g.project_id AND pm.user_id=$1)) AND g.status='active' ORDER BY g.updated_at DESC LIMIT 30",[user.id]);
 const tasks=await rows(db,"SELECT t.id,t.title,t.status,t.estimated_minutes FROM tasks t WHERE (t.owner_id=$1 AND t.project_id IS NULL OR EXISTS(SELECT 1 FROM project_members pm WHERE pm.project_id=t.project_id AND pm.user_id=$1)) AND t.status NOT IN ('archived','cancelled') ORDER BY t.updated_at DESC LIMIT 30",[user.id]);
 if(useCloud){
  requireThat(process.env.AI_API_KEY&&process.env.AI_MODEL,'Cloud AI is not configured. Switch to the local assistant or contact the administrator.',503,'ai_unavailable');
  const tools=Object.keys(schemas).filter(k=>process.env.PLANNING_API_URL||!['generate_schedule','replan_schedule'].includes(k));
  return cloudAnswer([{role:'system',content:`You are Planify. Return JSON {message:string,actions:[{kind,payload,reason}]}. You propose, never execute. Ask clarification if needed. Use only verified IDs. Supported kinds: ${tools.join(',')}. Schemas: ${JSON.stringify(Object.fromEntries(tools.map(k=>[k,z.toJSONSchema(schemas[k])])))}. No calendar times. Current user timezone ${user.timezone}. Date ${localDate(user)}. Authorized context ${JSON.stringify({goals,tasks,context:c})}.`},{role:'user',content:message}]);
 }
 if(/\b(summary|summarize|next|today|metrics|report)\b/i.test(message)&&!/(create|plan|revision)/i.test(message)){
  const completed=tasks.filter(t=>t.status==='completed').length;return {message:`Your accessible work has ${goals.length} active goals and ${tasks.filter(t=>t.status!=='completed').length} open tasks. ${completed} tasks are complete. Open a goal to choose the next milestone. This summary uses your stored records.`,actions:[]};
 }
 if(/\b(soon|sometime|later|next week)\b/i.test(message))return {message:'What exact target date should I use? Enter it as YYYY-MM-DD so I can prepare a clear proposal.',actions:[]};
 if(/\b(plan|decompose|break down|chapters|revision|milestones)\b/i.test(message)){
  const target=deadline(message,user)|| (c.goal_id?(await goalAccess(db,c.goal_id,user)).target_date:null);
  if(!target)return {message:'What is the target date? Include YYYY-MM-DD or a weekday, and the number of chapters or steps.',actions:[]};
  const chapter=message.match(/(?:\b(\d{1,2})\s+(?:chapters|steps)|\b(four|three|two|five|six)\s+(?:chapters|steps))/i);
  const count=chapter?Number(chapter[1]||({two:2,three:3,four:4,five:5,six:6})[chapter[2].toLowerCase()]):4;
  requireThat(count>=1&&count<=20,'Use between 1 and 20 steps.',422);
  const hours=message.match(/(?:maximum|max|at most)\s+(\d+|two|three|one)\s+hours?/i);
  const max=hours?Number(hours[1].match(/^\d+$/)?hours[1]:({one:1,two:2,three:3})[hours[1].toLowerCase()])*60:120;
  const goalTitle=c.goal_id?(await goalAccess(db,c.goal_id,user)).title:'Revision plan';
  return {message:'I prepared an editable outline using local rules. Review the titles and estimates before approval. These are unscheduled tasks; the daily limit is a planning constraint, not a confirmed calendar schedule.',actions:[{kind:'build_goal_plan',reason:'Break the requested work into manageable, reviewable steps.',payload:{title:goalTitle,...(c.goal_id?{goal_id:c.goal_id}:{}),...(c.project_id?{project_id:c.project_id}:{}),target_date:target,max_daily_minutes:max,steps:Array.from({length:count},(_,i)=>({title:chapter?`Review chapter ${i+1}`:['Define the outcome','Prepare the work','Complete the main work','Review and finish'][i]||`Complete step ${i+1}`,estimated_minutes:45,selected:true}))}}]};
 }
 if(/^(create|add)\s+(a\s+)?task[:\s]/i.test(message)){
  const taskTitle=message.replace(/^(create|add)\s+(a\s+)?task[:\s]+/i,'').replace(/\s+(before|by|on)\s+.*$/i,'').trim();
  return {message:'Review this task before it is created.',actions:[{kind:'create_task',reason:'You asked to capture a new task.',payload:{title:taskTitle,estimated_minutes:45,deadline:deadline(message,user),...(c.project_id?{project_id:c.project_id}:{})}}]};
 }
 return {message:'The local assistant can prepare revision outlines, add a task, and summarize stored work. Try “Plan four chapters before Friday, maximum two hours per day” or “Create task: draft the introduction by 2026-11-10”. Cloud mode supports broader requests when a provider is configured.',actions:[]};
}
export function registerAssistant(route,dbRoot){
 route('get','/assistant/capabilities',()=>({mode:process.env.AI_API_KEY&&process.env.AI_MODEL?'cloud_available':'local',planning_connected:Boolean(process.env.PLANNING_API_URL)}));
 route('get','/assistant/conversations',async(req,db,user)=>{const {limit,offset}=pagination(req);const list=await rows(db,"SELECT * FROM conversations WHERE owner_id=$1 AND ($2='' OR title ILIKE '%'||$2||'%') ORDER BY updated_at DESC,id LIMIT $3 OFFSET $4",[user.id,String(req.query.search||'').slice(0,160),limit+1,offset]);return {items:list.slice(0,limit),has_more:list.length>limit,offset};});
 route('post','/assistant/conversations',async(req,db,user)=>{
  const d=parse(z.object({title:title.default('A new conversation'),goal_id:uuid.nullable().optional(),project_id:uuid.nullable().optional()}).strict(),req.body);if(d.goal_id)await goalAccess(db,d.goal_id,user);if(d.project_id)await projectRole(db,d.project_id,user);
  const key=id(),time=now();await db.query('INSERT INTO conversations(id,owner_id,goal_id,project_id,title,created_at,updated_at) VALUES($1,$2,$3,$4,$5,$6,$6)',[key,user.id,d.goal_id||null,d.project_id||null,d.title,time]);return one(db,'SELECT * FROM conversations WHERE id=$1',[key]);
 },{status:201});
 route('get','/assistant/conversations/:id',async(req,db,user)=>{const c=await one(db,'SELECT * FROM conversations WHERE id=$1 AND owner_id=$2',[req.params.id,user.id]);requireThat(c,'Conversation not found.',404);await context(db,c,user);return {...c,messages:await rows(db,'SELECT * FROM messages WHERE conversation_id=$1 ORDER BY created_at,id',[c.id]),proposals:await rows(db,'SELECT * FROM proposals WHERE conversation_id=$1 ORDER BY created_at',[c.id])};});
 route('delete','/assistant/conversations/:id',async(req,db,user)=>{const c=await one(db,'SELECT id FROM conversations WHERE id=$1 AND owner_id=$2',[req.params.id,user.id]);requireThat(c,'Conversation not found.',404);await db.query('DELETE FROM conversations WHERE id=$1',[c.id]);return {deleted:true};});
 route('post','/assistant/messages',async(req,db,user)=>{
  const d=parse(z.object({conversation_id:uuid,message:z.string().trim().min(1).max(4000),use_cloud:z.boolean().default(false)}).strict(),req.body);
  const c=await one(db,'SELECT * FROM conversations WHERE id=$1 AND owner_id=$2',[d.conversation_id,user.id]);requireThat(c,'Conversation not found.',404);await context(db,c,user);
  const result=await answer(db,user,d.message,c,d.use_cloud);
  let p=null;if(result.actions.length)p=await proposal(db,user,{conversationId:c.id,goalId:c.goal_id,title:'Review proposed actions',explanation:result.message,actions:result.actions});
  const time=now();await db.query('INSERT INTO messages(id,conversation_id,role,body,created_at) VALUES($1,$2,$3,$4,$5)',[id(),c.id,'user',d.message,time]);await db.query('INSERT INTO messages(id,conversation_id,role,body,created_at) VALUES($1,$2,$3,$4,$5)',[id(),c.id,'assistant',result.message,new Date(Date.now()+1).toISOString()]);await db.query('UPDATE conversations SET updated_at=$2 WHERE id=$1',[c.id,time]);return {message:result.message,proposal:p};
 });
 route('post','/goals/:id/ai-decomposition',async(req,db,user)=>{
  const g=await goalAccess(db,req.params.id,user,true),d=parse(z.object({steps:z.number().int().min(1).max(20).default(4)}),req.body);
  return proposal(db,user,{goalId:g.id,title:`Break down ${g.title}`,explanation:'Local structured outline. Adjust the steps and estimates before approval. Work remains unscheduled until the calendar service plans it.',actions:[{kind:'build_goal_plan',reason:'Make the goal actionable with milestones and linked tasks.',payload:{title:g.title,goal_id:g.id,project_id:g.project_id,target_date:g.target_date,max_daily_minutes:120,steps:Array.from({length:d.steps},(_,i)=>({title:['Define the outcome','Prepare the work','Complete the main work','Review and finish'][i]||`Complete step ${i+1}`,estimated_minutes:45,selected:true}))}}]});
 });
 route('get','/assistant/actions',async(req,db,user)=>{const {limit,offset}=pagination(req);const list=await rows(db,"SELECT * FROM proposals WHERE owner_id=$1 AND ($2='' OR status=$2) ORDER BY created_at DESC,id LIMIT $3 OFFSET $4",[user.id,String(req.query.status||''),limit+1,offset]);return {items:list.slice(0,limit),has_more:list.length>limit,offset};});
 route('get','/assistant/actions/:id',async(req,db,user)=>{const p=await ownedProposal(db,req.params.id,user);return {...p,audit:await rows(db,'SELECT * FROM agent_audit WHERE proposal_id=$1 ORDER BY created_at,id',[p.id])};});
 route('patch','/assistant/actions/:id',async(req,db,user)=>{
  const p=await ownedProposal(db,req.params.id,user,true),d=parse(z.object({revision:z.number().int(),actions:z.array(z.unknown())}).strict(),req.body);requireThat(p.status==='pending'&&p.expires_at>now(),'This proposal is no longer editable. Request a new proposal.',409);requireThat(d.revision===p.revision,'This proposal changed. Refresh and review it again.',409);
  const actions=validateActions(d.actions);for(const a of actions)await authorizeAction(db,user,a);await db.query('UPDATE proposals SET actions=$2,revision=revision+1 WHERE id=$1',[p.id,JSON.stringify(actions)]);await audit(db,user,p.id,'edited','Edited the proposal before approval.');return ownedProposal(db,p.id,user);
 });
 route('post','/assistant/actions/:id/reject',async(req,db,user)=>{const p=await ownedProposal(db,req.params.id,user,true);requireThat(p.status==='pending','This proposal has already been handled.',409);await db.query("UPDATE proposals SET status='rejected',resolved_at=$2 WHERE id=$1",[p.id,now()]);await audit(db,user,p.id,'rejected','User rejected the proposal.');return ownedProposal(db,p.id,user);});
 route('post','/assistant/actions/:id/approve',async(req,db,user)=>{
  const p=await ownedProposal(db,req.params.id,user,true);if(p.status==='executed')return p;
  requireThat(p.status==='pending','This proposal has already been handled.',409);requireThat(p.expires_at>now(),'This proposal expired. Request a fresh proposal.',409);
  const d=parse(z.object({revision:z.number().int()}).strict(),req.body);requireThat(d.revision===p.revision,'This proposal changed. Refresh and review it again.',409);
  const actions=validateActions(p.actions);for(const a of actions)await authorizeAction(db,user,a);
  // Product writes and the executed status commit in one transaction. A failure rolls back all writes.
  await audit(db,user,p.id,'approved','User approved the validated action batch.');const result=[];
  for(let i=0;i<actions.length;i++)result.push(await execute(db,user,actions[i],`${p.id}:${i}`));
  await db.query("UPDATE proposals SET status='executed',result=$2,resolved_at=$3 WHERE id=$1",[p.id,JSON.stringify(result),now()]);await audit(db,user,p.id,'executed','Backend confirmed all actions.');return ownedProposal(db,p.id,user);
 },{onError:async(error,req,user)=>{
  // Preserve failure evidence in a separate transaction after the mutation transaction rolls back.
  if(!user)return;await dbRoot.transaction(async db=>{const p=await one(db,'SELECT * FROM proposals WHERE id=$1 AND owner_id=$2 FOR UPDATE',[req.params.id,user.id]);if(p?.status==='pending'){const message=error instanceof ApiError?error.message:'Execution failed; product changes rolled back.';await audit(db,user,p.id,'execution_failed',message);if(!(error instanceof ApiError)||[403,422,500,502,503].includes(error.status))await db.query("UPDATE proposals SET status='failed',error=$2,resolved_at=$3 WHERE id=$1",[p.id,message,now()]);}});
 }});
}
