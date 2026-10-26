// Local production-build preview. Both listeners stay on loopback.
import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { resolve, extname, sep } from 'node:path';
import { createApi } from './server.mjs';

const root = resolve('build/web');
const types = { '.html':'text/html', '.js':'text/javascript', '.json':'application/json', '.wasm':'application/wasm', '.ttf':'font/ttf', '.otf':'font/otf', '.woff2':'font/woff2', '.png':'image/png', '.ico':'image/x-icon', '.svg':'image/svg+xml' };
createApi().listen(3000,'127.0.0.1');
http.createServer(async(req,res)=>{
  try {
    const pathname=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
    const target=resolve(root,'.'+(pathname==='/'?'/index.html':pathname));
    if(!target.startsWith(root+sep)){res.writeHead(403);res.end();return;}
    const data=await readFile(target);
    res.writeHead(200,{'Content-Type':types[extname(target)]??'application/octet-stream','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});res.end(data);
  }catch{res.writeHead(404);res.end('Not found');}
}).listen(5173,'127.0.0.1',()=>console.log('Planify preview: http://localhost:5173'));
