// Creates verified riders and approved drivers directly in the database (signup/email/WhatsApp flows
// are covered by backend tests; the simulator is about the ride loop under load).
import pg from 'pg';
import { hash } from '@node-rs/argon2';

export const SIM_PASSWORD = 'simulator password 2026';

export interface SimUser {
  id: string;
  email: string;
  role: 'rider' | 'driver';
}

export async function bootstrapUsers(databaseUrl: string, tag: string, riders: number, drivers: number): Promise<{ riders: SimUser[]; drivers: SimUser[] }> {
  const db = new pg.Client({ connectionString: databaseUrl });
  await db.connect();
  try {
    const pw = await hash(SIM_PASSWORD, { memoryCost: 19456, timeCost: 2, parallelism: 1 });
    const city = (await db.query(`SELECT id FROM cities WHERE slug = 'meknes'`)).rows[0].id;
    const mk = async (role: 'rider' | 'driver', i: number): Promise<SimUser> => {
      const email = `sim-${tag}-${role}${i}@sim.ridema.test`;
      const phone = `+2126${String(Math.floor(Math.random() * 1e8)).padStart(8, '0')}`;
      const u = await db.query(
        `INSERT INTO users (role, email, email_verified_at, password_hash, phone, phone_verified_at, full_name, locale, rating_sum, rating_count)
         VALUES ($1,$2,now(),$3,$4,now(),$5,'fr',$6,$7) RETURNING id`,
        [role, email, pw, phone, `${role === 'rider' ? 'Rider' : 'Driver'} ${i} Sim`, 45, 10],
      );
      const id = u.rows[0].id;
      if (role === 'driver') {
        await db.query(`INSERT INTO drivers (user_id, city_id, driver_type, status, cin_last4, licence_issued_on, approved_at) VALUES ($1,$2,$3,'approved','S${i % 1000}', '2012-01-01', now())`, [id, city, i % 3 === 0 ? 'licensed_operator' : 'taxi']);
        await db.query(`INSERT INTO vehicles (driver_id, make, model, year, colour, plate, doors, has_ac) VALUES ($1,'Dacia','Logan',$2,'Blanc',$3,4,true)`, [id, new Date().getFullYear() - 2, `${10000 + i}-A-6`]);
        await db.query(
          `INSERT INTO documents (driver_id, type, storage_key, wrapped_key, iv, auth_tag, mime, size, expires_on, status)
           SELECT $1, t, 'sim/none', 'x', 'x', 'x', 'image/jpeg', 1, current_date + 365, 'approved'
           FROM unnest(ARRAY['cin_front','cin_back','licence','carte_grise','insurance','visite_technique','selfie']) AS t`,
          [id],
        );
      }
      return { id, email, role };
    };
    const r: SimUser[] = [];
    const d: SimUser[] = [];
    for (let i = 0; i < riders; i++) r.push(await mk('rider', i));
    for (let i = 0; i < drivers; i++) d.push(await mk('driver', i));
    return { riders: r, drivers: d };
  } finally {
    await db.end();
  }
}
