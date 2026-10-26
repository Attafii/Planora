import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { openDatabase, one } from '../src/database.mjs';
import { createApp } from '../src/app.mjs';
import { streak } from '../src/gamification.mjs';
import { validateActions } from '../src/assistant.mjs';
let db,server,base,owner,viewer,other,project,goal,task,proposal;
async function request(method,url,body,token,extra={}){
 const res=await fetch(base+url,{method,headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{ }),...extra},...(body===undefined?{}:{body:JSON.stringify(body)})});return {status:res.status,data:await res.json()};
}
async function register(name){const r=await request('POST','/auth/register',{name,email:`${name.toLowerCase()}@planify.test`,password:'A-secure-test-passphrase',timezone:'Africa/Tunis'});assert.equal(r.status,201);return r.data;}
before(async()=>{db=await openDatabase({url:'',path:':memory:'});server=createApp(db).listen(0,'127.0.0.1');await new Promise(resolve=>server.once('listening',resolve));base=`http://127.0.0.1:${server.address().port}`;owner=await register('Ahmed');viewer=await register('Viewer');other=await register('Other');});
after(async()=>{await new Promise(resolve=>server.close(resolve));await db.close();});

test('authentication, validation, private data and session revocation',async()=>{
 assert.equal((await request('GET','/goals')).status,401);
 assert.equal((await request('POST','/auth/login',{email:owner.user.email,password:'incorrect-password'})).status,401);
 assert.equal((await request('POST','/auth/register',{name:'Ahmed',email:owner.user.email,password:'secure-passphrase'})).status,409);
 assert.equal((await request('POST','/goals',{title:' ',owner_id:other.user.id},owner.token)).status,422);
 const g=await request('POST','/goals',{title:'Private outcome',start_date:'2026-12-10',target_date:'2026-12-01'},owner.token);assert.equal(g.status,422);
 goal=(await request('POST','/goals',{title:'Private outcome',target_date:'2027-01-10'},owner.token)).data;
 assert.equal((await request('GET',`/goals/${goal.id}`,undefined,other.token)).status,403);
 const login=await request('POST','/auth/login',{email:owner.user.email,password:'A-secure-test-passphrase'});assert.equal(login.status,200);
 await request('POST','/auth/logout',{},login.data.token);assert.equal((await request('GET','/auth/me',undefined,login.data.token)).status,401);
});
test('goal and milestone CRUD, valid task links and server-derived progress',async()=>{
 let m=await request('POST',`/goals/${goal.id}/milestones`,{title:'First chapter',target_date:'2027-01-11'},owner.token);assert.equal(m.status,422);
 m=(await request('POST',`/goals/${goal.id}/milestones`,{title:'First chapter',target_date:'2027-01-01'},owner.token)).data;
 task=(await request('POST','/tasks',{title:'Study the chapter',estimated_minutes:45,milestone_id:m.id},owner.token)).data;
 await request('POST',`/goals/${goal.id}/tasks`,{task_id:task.id},owner.token);
 assert.equal((await request('GET',`/goals/${goal.id}`,undefined,owner.token)).data.progress,0);
 assert.equal((await request('PATCH',`/goals/${goal.id}/milestones/${m.id}`,{title:m.title,completed:true},owner.token)).status,409);
 assert.equal((await request('PATCH',`/tasks/${task.id}`,{status:'completed'},owner.token)).status,200);
 assert.equal((await request('GET',`/goals/${goal.id}`,undefined,owner.token)).data.progress,100);
 await request('PATCH',`/goals/${goal.id}/milestones/${m.id}`,{title:m.title,completed:true},owner.token);
 assert.equal((await request('PATCH',`/goals/${goal.id}`,{title:goal.title,target_date:goal.target_date,status:'completed'},owner.token)).status,200);
 const list=await request('GET','/goals?search=Private&limit=1',undefined,owner.token);assert.equal(list.data.items.length,1);
 const badDate=await request('POST','/goals',{title:'Invalid date',target_date:'2026-02-30'},owner.token);assert.equal(badDate.status,422);
});
test('invitations are account-bound, revocable, single-use and permission-safe',async()=>{
 project=(await request('POST','/projects',{title:'Shared revision',description:'Study together'},owner.token)).data;
 let r=await request('POST',`/projects/${project.id}/invitations`,{email:viewer.user.email,role:'viewer'},owner.token);assert.equal(r.status,201);const inv=r.data;
 assert.equal((await request('GET',`/invitations/${inv.token}`,undefined,other.token)).status,403);
 assert.equal((await request('POST',`/invitations/${inv.token}/respond`,{accept:true},viewer.token)).status,200);
 assert.equal((await request('POST',`/invitations/${inv.token}/respond`,{accept:true},viewer.token)).status,409);
 assert.equal((await request('POST',`/projects/${project.id}/comments`,{body:'Cannot write'},viewer.token)).status,403);
 assert.equal((await request('PATCH',`/projects/${project.id}/members/${owner.user.id}`,{role:'viewer'},owner.token)).status,409);
 r=await request('POST',`/projects/${project.id}/invitations`,{email:other.user.email,role:'collaborator'},owner.token);const revoked=r.data;
 await request('POST',`/projects/${project.id}/invitations/${revoked.id}/revoke`,{},owner.token);
 assert.equal((await request('POST',`/invitations/${revoked.token}/respond`,{accept:true},other.token)).status,409);
 r=await request('POST',`/projects/${project.id}/invitations`,{email:other.user.email,role:'collaborator'},owner.token);
 await db.query('UPDATE invitations SET expires_at=$2 WHERE id=$1',[r.data.id,'2000-01-01T00:00:00.000Z']);
 assert.equal((await request('POST',`/invitations/${r.data.token}/respond`,{accept:true},other.token)).status,410);
});
test('assignment, mentions, comment editing, activity and role revocation',async()=>{
 await request('PATCH',`/projects/${project.id}/members/${viewer.user.id}`,{role:'collaborator'},owner.token);
 const shared=(await request('POST','/tasks',{title:'Shared task',project_id:project.id},owner.token)).data;
 assert.equal((await request('POST',`/projects/${project.id}/assignments`,{task_id:task.id,user_id:viewer.user.id},owner.token)).status,422);
 assert.equal((await request('POST',`/projects/${project.id}/assignments`,{task_id:shared.id,user_id:viewer.user.id},owner.token)).status,200);
 assert.equal((await request('PATCH',`/tasks/${shared.id}`,{status:'completed'},viewer.token)).status,200);
 const c=await request('POST',`/projects/${project.id}/comments`,{body:'Ready to review',mentions:[owner.user.id]},viewer.token);assert.equal(c.status,201);
 assert.equal((await request('POST',`/projects/${project.id}/comments`,{body:'Invalid mention',mentions:[other.user.id]},viewer.token)).status,403);
 assert.equal((await request('PATCH',`/projects/${project.id}/comments/${c.data.id}`,{body:'Reviewed'},viewer.token)).status,200);
 const activity=await request('GET',`/projects/${project.id}/activity?limit=2`,undefined,owner.token);assert.equal(activity.data.items.length,2);assert.equal(activity.data.has_more,true);
 await request('PATCH',`/projects/${project.id}/members/${viewer.user.id}`,{role:'viewer'},owner.token);
 assert.equal((await request('PATCH',`/tasks/${shared.id}`,{status:'todo'},viewer.token)).status,403);
 const detail=await request('GET',`/projects/${project.id}`,undefined,owner.token);assert.equal(detail.data.progress,100);assert.equal(detail.data.tasks[0].assignee_id,null);
});
test('assistant proposals are editable, rejected without writes and idempotently approved',async()=>{
 const c=(await request('POST','/assistant/conversations',{title:'Revision'},owner.token)).data;
 const beforeCount=Number((await one(db,'SELECT COUNT(*) AS n FROM tasks')).n);
 const r=await request('POST','/assistant/messages',{conversation_id:c.id,message:'Plan four chapters before Friday, maximum two hours per day'},owner.token);assert.equal(r.status,200);proposal=r.data.proposal;assert.equal(proposal.actions[0].payload.steps.length,4);
 assert.equal(Number((await one(db,'SELECT COUNT(*) AS n FROM tasks')).n),beforeCount);
 assert.equal((await request('GET',`/assistant/actions/${proposal.id}`,undefined,other.token)).status,404);
 await request('POST',`/assistant/actions/${proposal.id}/reject`,{},owner.token);assert.equal(Number((await one(db,'SELECT COUNT(*) AS n FROM tasks')).n),beforeCount);
 const r2=await request('POST','/assistant/messages',{conversation_id:c.id,message:'Plan four chapters before 2027-01-20'},owner.token);proposal=r2.data.proposal;
 const actions=proposal.actions.map(({kind,payload,reason})=>({kind,payload,reason}));actions[0].payload.steps[0].title='Review chapter one carefully';actions[0].payload.steps[3].selected=false;
 let edit=await request('PATCH',`/assistant/actions/${proposal.id}`,{revision:proposal.revision,actions},owner.token);assert.equal(edit.status,200);proposal=edit.data;
 assert.equal((await request('POST',`/assistant/actions/${proposal.id}/approve`,{revision:1},owner.token)).status,409);
 const applied=await request('POST',`/assistant/actions/${proposal.id}/approve`,{revision:proposal.revision},owner.token);assert.equal(applied.status,200);assert.equal(applied.data.status,'executed');assert.equal(applied.data.result[0].created_tasks,3);
 const repeated=await request('POST',`/assistant/actions/${proposal.id}/approve`,{revision:proposal.revision},owner.token);assert.equal(repeated.status,200);
 assert.equal(Number((await one(db,'SELECT COUNT(*) AS n FROM tasks')).n),beforeCount+3);
 const detail=await request('GET',`/assistant/actions/${proposal.id}`,undefined,owner.token);assert.ok(detail.data.audit.some(a=>a.event==='executed'));
 assert.throws(()=>validateActions([{kind:'create_task',payload:{title:'Injected',owner_id:other.user.id},reason:'Test'}]));
});
test('approval rollback preserves failure audit and does not leak partial product writes',async()=>{
 const c=(await request('POST','/assistant/conversations',{title:'Atomicity'},owner.token)).data;
 const r=await request('POST','/assistant/messages',{conversation_id:c.id,message:'Create task: temporary draft'},owner.token);let p=r.data.proposal;
 const edited=await request('PATCH',`/assistant/actions/${p.id}`,{revision:p.revision,actions:[{kind:'create_task',payload:{title:'Should roll back'},reason:'First step'},{kind:'create_goal',payload:{title:'Invalid interval',start_date:'2027-02-20',target_date:'2027-02-01'},reason:'Second step'}]},owner.token);assert.equal(edited.status,200);p=edited.data;
 const n=Number((await one(db,'SELECT COUNT(*) AS n FROM tasks')).n);
 assert.equal((await request('POST',`/assistant/actions/${p.id}/approve`,{revision:p.revision},owner.token)).status,422);
 assert.equal(Number((await one(db,'SELECT COUNT(*) AS n FROM tasks')).n),n);
 const detail=await request('GET',`/assistant/actions/${p.id}`,undefined,owner.token);assert.equal(detail.data.status,'failed');assert.ok(detail.data.audit.some(a=>a.event==='execution_failed'));
});
test('achievement events are deduplicated, trusted integrations restricted, challenges persist',async()=>{
 await request('PATCH',`/tasks/${task.id}`,{status:'completed'},owner.token);
 const s=await request('GET','/gamification/summary',undefined,owner.token);assert.equal(s.data.achievements.find(b=>b.id==='first_task').progress,1);assert.equal(s.data.achievements.find(b=>b.id==='first_goal').earned,true);
 assert.equal((await request('POST','/integrations/events',{user_id:owner.user.id,kind:'focus_completed',entity_id:'focus-1'})).status,403);
 process.env.INTEGRATION_TOKEN='trusted-test-service-secret';
 await request('POST','/integrations/events',{user_id:owner.user.id,kind:'focus_completed',entity_id:'focus-1'},undefined,{'X-Integration-Token':process.env.INTEGRATION_TOKEN});
 await request('POST','/integrations/events',{user_id:owner.user.id,kind:'focus_completed',entity_id:'focus-1'},undefined,{'X-Integration-Token':process.env.INTEGRATION_TOKEN});
 delete process.env.INTEGRATION_TOKEN;
 assert.equal(Number((await one(db,"SELECT COUNT(*) AS n FROM productivity_events WHERE user_id=$1 AND kind='focus_completed'",[owner.user.id])).n),1);
 assert.equal((await request('POST','/challenges/five_steps/join',{},owner.token)).status,200);
 assert.equal((await request('POST','/challenges/five_steps/join',{},owner.token)).status,409);
 assert.equal((await request('GET','/challenges',undefined,owner.token)).data.find(c=>c.id==='five_steps').status,'active');
 await request('POST','/challenges/five_steps/leave',{},owner.token);
 assert.equal(streak([{kind:'task_completed',occurred_at:'2026-10-09T12:00:00Z'}],'UTC',new Date('2026-10-12T10:00:00Z')),1);
});
test('embedded PostgreSQL survives database close and reopen',async()=>{
 const directory=await mkdtemp(join(tmpdir(),'planify-pg-'));
 try{let store=await openDatabase({url:'',path:directory});await store.query('INSERT INTO users(id,name,email,password_hash,created_at) VALUES($1,$2,$3,$4,$5)',['persistent-user','Persisted','persisted@planify.test','hash','2026-01-01T00:00:00Z']);await store.close();store=await openDatabase({url:'',path:directory});assert.equal((await one(store,'SELECT name FROM users WHERE id=$1',['persistent-user'])).name,'Persisted');await store.close();}finally{await rm(directory,{recursive:true,force:true});}
});
