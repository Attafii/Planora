import { test } from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { createApi } from './server.mjs';
import { mkdtempSync, readdirSync, unlinkSync, rmdirSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

async function fixture(options = {}) {
  const server = createApi({ database: ':memory:', ...options });
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  const call = async (path, method='GET', body, token) => {
    const response = await fetch(`http://127.0.0.1:${server.address().port}${path}`, { method, headers: { 'content-type':'application/json', ...(token ? {authorization:`Bearer ${token}`} : {}) }, ...(body !== undefined ? {body:JSON.stringify(body)} : {}) });
    return {status:response.status, data:await response.json()};
  };
  return { server, call, close:() => new Promise(resolve => server.close(resolve)) };
}
const credentials = (email='eya@example.com') => ({name:'Eya',email,password:'A long private password',timezone:'Africa/Tunis'});

test('registration, normalized identity, login, persistence, expiry and revoke', async t => {
  let clock=Date.now(); const f=await fixture({clock:()=>clock,sessionMs:60000});t.after(f.close);
  const registered=await f.call('/auth/register','POST',credentials(' EYA@example.com '));
  assert.equal(registered.status,201);
  const {token,user}=registered.data;
  assert.equal(user.email,'eya@example.com');assert.equal(user.email_verified_at,null);assert.equal(user.preferences.cloud_ai,false);
  assert.equal(user.password_hash,undefined);assert.equal(user.salt,undefined);
  assert.equal((await f.call('/users/me','GET',undefined,token)).data.id,user.id);
  assert.equal((await f.call('/auth/login','POST',{email:user.email,password:credentials().password})).status,200);
  assert.equal((await f.call('/auth/logout','POST',{},token)).status,200);
  assert.equal((await f.call('/auth/logout','POST',{},token)).status,200);
  assert.equal((await f.call('/users/me','GET',undefined,token)).status,401);
  const login=await f.call('/auth/login','POST',{email:user.email,password:credentials().password});clock+=60001;
  assert.equal((await f.call('/users/me','GET',undefined,login.data.token)).status,401);
});

test('strict input validation and duplicate email handling',async t=>{
  const f=await fixture();t.after(f.close);
  for(const patch of [{email:'oops'},{name:'a'},{password:'weak'},{timezone:'Made/Up'},{language:'xx'},{role:'admin'}]) assert.equal((await f.call('/auth/register','POST',{...credentials(),...patch})).status,422);
  assert.equal((await f.call('/auth/register','POST',credentials())).status,201);
  const duplicate=await f.call('/auth/register','POST',credentials());assert.equal(duplicate.status,409);assert.ok(duplicate.data.error.fields.email);
});

test('generic login errors and reset unavailable without false success',async t=>{
  const f=await fixture();t.after(f.close);await f.call('/auth/register','POST',credentials());
  const known=await f.call('/auth/login','POST',{email:'eya@example.com',password:'wrong'});
  const unknown=await f.call('/auth/login','POST',{email:'unknown@example.com',password:'wrong'});
  assert.equal(known.status,401);assert.deepEqual(known,unknown);
  const reset=await f.call('/auth/password-reset','POST',{email:'eya@example.com'});
  assert.equal(reset.status,503);assert.deepEqual(reset,await f.call('/auth/password-reset','POST',{email:'unknown@example.com'}));
  assert.equal((await f.call('/auth/password-reset/confirm','POST',{token:'fake'})).status,503);
});

test('two-account isolation, preferences persist, forbidden fields rejected',async t=>{
  const f=await fixture();t.after(f.close);
  const a=(await f.call('/auth/register','POST',credentials())).data;
  const b=(await f.call('/auth/register','POST',credentials('ahmed@example.com'))).data;
  assert.equal((await f.call('/users/me','PATCH',{name:'Eya Updated'},a.token)).data.name,'Eya Updated');
  const updated=await f.call('/users/me/preferences','PATCH',{timezone:'Europe/Paris',language:'fr',theme:'dark',cloud_ai:true},a.token);
  assert.equal(updated.status,200);assert.equal(updated.data.preferences.cloud_ai,true);assert.ok(updated.data.preferences.consent_updated_at);
  const restored=(await f.call('/users/me','GET',undefined,a.token)).data;assert.equal(restored.timezone,'Europe/Paris');assert.equal(restored.language,'fr');
  assert.equal((await f.call('/users/me','GET',undefined,b.token)).data.timezone,'Africa/Tunis');
  await f.call('/users/me/preferences','PATCH',{cloud_ai:false},a.token);
  assert.equal((await f.call('/users/me/preferences','GET',undefined,a.token)).data.cloud_ai,false);
  for(const [path,body] of [['/users/me',{name:'Xx',id:b.user.id}],['/users/me',{name:'Xx',email:'change@example.com'}],['/users/me/preferences',{cloud_ai:'yes'}],['/users/me/preferences',{timezone:'Unknown'}],['/users/me/preferences',{theme:'neon'}]])assert.equal((await f.call(path,'PATCH',body,a.token)).status,422);
  for(const path of ['/users/me','/users/me/preferences','/users/me/analytics'])assert.equal((await f.call(path)).status,401);
});

test('insights distinguish missing sources from zero and enforce date ranges',async t=>{
  const f=await fixture();t.after(f.close);const {token}=(await f.call('/auth/register','POST',credentials())).data;
  const analytics=await f.call('/users/me/analytics?from=2026-10-01T00:00:00Z&to=2026-11-01T00:00:00Z','GET',undefined,token);
  assert.equal(analytics.status,200);assert.equal(analytics.data.tasks_completed,null);assert.equal(analytics.data.status,'unavailable');assert.equal(analytics.data.range.end_exclusive,true);assert.equal('focus_minutes' in analytics.data,false);
  for(const query of ['','?from=bad&to=bad','?from=2026-11-01T00:00:00Z&to=2026-10-01T00:00:00Z','?from=2020-01-01T00:00:00Z&to=2026-10-01T00:00:00Z'])assert.equal((await f.call('/users/me/analytics'+query,'GET',undefined,token)).status,422);
  assert.equal((await f.call('/users/me','DELETE',{},token)).status,503);
  assert.equal((await f.call('/users/me/export','POST',{},token)).status,503);
  assert.equal((await f.call('/users/me','GET',undefined,token)).status,200);
});

test('rate limits apply to repeated authentication attempts',async t=>{
  const f=await fixture();t.after(f.close);
  for(let i=0;i<20;i++)await f.call('/auth/password-reset','POST',{});
  assert.equal((await f.call('/auth/login','POST',{email:'eya@example.com',password:'x'})).status,429);
});

test('SQLite survives API restart without storing raw tokens or passwords',async t=>{
  const folder=mkdtempSync(join(tmpdir(),'planify-'));
  const database=join(folder,'test.sqlite');const first=await fixture({database});
  const {token}=(await first.call('/auth/register','POST',credentials())).data;
  await first.call('/users/me/preferences','PATCH',{language:'fr'},token);await first.close();
  const second=await fixture({database});t.after(async()=>{await second.close();const contents=readFileSync(database);assert.equal(contents.includes(Buffer.from(token)),false);assert.equal(contents.includes(Buffer.from(credentials().password)),false);for(const file of readdirSync(folder))unlinkSync(join(folder,file));rmdirSync(folder);});
  const profile=await second.call('/users/me','GET',undefined,token);assert.equal(profile.status,200);assert.equal(profile.data.language,'fr');
});

test('personal collections use account revisions and support retry after a lost response', async t => {
  const f = await fixture();
  t.after(f.close);
  const a = (await f.call('/auth/register', 'POST', credentials())).data;
  const b = (await f.call('/auth/register', 'POST', credentials('other@example.com'))).data;
  const device = (await f.call('/auth/login', 'POST', {
    email: a.user.email, password: credentials().password,
  })).data;
  const root = '/users/me/sync';
  const snapshot = JSON.stringify([{ id: 'one', title: 'Préparer la journée' }]);
  const write = (token, revision, snapshot) => f.call(root + '/tasks', 'POST', { revision, snapshot }, token);
  const first = await write(a.token, 0, snapshot);
  assert.deepEqual(first, { status: 200, data: { applied: true, revision: 1, snapshot } });
  assert.deepEqual(await write(a.token, 0, snapshot), first);
  const conflicting = '[]';
  assert.deepEqual((await write(device.token, 0, conflicting)).data, { applied: false, revision: 1, snapshot });
  assert.deepEqual((await f.call(root, 'GET', undefined, device.token)).data.collections.tasks, { revision: 1, snapshot });
  assert.deepEqual((await f.call(root, 'GET', undefined, b.token)).data.collections, {});
  assert.equal((await write(b.token, 0, '{"bad":1}')).status, 422);
  assert.equal((await f.call(root)).status, 401);
  assert.equal((await write(device.token, 1, conflicting)).data.revision, 2);
  assert.equal((await write(a.token, 0, snapshot)).data.applied, false);
});

test('preferences compare original values only for touched fields', async t => {
  const f = await fixture();
  t.after(f.close);
  const {token} = (await f.call('/auth/register','POST',credentials())).data;
  const patch = changes => f.call('/users/me/preferences', 'PATCH', changes, token);
  assert.equal((await patch({ theme: 'dark', expected: { theme: 'system' } })).status, 200);
  assert.equal((await patch({ language: 'fr', expected: { language: 'en' } })).data.preferences.theme, 'dark');
  assert.equal((await patch({ theme: 'light', expected: { theme: 'system' } })).status, 409);
  assert.equal((await patch({ theme: 'dark', expected: { theme: 'system' } })).status, 200);
});
