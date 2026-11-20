import express from 'express';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { z } from 'zod';
import { id, now, secret, hash, passwordHash, passwordMatches, parse, requireThat, currentUser, ApiError } from './core.mjs';
import { one } from './database.mjs';
import { registerGoals } from './goals.mjs';
import { registerCollaboration } from './collaboration.mjs';
import { registerAssistant } from './assistant.mjs';
import { registerGamification } from './gamification.mjs';

export function createApp(db){
 const app=express();app.disable('x-powered-by');
 const origins=(process.env.CORS_ORIGINS||'http://localhost:5300,http://127.0.0.1:5300,http://localhost:4100,http://127.0.0.1:4100').split(',');
 app.use((req,res,next)=>{
  res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('Cache-Control','no-store');
  const origin=req.headers.origin;
  if(origin&&origins.includes(origin)){res.setHeader('Access-Control-Allow-Origin',origin);res.setHeader('Vary','Origin');res.setHeader('Access-Control-Allow-Headers','Content-Type,Authorization,Idempotency-Key');res.setHeader('Access-Control-Allow-Methods','GET,POST,PATCH,DELETE,OPTIONS');}
  if(req.method==='OPTIONS'){res.status(origin&&!origins.includes(origin)?403:204).end();return;}next();
 });
 app.use(express.json({limit:'64kb'}));
 const buckets=new Map();
 app.use((req,res,next)=>{
  const isAuth=req.path.startsWith('/auth/'),isAI=req.path==='/assistant/messages';
  if(!isAuth&&!isAI){next();return;}
  const key=`${req.ip}:${isAuth?'auth':'ai'}`,t=Date.now(),existing=buckets.get(key),entry=!existing||t-existing.start>60000?{start:t,count:0}:existing;
  entry.count++;buckets.set(key,entry);if(buckets.size>10000)for(const [k,v]of buckets)if(t-v.start>60000)buckets.delete(k);
  if(entry.count>(isAuth?30:12)){res.status(429).json({error:{message:'Too many requests. Please wait a minute and try again.',code:'rate_limited'}});return;}next();
 });
 const route=(method,url,fn,{public:isPublic=false,status=200,onError}={})=>app[method](url,async(req,res,next)=>{
  let user;
  try{const result=await db.transaction(async tx=>{user=isPublic?null:await currentUser(req,tx);return fn(req,tx,user);});res.status(status).json(result??{});}
  catch(error){try{if(onError)await onError(error,req,user);}catch{/* Preserve the original failure; never expose database internals. */}next(error);}
 });
 route('get','/health',()=>({ok:true,database:db.mode}),{public:true});
 const auth=z.object({email:z.string().trim().email().max(254).transform(s=>s.toLowerCase()),password:z.string().min(10,'Use at least 10 characters.').max(128)});
 route('post','/auth/register',async(req,tx)=>{
  const d=parse(auth.extend({name:z.string().trim().min(1).max(80),timezone:z.string().max(80).default('UTC')}).strict(),req.body);
  try{new Intl.DateTimeFormat('en',{timeZone:d.timezone}).format();}catch{throw new ApiError(422,'Choose a valid timezone.');}
  requireThat(!await one(tx,'SELECT id FROM users WHERE email=$1',[d.email]),'An account already exists for this email.',409);
  const user={id:id(),name:d.name,email:d.email,timezone:d.timezone};await tx.query('INSERT INTO users(id,name,email,password_hash,timezone,created_at) VALUES($1,$2,$3,$4,$5,$6)',[user.id,user.name,user.email,passwordHash(d.password),user.timezone,now()]);return startSession(tx,user);
 },{public:true,status:201});
 route('post','/auth/login',async(req,tx)=>{
  const d=parse(auth.strict(),req.body),record=await one(tx,'SELECT * FROM users WHERE email=$1',[d.email]);
  // A fixed dummy hash makes unknown accounts incur the same password verification work.
  const valid=passwordMatches(d.password,record?.password_hash||dummyHash);
  requireThat(record&&valid,'Email or password is incorrect.',401,'invalid_credentials');const {password_hash,...user}=record;return startSession(tx,user);
 },{public:true});
 route('get','/auth/me',(req,tx,user)=>user);
 route('post','/auth/logout',async(req,tx)=>{await tx.query('DELETE FROM sessions WHERE token_hash=$1',[hash(req.headers.authorization.replace(/^Bearer /,''))]);return {signed_out:true};});
 registerGoals(route);registerCollaboration(route);registerAssistant(route,db);registerGamification(route);
 const web=fileURLToPath(new URL('../../build/web',import.meta.url));if(existsSync(web))app.use(express.static(web));
 app.use((req,res)=>res.status(404).json({error:{message:'This endpoint could not be found.',code:'not_found'}}));
 app.use((error,req,res,next)=>{
  if(res.headersSent){next(error);return;}
  const known=error instanceof ApiError;
  const status=known?error.status:error.type==='entity.parse.failed'?400:error.code==='23505'?409:500;
  res.status(status).json({error:{message:known?error.message:status===409?'This record already exists. Refresh and try again.':status===400?'The request body is invalid.':'Something went wrong. Your changes were not applied. Please try again.',code:known?error.code:'request_failed'}});
 });
 return app;
}
const dummyHash=passwordHash('not-a-user-password');
async function startSession(db,user){
 const token=secret(),expires=new Date(Date.now()+7*86400000).toISOString();await db.query('INSERT INTO sessions(token_hash,user_id,expires_at) VALUES($1,$2,$3)',[hash(token),user.id,expires]);await db.query('DELETE FROM sessions WHERE expires_at<$1',[now()]);return {user,token,expires_at:expires};
}
