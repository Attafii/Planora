import { requireThat } from './core.mjs';

const taskId = /^[a-zA-Z0-9_-]{1,100}(?:@\d{4}-\d{2}-\d{2})?$/;

// This is a read-through view of the authenticated Eya collection. Missing
// snapshots differ from a synced empty list, including after a task is deleted.
export function personalTaskView(snapshot) {
  if (snapshot == null) return null;
  let records;
  try {
    records = JSON.parse(snapshot);
  } catch {
    return null;
  }
  if (!Array.isArray(records) || records.some(task =>
    !task || typeof task.id !== 'string' || typeof task.title !== 'string' ||
    typeof task.done !== 'boolean' || typeof task.skipped !== 'boolean')) return null;
  const tasks = new Map(records.map(task => [task.id, task]));
  const steps = new Map();
  for (const task of tasks.values()) {
    if (typeof task.parent !== 'string') continue;
    if (!steps.has(task.parent)) steps.set(task.parent, []);
    steps.get(task.parent).push(task);
  }
  const memo = new Map();
  function completed(task, path = new Set()) {
    if (memo.has(task.id)) return memo.get(task.id);
    if (path.has(task.id) || task.skipped) return false;
    path.add(task.id);
    const children = steps.get(task.id) ?? [];
    const done = (!Array.isArray(task.requires) || task.requires.every(key =>
      tasks.has(key) && completed(tasks.get(key), path))) &&
      (children.length ? children.every(child => completed(child, path)) : task.done);
    path.delete(task.id);
    memo.set(task.id, done);
    return done;
  }
  const view = new Map();
  for (const task of tasks.values()) {
    if (!taskId.test(task.id) || task.skipped || (task.repeat ?? 'once') !== 'once') continue;
    view.set(task.id, {
      id: task.id,
      title: task.title,
      status: completed(task) ? 'completed' : 'todo',
      estimated_minutes: Number.isInteger(task.minutes) && task.minutes > 0 ? task.minutes : 25,
      deadline: typeof task.due === 'string' ? task.due : null,
      project_id: null,
      personal: true,
    });
  }
  return view;
}

export function validatePersonalTaskId(key) {
  requireThat(typeof key === 'string' && taskId.test(key), 'Choose an existing personal task.', 422);
  return key;
}

export const counts = (items, done) => ({
  total: items.length,
  completed: items.filter(done).length,
});
