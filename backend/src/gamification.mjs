import { z } from 'zod';
import { rows, one } from './database.mjs';
import { now, parse, requireThat, event, uuid } from './core.mjs';

export const badges=[
 {id:'first_task',title:'First step',description:'Complete your first real task.',kind:'task_completed',target:1,points:20},
 {id:'five_tasks',title:'Steady progress',description:'Complete five distinct tasks.',kind:'task_completed',target:5,points:50},
 {id:'first_goal',title:'Goal reached',description:'Complete a goal and its linked work.',kind:'goal_completed',target:1,points:80},
 {id:'first_focus',title:'Focused start',description:'Complete a verified focus session.',kind:'focus_completed',target:1,points:30},
 {id:'consistent_focus',title:'Consistent focus',description:'Complete five verified focus sessions.',kind:'focus_completed',target:5,points:75},
 {id:'thoughtful_planner',title:'Thoughtful planner',description:'Approve five distinct calendar plans.',kind:'plan_approved',target:5,points:60},
];
export const challenges=[
 {id:'finish_one_goal',title:'One clear outcome',description:'Complete one goal in seven days.',kind:'goal_completed',target:1,days:7},
 {id:'five_steps',title:'Five meaningful steps',description:'Complete five tasks in seven days.',kind:'task_completed',target:5,days:7},
 {id:'three_focus',title:'Make room for focus',description:'Complete three verified focus sessions in seven days.',kind:'focus_completed',target:3,days:7},
];
const dayKey=(time,zone)=>new Intl.DateTimeFormat('en-CA',{timeZone:zone,year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(time));
export function streak(events,zone='UTC',clock=new Date()){
 const eligible=new Set(events.filter(e=>['task_completed','goal_completed','focus_completed','plan_approved'].includes(e.kind)).map(e=>dayKey(e.occurred_at,zone)));
 const cursor=new Date(dayKey(clock,zone)+'T12:00:00Z');
 const previous=()=>cursor.setUTCDate(cursor.getUTCDate()-1);
 // Weekends are rest days. Today has until midnight to qualify, so an unfinished day is not punished.
 while([0,6].includes(cursor.getUTCDay()))previous();
 if(!eligible.has(cursor.toISOString().slice(0,10)))previous();
 let count=0;for(let i=0;i<3660;i++){if([0,6].includes(cursor.getUTCDay())){previous();continue;}if(!eligible.has(cursor.toISOString().slice(0,10)))break;count++;previous();}return count;
}
export async function summary(db,user){
 const events=await rows(db,'SELECT * FROM productivity_events WHERE user_id=$1 ORDER BY occurred_at',[user.id]);
 const achievements=badges.map(b=>{const hits=events.filter(e=>e.kind===b.kind);return {...b,progress:Math.min(b.target,hits.length),earned:hits.length>=b.target,earned_at:hits.length>=b.target?hits[b.target-1].occurred_at:null};});
 const points=achievements.filter(b=>b.earned).reduce((s,b)=>s+b.points,0),level=1+Math.floor(points/100);
 return {achievements,points,level,level_progress:points%100,next_level_points:100,streak:streak(events,user.timezone),streak_rule:'A weekday qualifies when verified work is completed or a plan is approved. Weekends are rest days. Today remains open until midnight in your profile timezone.'};
}
export function registerGamification(route){
 route('get','/gamification/summary',(req,db,user)=>summary(db,user));
 route('get','/achievements/:id',async(req,db,user)=>{const s=await summary(db,user),b=s.achievements.find(a=>a.id===req.params.id);requireThat(b,'Achievement not found.',404);return b;});
 route('get','/challenges',async(req,db,user)=>{
  const joined=await rows(db,'SELECT * FROM user_challenges WHERE user_id=$1',[user.id]);
  const result=[];for(const c of challenges){const j=joined.find(a=>a.challenge_id===c.id);let progress=0;if(j){progress=Number((await one(db,'SELECT COUNT(*) AS n FROM productivity_events WHERE user_id=$1 AND kind=$2 AND occurred_at>=$3 AND occurred_at<=$4',[user.id,c.kind,j.joined_at,j.expires_at])).n);if(progress>=c.target&&!j.completed_at){j.completed_at=now();await db.query('UPDATE user_challenges SET completed_at=$3 WHERE user_id=$1 AND challenge_id=$2',[user.id,c.id,j.completed_at]);}}result.push({...c,...j,progress:Math.min(c.target,progress),status:!j?'available':j.completed_at?'completed':j.expires_at<now()?'expired':'active'});}return result;
 });
 route('post','/challenges/:id/join',async(req,db,user)=>{const c=challenges.find(a=>a.id===req.params.id);requireThat(c,'Challenge not found.',404);const j=await one(db,'SELECT * FROM user_challenges WHERE user_id=$1 AND challenge_id=$2',[user.id,c.id]);requireThat(!j,'This challenge is already joined.',409);await db.query('INSERT INTO user_challenges(user_id,challenge_id,joined_at,expires_at) VALUES($1,$2,$3,$4)',[user.id,c.id,now(),new Date(Date.now()+c.days*86400000).toISOString()]);return {joined:true};});
 route('post','/challenges/:id/leave',async(req,db,user)=>{await db.query('DELETE FROM user_challenges WHERE user_id=$1 AND challenge_id=$2',[user.id,req.params.id]);return {left:true};});
 route('post','/integrations/events',async(req,db)=>{
  requireThat(process.env.INTEGRATION_TOKEN&&req.headers['x-integration-token']===process.env.INTEGRATION_TOKEN,'This endpoint requires a trusted service integration.',403);
  const d=parse(z.object({user_id:uuid,kind:z.enum(['focus_completed','plan_approved']),entity_id:z.string().trim().min(1).max(160)}).strict(),req.body);
  requireThat(await one(db,'SELECT id FROM users WHERE id=$1',[d.user_id]),'User not found.',404);await event(db,d.user_id,d.kind,d.entity_id);return {recorded:true};
 },{public:true});
}
