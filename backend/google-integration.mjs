import { OAuth2Client } from 'google-auth-library';
import { randomBytes, randomUUID, createCipheriv, createDecipheriv } from 'node:crypto';
const scope = 'https://www.googleapis.com/auth/calendar.events';
const problem = (status, message) => Object.assign(new Error(message), {status, code:'google_integration'});
export function seal(value, key) {
  const iv=randomBytes(12), cipher=createCipheriv('aes-256-gcm', Buffer.from(key,'hex'), iv);
  const data=Buffer.concat([cipher.update(JSON.stringify(value)),cipher.final()]);
  return Buffer.concat([iv,cipher.getAuthTag(),data]).toString('base64');
}
export function unseal(value,key) {
  const data=Buffer.from(value,'base64'), decipher=createDecipheriv('aes-256-gcm',Buffer.from(key,'hex'),data.subarray(0,12));
  decipher.setAuthTag(data.subarray(12,28));
  return JSON.parse(Buffer.concat([decipher.update(data.subarray(28)),decipher.final()]).toString());
}
export async function googleIntegration({db,identity,startSession,req,path,body,send,clock=Date.now, clientFactory=(id,secret)=>new OAuth2Client(id,secret,'postmessage')}) {
  if (!['/auth/google/config','/auth/google','/users/me/google/calendar','/users/me/google/calendar/events'].includes(path)) return false;
  const clientId=process.env.GOOGLE_CLIENT_ID, secret=process.env.GOOGLE_CLIENT_SECRET, key=process.env.GOOGLE_TOKEN_KEY;
  if(path==='/auth/google/config') { send(200,{client_id:clientId ?? null,calendar_available:!!key}); return true; }
  if(!clientId || !secret) throw problem(503,'Google is not configured.');
  const oauth=clientFactory(clientId,secret);
  if(path==='/auth/google' && req.method==='POST') {
    if(typeof body.code!=='string' || body.code.length>4096) throw problem(422,'A Google authorization code is required.');
    let tokens,payload;
    try {
      ({tokens}=await oauth.getToken(body.code));
      payload=(await oauth.verifyIdToken({idToken:tokens.id_token,audience:clientId})).getPayload();
    } catch { throw problem(422,'Google authorization failed or expired. Please try again.'); }
    if(!payload?.sub || !payload.email_verified || !payload.email) throw problem(422,'Google did not return a verified identity.');
    if(body.calendar===true && !req.headers.authorization) throw problem(401,'Sign in before connecting Calendar.');
    const auth=req.headers.authorization ? await identity(req) : null;
    let u=await db.prepare('SELECT * FROM users WHERE google_sub=?').get(payload.sub);
    if(auth) {
      if(u && u.id!==auth.id) throw problem(409,'This Google account is linked to another Planify account.');
      u=await db.prepare('SELECT * FROM users WHERE id=?').get(auth.id);
      if(u.google_sub && u.google_sub!==payload.sub) throw problem(409,'Disconnect your existing Google connection before changing accounts.');
    } else if(!u) {
      if(await db.prepare('SELECT id FROM users WHERE email=?').get(payload.email.toLowerCase())) throw problem(409,'This email already has a Planify account. Sign in with your password, then connect Google from Calendar.');
      const id=randomUUID(), at=new Date(clock()).toISOString();
      await db.exec('BEGIN');
      try {
        await db.prepare('INSERT INTO users (id,name,email,email_verified_at,password_hash,salt,timezone,language,created_at,updated_at,google_sub) VALUES (?,?,?,?,?,?,?,?,?,?,?)').run(id,(payload.name || 'Google user').slice(0,80),payload.email.toLowerCase(),at,randomBytes(64).toString('hex'),randomBytes(16).toString('hex'),'UTC','en',at,at,payload.sub);
        await db.prepare('INSERT INTO preferences (user_id) VALUES (?)').run(id);
        await db.exec('COMMIT');
      } catch(e) {await db.exec('ROLLBACK'); throw e;}
      u={id};
    }
    if(auth) await db.prepare('UPDATE users SET google_sub=? WHERE id=?').run(payload.sub,u.id);
    if(body.calendar===true) {
      if(!/^[a-f0-9]{64}$/.test(key ?? '')) throw problem(503,'Calendar secure token storage is not configured.');
      if(!auth) throw problem(401,'Sign in to Planify before connecting Calendar.');
      if(!(tokens.scope || '').split(' ').includes(scope)) throw problem(403,'Calendar access was not granted.');
      const previous=u.google_tokens ? unseal(u.google_tokens,key) : {};
      await db.prepare('UPDATE users SET google_tokens=? WHERE id=?').run(seal({...previous,...tokens,refresh_token:tokens.refresh_token || previous.refresh_token},key),u.id);
      send(200,{connected:true});
    } else send(200,await startSession(u.id,req));
    return true;
  }
  const auth=await identity(req), u=await db.prepare('SELECT * FROM users WHERE id=?').get(auth.id);
  if(path==='/users/me/google/calendar') {
    if(req.method==='DELETE') {
      if(u.google_tokens && key) { const t=unseal(u.google_tokens,key); try {await oauth.revokeToken(t.refresh_token || t.access_token);} catch {throw problem(502,'Google could not revoke access. Retry disconnect.');} }
      await db.prepare('UPDATE users SET google_tokens=NULL WHERE id=?').run(auth.id);
      send(200,{connected:false});
    } else send(200,{connected:!!u.google_tokens});
    return true;
  }
  if(!u.google_tokens || !key) throw problem(409,'Connect Google Calendar first.');
  oauth.setCredentials(unseal(u.google_tokens,key));
  try {
    const endpoint='https://www.googleapis.com/calendar/v3/calendars/primary/events';
    if(req.method==='GET') {
      const result=await oauth.request({url:endpoint,params:{timeMin:new Date(clock()).toISOString(),maxResults:100,singleEvents:true,orderBy:'startTime'}});
      send(200,{events:result.data.items || []});
    } else if(req.method==='POST') {
      if(!/^[a-f0-9]{32}$/.test(body.request_id ?? '') || typeof body.title!=='string' || !body.title.trim() || body.title.length>200 || !Number.isFinite(Date.parse(body.start)) || !Number.isFinite(Date.parse(body.end)) || Date.parse(body.start)>=Date.parse(body.end)) throw problem(422,'Enter a title and valid start and end times.');
      const event={id:body.request_id,summary:body.title.trim(),start:{dateTime:new Date(body.start).toISOString()},end:{dateTime:new Date(body.end).toISOString()}};
      let result;
      try {result=await oauth.request({url:endpoint,method:'POST',data:event});}
      catch(e) {if(e.response?.status!==409) throw e; result=await oauth.request({url:`${endpoint}/${event.id}`});}
      send(200,{event:result.data});
    } else throw problem(405,'Method not supported.');
  } catch(e) {if(e.status) throw e; throw problem(502,'Google Calendar could not complete this request. Check consent, Calendar API configuration, and connectivity, then retry.');}
  return true;
}
