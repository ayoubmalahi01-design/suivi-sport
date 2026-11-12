import {cp,mkdir,rm,copyFile} from 'node:fs/promises';
const root=new URL('../',import.meta.url),out=new URL('../cloudflare-upload/',import.meta.url);
await rm(out,{recursive:true,force:true});await mkdir(out,{recursive:true});
for(const f of ['index.html','manifest.webmanifest','sw.js','icon.svg','icon-192.png','icon-512.png','_headers']) await copyFile(new URL(f,root),new URL(f,out));
await cp(new URL('app/',root),new URL('app/',out),{recursive:true});
console.log('Static Cloudflare upload bundle generated.');
