import {test} from 'node:test';
import assert from 'node:assert/strict';
import {validate,createServer} from './server.mjs';
test('Bounds model actions and rejects past reminder times',()=>{
 assert.throws(()=>validate({kind:'focus',title:'Work',reason:'Help',minutes:999,steps:['Read']},'focus'));
 assert.throws(()=>validate({kind:'reminder',title:'Work',reason:'Help',when:'2000-01-01',repeat:'Once'},'reminder'));
 assert.equal(validate({kind:'focus',title:'Work',reason:'Help',minutes:25,steps:['Read']},'focus').minutes,25);
});
test('Unconfigured AI returns an explicit error without fabricated output',async()=>{
 const old=process.env.AI_API_KEY;delete process.env.AI_API_KEY;
 const server=createServer();await new Promise(r=>server.listen(0,'127.0.0.1',r));
 try{const r=await fetch(`http://127.0.0.1:${server.address().port}/propose`,{method:'POST',body:'{}'});assert.equal(r.status,503);assert.match((await r.json()).error,/not configured/);}
 finally{await new Promise(r=>server.close(r));if(old)process.env.AI_API_KEY=old;}
});

test('Both agents call their read tools and validate final proposals with a simulated provider',async()=>{
 const {default:http}=await import('node:http');
 const oldKey=process.env.AI_API_KEY,oldModel=process.env.AI_MODEL;
 process.env.AI_API_KEY='local-test-only';process.env.AI_MODEL='simulated-test';
 let calls=0;
 const fake=http.createServer(async(req,res)=>{
  let raw='';for await(const c of req)raw+=c;const body=JSON.parse(raw);calls++;
  const focus=body.messages[0].content.includes('focus agent');
  const name=focus?'read_focus_stats':'read_reminder_load';
  if(!body.messages.some(m=>m.role==='tool'))res.end(JSON.stringify({choices:[{message:{role:'assistant',content:null,tool_calls:[{id:'call1',type:'function',function:{name,arguments:'{}'}}]}}]}));
  else{
   assert.equal(body.messages.find(m=>m.role==='tool').tool_call_id,'call1');
   const proposal=focus?{kind:'focus',title:'Read',reason:'Short block',minutes:20,steps:['Read a page']}:{kind:'reminder',title:'Stretch',reason:'Requested time',when:new Date(Date.now()+86400000).toISOString(),repeat:'Daily'};
   res.end(JSON.stringify({choices:[{message:{role:'assistant',content:JSON.stringify(proposal)}}]}));
  }
 });
 await new Promise(r=>fake.listen(0,'127.0.0.1',r));
 const app=createServer({providerUrl:`http://127.0.0.1:${fake.address().port}`});await new Promise(r=>app.listen(0,'127.0.0.1',r));
 try{for(const kind of ['focus','reminder']){
  const r=await fetch(`http://127.0.0.1:${app.address().port}/propose`,{method:'POST',body:JSON.stringify({kind,input:'Help me plan',now:new Date().toISOString(),offsetMinutes:60,context:{completed:[{seconds:1200,interruptions:0}],reminders:[]}})});
  assert.equal(r.status,200);assert.equal((await r.json()).kind,kind);
 }assert.equal(calls,4);}
 finally{await new Promise(r=>app.close(r));await new Promise(r=>fake.close(r));if(oldKey===undefined)delete process.env.AI_API_KEY;else process.env.AI_API_KEY=oldKey;if(oldModel===undefined)delete process.env.AI_MODEL;else process.env.AI_MODEL=oldModel;}
});
