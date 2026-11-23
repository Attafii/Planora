import pg from 'pg';
import { AsyncLocalStorage } from 'node:async_hooks';

// Account tables have their own namespace: workspace users are an authorized
// projection, not a second authentication source. All records live in Neon.
export async function openAccountDatabase(url, { schema = 'planify_account' } = {}) {
  if (!/^[a-z_][a-z0-9_]*$/.test(schema)) throw Error('Invalid account schema.');
  const pool = new pg.Pool({ connectionString: url });
  const context = new AsyncLocalStorage();
  await pool.query(`CREATE SCHEMA IF NOT EXISTS ${schema}`);
  pg.types.setTypeParser(20, value => Number(value)); // millisecond timestamps
  async function connection(fn) {
    const existing = context.getStore();
    if (existing) return fn(existing);
    const client = await pool.connect();
    try {
      return await context.run(client, () => fn(client));
    } finally {
      // Also clean up a transaction if a request exited unexpectedly.
      await client.query('ROLLBACK');
      client.release();
    }
  }
  function translate(sql) {
    let n = 0;
    return sql.replace(/\b(users|sessions|preferences|personal_sync|account_notices|insight_consent|consent_events|account_exports|account_deletions)\b/g, name => `${schema}.${name}`).replace(/\?/g, () => '$' + (++n)).replace(/\bINTEGER\b/g, 'BIGINT')
      .replace(/ADD COLUMN (?!IF NOT EXISTS)/g, 'ADD COLUMN IF NOT EXISTS ').replace(/,rowid DESC/g, ',id DESC');
  }
  return {
    withConnection: fn => connection(fn),
    lockAccount: id => connection(client => client.query(`SELECT id FROM ${schema}.users WHERE id=$1 FOR UPDATE`, [id])),
    async exec(sql) {
      sql = sql.replace(/PRAGMA[^;]+;/g, '').replace('BEGIN IMMEDIATE', 'BEGIN; LOCK TABLE personal_sync IN SHARE ROW EXCLUSIVE MODE');
      if (sql.trim()) await connection(client => client.query(translate(sql)));
    },
    prepare(sql) {
      async function query(args) {
        const pragma = sql.match(/^PRAGMA table_info\((\w+)\)$/);
        return connection(client => pragma
          ? client.query('SELECT column_name AS name FROM information_schema.columns WHERE table_schema=$1 AND table_name=$2', [schema, pragma[1]])
          : client.query(translate(sql), args));
      }
      return {
        get: async (...args) => (await query(args)).rows[0],
        all: async (...args) => (await query(args)).rows,
        run: async (...args) => ({ changes: (await query(args)).rowCount }),
      };
    },
    close: () => pool.end(),
  };
}
