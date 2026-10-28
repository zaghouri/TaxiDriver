import { z } from 'zod';

const bool = z
  .union([z.boolean(), z.string()])
  .transform((v) => v === true || v === 'true' || v === '1');

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(3000),
  LOG_LEVEL: z.string().default('info'),
  PUBLIC_HOST: z.string().optional().default(''),
  SERVER_IP: z.string().optional().default('127.0.0.1'),
  DATABASE_URL: z.string().default('postgres://postgres:postgres@localhost:5433/ridema'),
  REDIS_URL: z.string().default('redis://localhost:6379'),
  REDIS_PREFIX: z.string().default('ridema'),
  JWT_SECRET: z.string().min(32).default('dev-only-jwt-secret-change-me-0123456789abcdef'),
  ACCESS_TOKEN_TTL_S: z.coerce.number().default(15 * 60),
  REFRESH_TOKEN_TTL_DAYS: z.coerce.number().default(30),
  DOCUMENT_MASTER_KEY: z.string().default('ZGV2LW9ubHktZG9jdW1lbnQtbWFzdGVyLWtleS0zMmI='),
  TOTP_ENC_KEY: z.string().default('ZGV2LW9ubHktdG90cC1lbmNyeXB0aW9uLWtleS0zMmI='),
  ADMIN_BOOTSTRAP_EMAIL: z.string().optional().default(''),
  ADMIN_BOOTSTRAP_PASSWORD: z.string().optional().default(''),
  ADMIN_IP_ALLOWLIST: z.string().optional().default(''),
  /** Number of reverse-proxy hops in front of the API (Caddy = 1). Never trust client-supplied X-Forwarded-For beyond that. */
  TRUST_PROXY_HOPS: z.coerce.number().int().min(0).max(5).default(1),

  EMAIL_PROVIDER: z.enum(['smtp', 'log']).default('log'),
  SMTP_HOST: z.string().optional().default(''),
  SMTP_PORT: z.coerce.number().default(587),
  SMTP_USER: z.string().optional().default(''),
  SMTP_PASS: z.string().optional().default(''),
  SMTP_FROM: z.string().default('RideMA <no-reply@ridema.local>'),

  OTP_CHANNEL: z.enum(['whatsapp', 'log']).default('log'),
  WHATSAPP_PHONE_NUMBER_ID: z.string().optional().default(''),
  WHATSAPP_ACCESS_TOKEN: z.string().optional().default(''),
  WHATSAPP_OTP_TEMPLATE: z.string().default('ridema_otp'),
  /** Utility template for SOS alerts to saved emergency contacts (D71); empty = log only. */
  WHATSAPP_SOS_TEMPLATE: z.string().optional().default(''),
  WHATSAPP_API_VERSION: z.string().default('v21.0'),
  SMS_PROVIDER: z.string().default('disabled'),

  PUSH_PROVIDER: z.enum(['fcm', 'log']).default('log'),
  FIREBASE_SERVICE_ACCOUNT_FILE: z.string().optional().default(''),

  ROUTER_PROVIDER: z.enum(['osrm', 'haversine']).default('haversine'),
  OSRM_URL: z.string().default('http://localhost:5000'),

  STORAGE_PROVIDER: z.enum(['s3', 'local']).default('local'),
  STORAGE_LOCAL_DIR: z.string().default('./storage'),
  OBJECT_STORAGE_ENDPOINT: z.string().optional().default(''),
  OBJECT_STORAGE_REGION: z.string().optional().default('auto'),
  OBJECT_STORAGE_BUCKET: z.string().optional().default(''),
  OBJECT_STORAGE_ACCESS_KEY: z.string().optional().default(''),
  OBJECT_STORAGE_SECRET_KEY: z.string().optional().default(''),

  APK_DIR: z.string().default('./apk'),
  ADMIN_DIST_DIR: z.string().optional().default(''),

  PLAY_INTEGRITY_PROJECT_NUMBER: z.string().optional().default(''),
  PLAY_INTEGRITY_SERVICE_ACCOUNT_FILE: z.string().optional().default(''),

  TURN_SECRET: z.string().optional().default(''),
  TURN_REALM: z.string().default('ridema'),
  TURN_URLS: z.string().optional().default(''),

  SENTRY_DSN: z.string().optional().default(''),
  SENTRY_ENVIRONMENT: z.string().default('development'),
  ALERT_WEBHOOK_URL: z.string().optional().default(''),

  RUN_OUTBOX_DISPATCHER: bool.default(true),
  RATE_LIMIT_MULTIPLIER: z.coerce.number().default(1),
});

export type Config = z.infer<typeof schema> & { publicBaseUrl: string };

export function loadConfig(env: Record<string, string | undefined> = process.env): Config {
  const parsed = schema.safeParse(env);
  if (!parsed.success) {
    const issues = parsed.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`).join('; ');
    throw new Error(`Invalid configuration: ${issues}`);
  }
  const c = parsed.data;
  if (c.NODE_ENV === 'production') {
    for (const k of ['JWT_SECRET', 'DOCUMENT_MASTER_KEY', 'TOTP_ENC_KEY'] as const) {
      if (!env[k]) throw new Error(`${k} must be set in production`);
    }
  }
  const host = c.PUBLIC_HOST || `${c.SERVER_IP}.sslip.io`;
  const publicBaseUrl = c.NODE_ENV === 'production' ? `https://${host}` : `http://${host === '127.0.0.1.sslip.io' ? `localhost:${c.PORT}` : host}`;
  return { ...c, publicBaseUrl };
}
