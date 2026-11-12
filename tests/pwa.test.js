import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
const manifest=JSON.parse(readFileSync(new URL('../manifest.webmanifest',import.meta.url),'utf8'));
const sw=readFileSync(new URL('../sw.js',import.meta.url),'utf8');
const headers=readFileSync(new URL('../_headers',import.meta.url),'utf8');
test('PWA manifest is installable and declares local icons',()=>{assert.equal(manifest.display,'standalone');assert.equal(manifest.scope,'/');assert.ok(manifest.icons.length>=2);for(const icon of manifest.icons)assert.ok(existsSync(new URL('../'+icon.src.replace(/^\//,''),import.meta.url)),icon.src)});
test('service worker precaches every local JavaScript module',()=>{for(const asset of ['/','/index.html','/manifest.webmanifest','/icon.svg','/icon-192.png','/icon-512.png','/app/main.js','/app/domain.js','/app/extended-i18n.js','/app/styles.css'])assert.ok(sw.includes(`'${asset}'`),asset)});
test('static security headers permit only required external SDK origins',()=>{assert.match(headers,/Content-Security-Policy/);assert.match(headers,/https:\/\/\*\.supabase\.co/);assert.match(headers,/https:\/\/esm\.sh/);assert.doesNotMatch(headers,/unsafe-eval/)});
