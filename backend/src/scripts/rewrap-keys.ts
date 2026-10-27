// Re-wraps every document / ID-check data key from DOCUMENT_MASTER_KEY_OLD to DOCUMENT_MASTER_KEY.
// Files are not touched (they stay encrypted with their own data key). Safe to re-run: rows already
// wrapped with the new key are detected and skipped.
import { loadConfig } from '../config.js';
import { createPool } from '../db/pool.js';
import { openString, rewrapKey } from '../lib/crypto.js';

const cfg = loadConfig();
const oldKey = process.env.DOCUMENT_MASTER_KEY_OLD;
if (!oldKey) throw new Error('set DOCUMENT_MASTER_KEY_OLD');
const db = createPool(cfg.DATABASE_URL, 2);
let done = 0;
let skipped = 0;
for (const table of ['documents', 'id_checks']) {
  const rows = (await db.query(`SELECT id, wrapped_key FROM ${table}`)).rows;
  for (const r of rows) {
    try {
      openString(cfg.DOCUMENT_MASTER_KEY, r.wrapped_key);
      skipped++;
      continue;
    } catch {
      // not yet re-wrapped
    }
    await db.query(`UPDATE ${table} SET wrapped_key = $2 WHERE id = $1`, [r.id, rewrapKey(oldKey, cfg.DOCUMENT_MASTER_KEY, r.wrapped_key)]);
    done++;
  }
}
console.log(`re-wrapped ${done} keys, ${skipped} already on the new key`);
await db.end();
