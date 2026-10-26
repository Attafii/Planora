import { randomUUID, randomBytes, createHash, scryptSync, timingSafeEqual } from 'node:crypto';
import { z } from 'zod';
import { one } from './database.mjs';

export const id = () => randomUUID();
export const now = () => new Date().toISOString();
export const secret = () => randomBytes(32).toString('base64url');
export const hash = (s) => createHash('sha256').update(s).digest('hex');
export class ApiError extends Error {
  constructor(status, message, code = 'request_failed') { super(message); this.status = status; this.code = code; }
}
export const requireThat = (condition, message, status = 400, code) => { if (!condition) throw new ApiError(status, message, code); };
export const title = z.string().trim().min(1, 'Enter a title.').max(160);
export const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Use a valid date.').refine(s => !Number.isNaN(Date.parse(s)) && new Date(s).toISOString().startsWith(s), 'Use a real calendar date.').nullable().optional();
export const uuid = z.string().uuid();
export function parse(schema, input) {
  const r = schema.safeParse(input);
  if (!r.success) throw new ApiError(422, r.error.issues.map(i => `${i.path.join('.') || 'Input'}: ${i.message}`).join('\n'), 'validation_error');
  return r.data;
}
export function passwordHash(password) {
  const salt = randomBytes(16).toString('hex');
  return `${salt}:${scryptSync(password, salt, 64).toString('hex')}`;
}
export function passwordMatches(password, encoded) {
  const [salt, key] = encoded.split(':');
  return timingSafeEqual(scryptSync(password, salt, 64), Buffer.from(key, 'hex'));
}
export async function currentUser(req, db) {
  const token = req.headers.authorization?.replace(/^Bearer /, '');
  requireThat(token && token.length < 512, 'Please sign in to continue.', 401, 'unauthenticated');
  const user = await one(db, 'SELECT u.id,u.name,u.email,u.timezone FROM users u JOIN sessions s ON s.user_id=u.id WHERE s.token_hash=$1 AND s.expires_at>$2', [hash(token), now()]);
  requireThat(user, 'Your session expired. Please sign in again.', 401, 'unauthenticated');
  return user;
}
export async function projectRole(db, projectId, user, roles) {
  const row = await one(db, 'SELECT role FROM project_members WHERE project_id=$1 AND user_id=$2', [projectId, user.id]);
  requireThat(row, 'This project is not available to your account.', 403, 'forbidden');
  if (roles) requireThat(roles.includes(row.role), 'Your project role does not allow this action.', 403, 'forbidden');
  return row.role;
}
export async function goalAccess(db, goalId, user, write = false) {
  const goal = await one(db, 'SELECT * FROM goals WHERE id=$1', [goalId]);
  requireThat(goal, 'This goal could not be found.', 404);
  if (goal.project_id) {
    const role=await projectRole(db,goal.project_id,user);
    if(write)requireThat(['owner','admin'].includes(role)||(role==='collaborator'&&goal.owner_id===user.id),'You cannot edit another member’s goal.',403);
  }
  else requireThat(goal.owner_id === user.id, 'This goal is private.', 403, 'forbidden');
  return goal;
}
export async function taskAccess(db, taskId, user, write = false) {
  const task = await one(db, 'SELECT t.*,a.user_id AS assignee_id FROM tasks t LEFT JOIN task_assignments a ON a.task_id=t.id WHERE t.id=$1', [taskId]);
  requireThat(task, 'This task could not be found.', 404);
  let canEdit=task.owner_id===user.id;
  if (task.project_id) {
    const role = await projectRole(db, task.project_id, user);
    canEdit=['owner','admin'].includes(role) || (role==='collaborator' && (task.owner_id===user.id || task.assignee_id===user.id));
    if (write) requireThat(canEdit, 'You can only update tasks assigned to you or created by you.', 403);
  } else requireThat(task.owner_id===user.id, 'This task is private.', 403);
  return {...task,can_edit:canEdit};
}
export async function activity(db, projectId, user, kind, message) {
  await db.query('INSERT INTO activity(id,project_id,actor_id,kind,message,created_at) VALUES($1,$2,$3,$4,$5,$6)', [id(),projectId,user.id,kind,message,now()]);
}
export async function event(db, userId, kind, entityId) {
  await db.query('INSERT INTO productivity_events(id,user_id,kind,entity_id,occurred_at) VALUES($1,$2,$3,$4,$5) ON CONFLICT(user_id,kind,entity_id) DO NOTHING', [id(),userId,kind,entityId,now()]);
}
export function pagination(req) {
  const limit = Math.min(50,Math.max(1,Number.parseInt(req.query.limit)||20));
  const offset = Math.max(0,Number.parseInt(req.query.offset)||0);
  return { limit, offset };
}
export const managers = ['owner','admin'];
