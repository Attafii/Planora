import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import pg from 'pg';

export async function openDatabase({ url = process.env.DATABASE_URL, path = process.env.DATABASE_PATH || './data' } = {}) {
  const schema = await readFile(new URL('./schema.sql', import.meta.url), 'utf8');
  if (url) {
    const pool = new pg.Pool({ connectionString: url });
    const setup = await pool.connect();
    try {
      await setup.query('BEGIN');
      await setup.query('SET LOCAL search_path TO public');
      await setup.query(schema);
      await setup.query('COMMIT');
    } catch (e) { await setup.query('ROLLBACK'); throw e; } finally { setup.release(); }
    return {
      mode: 'PostgreSQL',
      query: async (sql, args) => {
        const client = await pool.connect();
        try {
          await client.query('BEGIN');
          await client.query('SET LOCAL search_path TO public');
          const result = await client.query(sql, args);
          await client.query('COMMIT');
          return result;
        } catch (e) { await client.query('ROLLBACK'); throw e; } finally { client.release(); }
      },
      transaction: async (fn) => {
        const client = await pool.connect();
        try {
          await client.query('BEGIN');
          await client.query('SET LOCAL search_path TO public');
          const result = await fn(client);
          await client.query('COMMIT');
          return result;
        } catch (error) {
          await client.query('ROLLBACK');
          throw error;
        } finally { client.release(); }
      },
      close: () => pool.end(),
    };
  }
  const db = new PGlite(path === ':memory:' ? undefined : path);
  await db.exec(schema);
  return { mode: 'Embedded PostgreSQL', query: (sql, args) => db.query(sql, args), transaction: (fn) => db.transaction(fn), close: () => db.close() };
}

export const one = async (db, sql, args = []) => (await db.query(sql, args)).rows[0];
export const rows = async (db, sql, args = []) => (await db.query(sql, args)).rows;
