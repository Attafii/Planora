import { test } from 'node:test';
import assert from 'node:assert/strict';
import { openDatabase } from '../src/database.mjs';
import { readWorkspace, executePersonal as execute } from '../src/agent_workspace.mjs';
import { personalTaskView } from '../src/work_progress.mjs';

const executePersonal = (db,user,action) => db.transaction(tx => execute(tx,user,action));

async function fixture() {
 const db=await openDatabase({url:'',path:':memory:'});
 await db.query('CREATE SCHEMA planify_account');
 await db.query('CREATE TABLE planify_account.personal_sync(user_id TEXT,collection TEXT,revision INTEGER,snapshot TEXT,PRIMARY KEY(user_id,collection))');
 const user={id:'owner',timezone:'Africa/Tunis',personalActions:true};
 return {db,user};
}
test('personal actions preserve sync contracts, batch writes, stale detection and dependencies',async()=>{
 const {db,user}=await fixture();
 try {
  await executePersonal(db,user,{kind:'create_personal_task',payload:{title:'First',minutes:25,revision:0}});
  await executePersonal(db,user,{kind:'create_personal_task',payload:{title:'Second',minutes:15,revision:0}});
  let current=(await db.query("SELECT * FROM planify_account.personal_sync WHERE user_id='owner'")).rows[0];
  assert.equal(current.revision,2);const tasks=JSON.parse(current.snapshot);assert.equal(tasks.length,2);
  assert.equal(personalTaskView(current.snapshot).size,2);
  await assert.rejects(executePersonal(db,{...user,agentRevisionOffsets:{}},{kind:'create_personal_task',payload:{title:'Stale',minutes:25,revision:0}}),e=>e.code==='stale_proposal');
  tasks[1].requires=[tasks[0].id];
  await db.query('UPDATE planify_account.personal_sync SET snapshot=$1',[JSON.stringify(tasks)]);
  await assert.rejects(executePersonal(db,{...user,agentRevisionOffsets:{}},{kind:'complete_personal_task',payload:{personal_task_id:tasks[1].id,revision:2}}),/prerequisites/);
  const second={...user,id:'another',agentRevisionOffsets:{}};
  await executePersonal(db,second,{kind:'create_personal_task',payload:{title:'Private',minutes:25,revision:0}});
  assert.equal((await db.query("SELECT revision FROM planify_account.personal_sync WHERE user_id='owner'")).rows[0].revision,2);
 } finally {await db.close();}
});
test('calendar events reject overlaps and invalid dates while preserving previous plans',async()=>{
 const {db,user}=await fixture();
 try {
  const event={kind:'create_calendar_event',payload:{title:'Meeting',date:'2026-11-23',start:600,end:660,kind:'commitment',timezone:'Africa/Tunis',revision:0}};
  await executePersonal(db,user,event);
  const before=(await db.query("SELECT * FROM planify_account.personal_sync WHERE user_id='owner'")).rows[0];
  const stored=JSON.parse(before.snapshot)['2026-11-23'];assert.equal(stored.reserved.length,2);assert.equal(stored.reserved[0].title,'Lunch');
  await assert.rejects(executePersonal(db,{...user,agentRevisionOffsets:{}},{...event,payload:{...event.payload,revision:1,start:630}}),/overlaps/);
  await assert.rejects(executePersonal(db,{...user,agentRevisionOffsets:{}},{...event,payload:{...event.payload,revision:1,date:'2026-02-30'}}),/valid same-day/);
  for (const [date,start,end] of [['2027-03-14',150,180],['2026-11-01',90,120]]) await assert.rejects(executePersonal(db,{...user,timezone:'America/New_York',agentRevisionOffsets:{}},{...event,payload:{...event.payload,revision:1,date,start,end,timezone:'America/New_York'}}),/ambiguous or unavailable/);
  assert.equal((await db.query("SELECT snapshot FROM planify_account.personal_sync WHERE user_id='owner'")).rows[0].snapshot,before.snapshot);
 } finally {await db.close();}
});
test('statistics distinguish missing personal/focus data and count full stored records',async()=>{
 const {db,user}=await fixture();
 try {
  const empty=await readWorkspace(db,user);assert.equal(empty.recorded_focus_seconds,null);assert.equal(empty.personal_tasks,null);assert.equal(empty.charts.length,1);
  user.personalTasks=personalTaskView(JSON.stringify([{id:'a',title:'Done',done:true,skipped:false,minutes:25}]));
  user.personalCollections={focus:{snapshot:JSON.stringify({sessions:[{id:'a',status:'completed',seconds:90},{id:'a',status:'completed',seconds:90},{id:'b',status:'cancelled',seconds:300},{id:'c',status:'paused',seconds:400}]})}};
  const facts=await readWorkspace(db,user);assert.equal(facts.recorded_focus_seconds,90);assert.equal(facts.charts[1].items.find(i=>i.label==='completed').value,1);
 } finally {await db.close();}
});
