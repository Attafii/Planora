import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { createApi } from './server.mjs';
test('account AI requires context consent, validates output, minimizes context and rejects stale sync metadata',async()=>{
 const previous=Object.fromEntries(['AI_API_KEY','AI_MODEL','AI_BASE_URL'].map(k=>[k,process.env[k]]));let context,calls=0,invalid=false;
 const provider=createServer(async(req,res)=>{let raw='';for await(const c of req)raw+=c;const body=JSON.parse(raw);context=JSON.parse(body.messages[1].content);calls++;const setup=body.messages[0].content.includes('Suggest preferences');res.end(JSON.stringify({choices:[{message:{content:JSON.stringify({message:'Review these choices; nothing changed.',actions:setup?[{kind:'suggest_preferences',payload:{timezone:'Africa/Tunis',theme:invalid?'invalid':'dark',language:'fr'},reason:'Explicit request'}]:[]})}}]}));});
 await new Promise(r=>provider.listen(0,'127.0.0.1',r));
 process.env.AI_API_KEY='synthetic';process.env.AI_MODEL='test';process.env.AI_BASE_URL=`http://127.0.0.1:${provider.address().port}`;
 const api=createApi({database:':memory:'});await api.ready;await new Promise(r=>api.listen(0,'127.0.0.1',r));let token;
 async function call(path,body,method=body?'POST':'GET'){const r=await fetch(`http://127.0.0.1:${api.address().port}`+path,{method,headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},...(body?{body:JSON.stringify(body)}:{})});return {status:r.status,data:await r.json()};}
 try{
 token=(await call('/auth/register',{name:'Synthetic',email:'qa@example.test',password:'Synthetic-password-2026',timezone:'Africa/Tunis'})).data.token;
 assert.equal((await call('/users/me/setup-assist',{needs:'French dark mode',context_consent:true})).status,403);assert.equal(calls,0);
 await call('/users/me/preferences',{cloud_ai:true},'PATCH');
 assert.equal((await call('/users/me/setup-assist',{needs:'French dark mode',context_consent:false})).status,422);assert.equal(calls,0);
 const result=await call('/users/me/setup-assist',{needs:'French dark mode',context_consent:true});assert.equal(result.status,200);assert.equal(result.data.suggestions.theme,'dark');assert.deepEqual(Object.keys(context).sort(),['current','needs']);assert.doesNotMatch(JSON.stringify(context),/qa@example|password_hash|token/);
 assert.equal((await call('/users/me')).data.preferences.theme,'system');invalid=true;
 assert.equal((await call('/users/me/setup-assist',{needs:'French dark mode',context_consent:true})).status,502);
 const metadata={collection:'tasks',base_revision:0,remote_revision:9,counts:{added:1,removed:0,changed:0},context_consent:true};const before=calls;
 assert.equal((await call('/users/me/sync-assist',metadata)).status,409);assert.equal(calls,before);
 assert.equal((await call('/users/me/sync-assist',{...metadata,remote_revision:0})).status,200);assert.equal(context.timestamps,'unavailable');
 }finally{await new Promise(r=>api.close(r));await new Promise(r=>provider.close(r));for(const[k,v]of Object.entries(previous)){if(v===undefined)delete process.env[k];else process.env[k]=v;}}
});
