import { openDatabase } from '../src/database.mjs';
import { openAccountDatabase } from '../src/account_database.mjs';
import { createApi } from '../server.mjs';
if (!process.env.DATABASE_URL) throw Error('DATABASE_URL is required.');
const db = await openDatabase();
const accountDb = await openAccountDatabase(process.env.DATABASE_URL);
const server = createApi({ accountDb });
try {
  await server.ready;
  console.info('Neon workspace and account schema ready.');
  const tables = await db.query("SELECT table_schema,table_name FROM information_schema.tables WHERE table_schema IN ('public','planify_account') AND table_type='BASE TABLE' ORDER BY table_schema,table_name");
  console.info(JSON.stringify(tables.rows));
} finally { await accountDb.close(); await db.close(); }
