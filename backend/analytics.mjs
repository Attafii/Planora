// Server-only adapter contract. Sources must query current access permissions
// and return authoritative completed records, never client-submitted totals.
// No HTTP endpoint creates task, goal or focus records in this account module.
export async function privateAnalytics({ source, userId, from, to, timezone }) {
  const base = { range: { from, to, end_exclusive: true }, timezone, generated_at: new Date().toISOString() };
  if (!source) return { ...base, status: 'unavailable', tasks_completed: null, goals_completed: null };
  const data = await source({ userId, from, to, timezone });
  const count = records => {
    if (records == null) return null;
    if (!Array.isArray(records)) throw new Error('Invalid activity adapter response');
    return new Set(records.filter(record => {
      const completed = Date.parse(record.completed_at);
      return typeof record.id === 'string' && record.owner_id === userId && record.accessible === true && Number.isFinite(completed) && completed >= Date.parse(from) && completed < Date.parse(to);
    }).map(record => record.id)).size;
  };
  const tasks_completed = count(data.tasks), goals_completed = count(data.goals);
  return { ...base, status: tasks_completed === null && goals_completed === null ? 'unavailable' : tasks_completed === null || goals_completed === null ? 'partial' : 'available', tasks_completed, goals_completed };
}
