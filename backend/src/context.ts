import { Redis } from 'ioredis';
import type { Config } from './config.js';
import { createLogger, type Logger } from './logger.js';
import { createPool, type Db } from './db/pool.js';
import { SettingsService } from './core/settings.js';
import { OutboxDispatcher } from './core/outbox.js';
import { RateLimiter } from './core/ratelimit.js';
import { BullScheduler, type Scheduler } from './core/scheduler.js';
import { DriverGeoIndex } from './core/geo-index.js';
import type { Realtime } from './core/realtime.js';
import { LogEmailProvider, SmtpEmailProvider, type EmailProvider } from './providers/email.js';
import { DisabledSmsChannel, LogOtpChannel, WhatsAppOtpChannel, type OtpChannel } from './providers/otp.js';
import { FcmPushProvider, LogPushProvider, type PushProvider } from './providers/push.js';
import { HaversineRouter, OsrmRouter, type RouterProvider } from './providers/router.js';
import { LocalStorage, S3Storage, type StorageProvider } from './providers/storage.js';
import { createPaymentProviders, type PaymentMethod, type PaymentProvider } from './providers/payment.js';
import { MockIntegrityProvider, PlayIntegrityProvider, type IntegrityProvider } from './providers/integrity.js';

export interface AppContext {
  cfg: Config;
  log: Logger;
  db: Db;
  redis: Redis;
  settings: SettingsService;
  limiter: RateLimiter;
  scheduler: Scheduler;
  geo: DriverGeoIndex;
  realtime: Realtime;
  outbox: OutboxDispatcher;
  email: EmailProvider;
  otp: OtpChannel;
  sms: OtpChannel;
  push: PushProvider;
  router: RouterProvider;
  storage: StorageProvider;
  payments: Record<PaymentMethod, PaymentProvider>;
  integrity: IntegrityProvider;
}

/** Realtime is replaced by the Socket.IO implementation once the HTTP server exists. */
class DeferredRealtime implements Realtime {
  target?: Realtime;
  emit(t: any, e: string, d: unknown) {
    this.target?.emit(t, e, d);
  }
}

export type ContextOverrides = Partial<Omit<AppContext, 'cfg'>>;

export function createContext(cfg: Config, o: ContextOverrides = {}): AppContext {
  const log = o.log ?? createLogger(cfg.LOG_LEVEL);
  const db = o.db ?? createPool(cfg.DATABASE_URL);
  const redis = o.redis ?? new Redis(cfg.REDIS_URL, { maxRetriesPerRequest: null });
  const prefix = cfg.REDIS_PREFIX;

  const email =
    o.email ??
    (cfg.EMAIL_PROVIDER === 'smtp' && cfg.SMTP_HOST
      ? new SmtpEmailProvider({ host: cfg.SMTP_HOST, port: cfg.SMTP_PORT, user: cfg.SMTP_USER, pass: cfg.SMTP_PASS, from: cfg.SMTP_FROM })
      : new LogEmailProvider(log));
  const otp =
    o.otp ??
    (cfg.OTP_CHANNEL === 'whatsapp' && cfg.WHATSAPP_ACCESS_TOKEN
      ? new WhatsAppOtpChannel({ phoneNumberId: cfg.WHATSAPP_PHONE_NUMBER_ID, token: cfg.WHATSAPP_ACCESS_TOKEN, template: cfg.WHATSAPP_OTP_TEMPLATE, apiVersion: cfg.WHATSAPP_API_VERSION })
      : new LogOtpChannel(log));
  const push = o.push ?? (cfg.PUSH_PROVIDER === 'fcm' && cfg.FIREBASE_SERVICE_ACCOUNT_FILE ? new FcmPushProvider(cfg.FIREBASE_SERVICE_ACCOUNT_FILE) : new LogPushProvider(log));
  const router = o.router ?? (cfg.ROUTER_PROVIDER === 'osrm' ? new OsrmRouter(cfg.OSRM_URL) : new HaversineRouter());
  const storage =
    o.storage ??
    (cfg.STORAGE_PROVIDER === 's3' && cfg.OBJECT_STORAGE_BUCKET
      ? new S3Storage({ endpoint: cfg.OBJECT_STORAGE_ENDPOINT, region: cfg.OBJECT_STORAGE_REGION, bucket: cfg.OBJECT_STORAGE_BUCKET, accessKey: cfg.OBJECT_STORAGE_ACCESS_KEY, secretKey: cfg.OBJECT_STORAGE_SECRET_KEY })
      : new LocalStorage(cfg.STORAGE_LOCAL_DIR));
  const integrity = o.integrity ?? (cfg.PLAY_INTEGRITY_SERVICE_ACCOUNT_FILE ? new PlayIntegrityProvider(cfg.PLAY_INTEGRITY_SERVICE_ACCOUNT_FILE) : new MockIntegrityProvider());
  const realtime = o.realtime ?? new DeferredRealtime();

  return {
    cfg,
    log,
    db,
    redis,
    settings: o.settings ?? new SettingsService(db),
    limiter: o.limiter ?? new RateLimiter(redis, prefix, cfg.RATE_LIMIT_MULTIPLIER),
    scheduler: o.scheduler ?? new BullScheduler(redis, prefix),
    geo: o.geo ?? new DriverGeoIndex(redis, prefix),
    realtime,
    outbox: o.outbox ?? new OutboxDispatcher({ db, databaseUrl: cfg.DATABASE_URL, realtime, push, email, log }),
    email,
    otp,
    sms: o.sms ?? new DisabledSmsChannel(),
    push,
    router,
    storage,
    payments: o.payments ?? createPaymentProviders(cfg.publicBaseUrl),
    integrity,
  };
}

export function attachRealtime(ctx: AppContext, rt: Realtime) {
  if (ctx.realtime instanceof DeferredRealtime) ctx.realtime.target = rt;
}

export async function closeContext(ctx: AppContext) {
  await ctx.outbox.stop().catch(() => undefined);
  await ctx.scheduler.close().catch(() => undefined);
  await ctx.db.end().catch(() => undefined);
  ctx.redis.disconnect();
}
