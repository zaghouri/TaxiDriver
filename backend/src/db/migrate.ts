import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

const here = dirname(fileURLToPath(import.meta.url));

/** Applies every migrations/*.sql not yet applied, in name order, each in its own transaction. */
export async function migrate(databaseUrl: string, log: (m: string) => void = console.log): Promise<string[]> {
  const client = new pg.Client({ connectionString: databaseUrl });
  await client.connect();
  try {
    // Serialise concurrent migrators (e.g. two containers starting).
    await client.query('SELECT pg_advisory_lock(727274)');
    await client.query('CREATE TABLE IF NOT EXISTS schema_migrations (name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())');
    const done = new Set((await client.query('SELECT name FROM schema_migrations')).rows.map((r) => r.name));
    const dir = join(here, 'migrations');
    const files = readdirSync(dir).filter((f) => f.endsWith('.sql')).sort();
    const applied: string[] = [];
    for (const f of files) {
      if (done.has(f)) continue;
      const sql = readFileSync(join(dir, f), 'utf8');
      await client.query('BEGIN');
      try {
        await client.query(sql);
        await client.query('INSERT INTO schema_migrations(name) VALUES ($1)', [f]);
        await client.query('COMMIT');
        applied.push(f);
        log(`migration applied: ${f}`);
      } catch (e) {
        await client.query('ROLLBACK');
        throw new Error(`migration ${f} failed: ${(e as Error).message}`, { cause: e });
      }
    }
    return applied;
  } finally {
    await client.query('SELECT pg_advisory_unlock(727274)').catch(() => undefined);
    await client.end();
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const { loadConfig } = await import('../config.js');
  const { seed } = await import('./seed.js');
  const cfg = loadConfig();
  await migrate(cfg.DATABASE_URL);
  await seed(cfg);
  console.log('migrate + seed done');
}
