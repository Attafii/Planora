import { z } from 'zod';
import { rows, one } from './database.mjs';
import { id, requireThat } from './core.mjs';
import { personalTaskView } from './work_progress.mjs';

const revision = z.number().int().nonnegative().optional();
export const personalSchemas = {
 create_personal_task: z.object({ title: z.string().trim().min(1).max(120), minutes: z.number().int().min(1).max(1440), due: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable().optional(), revision }).strict(),
 complete_personal_task: z.object({ personal_task_id: z.string().min(1).max(120), personal_task_title:z.string().max(120).optional(), revision }).strict(),
 create_calendar_event: z.object({ title: z.string().trim().min(1).max(120), date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/), start: z.number().int().min(0).max(1438), end: z.number().int().min(1).max(1439), kind: z.enum(['commitment','pause']), timezone:z.string().max(100).optional(), revision }).strict(),
};
export const collectionFor = kind => kind === 'create_calendar_event' ? 'planning' : 'tasks';
export function decodeCollection(user, name) {
 try { return user.personalCollections?.[name] ? JSON.parse(user.personalCollections[name].snapshot) : null; } catch { return null; }
}
export async function readWorkspace(db, user) {
 const personal = user.personalTasks;
 const project = await rows(db, `SELECT t.id,t.title,t.status,t.estimated_minutes,t.deadline,t.project_id FROM tasks t WHERE (t.owner_id=$1 AND t.project_id IS NULL) OR EXISTS(SELECT 1 FROM project_members m WHERE m.project_id=t.project_id AND m.user_id=$1) ORDER BY t.id`, [user.id]);
 const rawTasks=decodeCollection(user,'tasks');
 const rawMap=new Map((Array.isArray(rawTasks)?rawTasks:[]).map(t=>[t.id,t]));
 const personalList = personal == null ? null : [...personal.values()].map(task=>{const raw=rawMap.get(task.id);const prerequisites=raw?.requires??[];const blockers=prerequisites.filter(key=>personal.get(key)?.status!=='completed');return {...task,readiness:raw?task.status==='completed'?'completed':blockers.length?'blocked':(Array.isArray(rawTasks)&&rawTasks.some(t=>t.parent===task.id&&!t.skipped))?'has_subtasks':'ready':'unknown',blockers};});
 const chart = (key, title, items) => ({ key, title, unit: 'tasks', source: 'Last synchronized task records', generated_at: new Date().toISOString(), items });
 const charts = [chart('workspace_tasks', 'Workspace tasks', ['todo','in_progress','blocked','completed','archived','cancelled'].map(label => ({label, value: project.filter(t => t.status === label).length})))];
 if (personalList != null) charts.push(chart('personal_tasks','Personal tasks', ['todo','completed'].map(label => ({label,value:personalList.filter(t=>t.status===label).length}))));
 const focus = decodeCollection(user,'focus');
 const sessions = Array.isArray(focus?.sessions) ? [...new Map(focus.sessions.filter(s=>s && typeof s.id==='string').map(s=>[s.id,s])).values()] : null;
 const seconds = sessions == null ? null : sessions.filter(s=>['completed','endedEarly'].includes(s.status) && Number.isFinite(s.seconds) && s.seconds>=0).reduce((sum,s)=>sum+s.seconds,0);
 if (sessions != null) charts.push({key:'focus_time',title:'All saved focus activity',unit:'seconds',source:'Saved completed and ended-early sessions only',generated_at:new Date().toISOString(),items:['completed','endedEarly'].map(label=>({label,value:sessions.filter(s=>s.status===label&&Number.isFinite(s.seconds)&&s.seconds>=0).reduce((sum,s)=>sum+s.seconds,0)}))});
 return { as_of: new Date().toISOString(), personal_source: personalList == null ? 'unavailable; sync My tasks first' : 'last synced; device-only edits are not included', personal_tasks: personalList?.slice(0,150) ?? null, workspace_tasks: project.slice(0,150), workspace_task_count: project.length, task_list_truncated: project.length>150 || (personalList?.length ?? 0)>150, recorded_focus_seconds:seconds, focus_source:sessions==null?'unavailable':'saved completed and ended-early sessions; paused and abandoned time excluded', charts };
}
// A nonexistent or ambiguous civil time must be corrected in the calendar.
function validCivilTime(day, minute, timezone) {
 const formatter = new Intl.DateTimeFormat('en-CA',{timeZone:timezone,year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hourCycle:'h23'});
 const target = `${day} ${String(Math.floor(minute/60)).padStart(2,'0')}:${String(minute%60).padStart(2,'0')}`;
 const noon = Date.parse(day+'T12:00:00Z'); let matches=0;
 for(let offset=-30*60+minute%15;offset<=30*60;offset+=15){const parts=Object.fromEntries(formatter.formatToParts(new Date(noon+offset*60000)).map(p=>[p.type,p.value]));if(`${parts.year}-${parts.month}-${parts.day} ${parts.hour}:${parts.minute}`===target) matches++;}
 return matches===1;
}
export async function executePersonal(db,user,action) {
 const collection=collectionFor(action.kind), p=action.payload;
 requireThat(user.personalActions,'Personal actions require the shared Neon backend. Open the normal task or calendar flow instead.',503);
 // Serializes absence as well as existing rows, using the same lock as Eya sync.
 await db.query('LOCK TABLE planify_account.personal_sync IN SHARE ROW EXCLUSIVE MODE');
 const current=await one(db,'SELECT revision,snapshot FROM planify_account.personal_sync WHERE user_id=$1 AND collection=$2',[user.id,collection]);
 requireThat((current?.revision??0)===p.revision+(user.agentRevisionOffsets?.[collection]??0),'Your work changed after this proposal. Sync and ask for a fresh proposal.',409,'stale_proposal');
 let snapshot=current ? JSON.parse(current.snapshot) : collection==='tasks'?[]:{};
 if(action.kind==='create_personal_task' && p.due) requireThat(Number.isFinite(Date.parse(p.due)) && new Date(p.due+'T12:00:00Z').toISOString().slice(0,10)===p.due,'Choose a valid due date.',422);
 if(action.kind==='create_personal_task') snapshot.push({id:id(),title:p.title,minutes:p.minutes,energy:'medium',activity:'general',due:p.due??null,done:false,skipped:false,parent:null,requires:[],repeat:'once',until:null,seriesId:null});
 if(action.kind==='complete_personal_task') {
  const task=snapshot.find(t=>t.id===p.personal_task_id);
  requireThat(task&&!task.skipped&&(task.repeat??'once')==='once','This task is no longer available. Open My tasks to review it.',409);
  const view=personalTaskView(JSON.stringify(snapshot));
  requireThat((task.requires??[]).every(key=>view?.get(key)?.status==='completed')&&!snapshot.some(t=>t.parent===task.id&&view?.get(t.id)?.status!=='completed'),'Finish the prerequisites and subtasks first.',409);
  task.done=true;
 }
 if(action.kind==='create_calendar_event') {
  requireThat(p.timezone===user.timezone,'Your timezone changed after this proposal. Request a fresh proposal.',409,'stale_proposal');
  requireThat(p.start<p.end&&Number.isFinite(Date.parse(p.date))&&new Date(p.date+'T12:00:00Z').toISOString().slice(0,10)===p.date,'Choose a valid same-day interval.',422);
  requireThat(validCivilTime(p.date,p.start,user.timezone)&&validCivilTime(p.date,p.end,user.timezone),'This time is ambiguous or unavailable in your timezone. Choose another time in Calendar.',422);
  const day=snapshot[p.date]??{start:540,end:1020,reserved:[{id:'lunch',title:'Lunch',start:720,end:780,kind:'pause'}],approved:[],history:[],version:0,windows:{}};
  requireThat(![...day.reserved,...day.approved].some(b=>b.start<p.end&&p.start<b.end),'This event overlaps existing work or a break. Revise the proposal or use Calendar to replan.',409);
  day.reserved.push({id:id(),title:p.title,start:p.start,end:p.end,kind:p.kind});day.version++;snapshot[p.date]=day;
 }
 await db.query(`INSERT INTO planify_account.personal_sync(user_id,collection,revision,snapshot) VALUES($1,$2,$3,$4) ON CONFLICT(user_id,collection) DO UPDATE SET revision=EXCLUDED.revision,snapshot=EXCLUDED.snapshot`,[user.id,collection,(current?.revision??0)+1,JSON.stringify(snapshot)]);
 user.agentRevisionOffsets ??= {}; user.agentRevisionOffsets[collection]=(user.agentRevisionOffsets[collection]??0)+1;
 return {collection,revision:(current?.revision??0)+1,message:'Saved to your account. Sync the daily workspace to receive this change.'};
}
