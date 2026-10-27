// Copies non-TS assets (SQL migrations, HTML templates) next to the compiled JS.
import { cpSync } from 'node:fs';
cpSync('src/db/migrations', 'dist/db/migrations', { recursive: true });
cpSync('src/web/assets', 'dist/web/assets', { recursive: true });
console.log('assets copied');
