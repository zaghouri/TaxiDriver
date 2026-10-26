import pg from 'pg';

// int8 (bigserial, count(*)) as JS number; our values stay far below 2^53.
pg.types.setTypeParser(20, (v) => Number(v));
// numeric as number (prices/ratios per city).
pg.types.setTypeParser(1700, (v) => Number(v));
// date as plain 'YYYY-MM-DD' string.
pg.types.setTypeParser(1082, (v) => v);

export type Db = pg.Pool;
export type Tx = pg.PoolClient;
export type Queryable = pg.Pool | pg.PoolClient;

export function createPool(url: string, max = 20): Db {
  return new pg.Pool({ connectionString: url, max });
}

/** Runs fn inside a transaction; rolls back on throw. */
export async function withTx<T>(db: Db, fn: (tx: Tx) => Promise<T>): Promise<T> {
  const client = await db.connect();
  try {
    await client.query('BEGIN');
    const out = await fn(client);
    await client.query('COMMIT');
    return out;
  } catch (e) {
    await client.query('ROLLBACK').catch(() => undefined);
    throw e;
  } finally {
    client.release();
  }
}

export async function one<T = any>(q: Queryable, sql: string, params: unknown[] = []): Promise<T | null> {
  const r = await q.query(sql, params);
  return (r.rows[0] as T) ?? null;
}

export async function many<T = any>(q: Queryable, sql: string, params: unknown[] = []): Promise<T[]> {
  const r = await q.query(sql, params);
  return r.rows as T[];
}
