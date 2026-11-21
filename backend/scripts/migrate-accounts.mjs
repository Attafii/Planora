import { DatabaseSync } from 'node:sqlite';
import { openAccountDatabase } from '../src/account_database.mjs';
import { createApi } from '../server.mjs';
if (!process.env.DATABASE_URL || !process.argv[2]) throw Error('Set DATABASE_URL and pass the source SQLite file.');
const source = new DatabaseSync(process.argv[2], { readOnly: true });
const db = await openAccountDatabase(process.env.DATABASE_URL);
const server = createApi({ accountDb: db });
const tables = ['users','preferences','sessions','personal_sync','account_notices','insight_consent','consent_events','account_exports','account_deletions'];
let count = 0;
try {
  await server.ready;
  await db.withConnection(async () => {
    await db.exec('BEGIN');
    try {
      for (const table of tables) {
        if (!source.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name=?").get(table)) continue;
        const keys = source.prepare(`PRAGMA table_info(${table})`).all().filter(c => c.pk).sort((a,b) => a.pk-b.pk).map(c => c.name);
        for (const row of source.prepare(`SELECT * FROM ${table}`).all()) {
          const columns = Object.keys(row);
          const existing = await db.prepare(`SELECT * FROM ${table} WHERE ${keys.map(k => `${k}=?`).join(' AND ')}`).get(...keys.map(k => row[k]));
          if (existing) {
            if (columns.some(k => existing[k] !== row[k])) throw Error(`Migration conflict in ${table}; nothing from this source was imported. Source retained.`);
          } else {
            await db.prepare(`INSERT INTO ${table} (${columns.join(',')}) VALUES (${columns.map(() => '?').join(',')})`).run(...Object.values(row));
            count++;
          }
        }
      }
      await db.exec('COMMIT');
    } catch (e) { await db.exec('ROLLBACK'); throw e; }
  });
  console.info(`Imported ${count} account records. Source retained; matching records are safe to retry.`);
} finally { source.close(); await db.close(); }
