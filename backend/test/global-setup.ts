import pg from 'pg';
import { migrate } from '../src/db/migrate.js';
import { seed } from '../src/db/seed.js';
import { loadConfig } from '../src/config.js';

export const ADMIN_URL = process.env.TEST_DATABASE_ADMIN_URL ?? 'postgres://postgres:postgres@localhost:5433/postgres';
export const TEMPLATE_DB = 'ridema_tpl';

const urlFor = (db: string) => ADMIN_URL.replace(/\/[^/]*$/, `/${db}`);

export default async function setup() {
  const admin = new pg.Client({ connectionString: ADMIN_URL });
  await admin.connect();
  // Drop leftovers from earlier runs.
  const old = await admin.query(`SELECT datname FROM pg_database WHERE datname LIKE 'ridema_t_%' OR datname = $1`, [TEMPLATE_DB]);
  for (const r of old.rows) await admin.query(`DROP DATABASE IF EXISTS "${r.datname}" WITH (FORCE)`);
  await admin.query(`CREATE DATABASE ${TEMPLATE_DB}`);
  await admin.end();
  await migrate(urlFor(TEMPLATE_DB), () => undefined);
  await seed(loadConfig({ DATABASE_URL: urlFor(TEMPLATE_DB), NODE_ENV: 'test' }));
}
