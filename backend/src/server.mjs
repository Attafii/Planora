import { openDatabase } from './database.mjs';
import { createApp } from './app.mjs';
if(process.env.NODE_ENV==='production'&&!process.env.DATABASE_URL)throw new Error('Production requires DATABASE_URL pointing to the PostgreSQL service.');
const db=await openDatabase();
const port=Number(process.env.PORT||4100),host=process.env.HOST||'127.0.0.1';
const server=createApp(db).listen(port,host,()=>console.info(`Planify API listening on ${host}:${port} (${db.mode})`));
for(const signal of ['SIGINT','SIGTERM'])process.once(signal,()=>server.close(async()=>{await db.close();process.exit(0);}));
