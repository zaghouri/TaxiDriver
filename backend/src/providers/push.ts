import { readFileSync } from 'node:fs';
import type { Logger } from '../logger.js';

export interface PushMessage {
  title: string;
  body: string;
  data?: Record<string, string>;
  /** Android channel id; drivers' ride requests use a high-importance channel with sound. */
  channel?: string;
  /** Android notification tag: a later push with the same tag replaces the earlier one (the rider's live ride notification, D69). */
  tag?: string;
}

export interface PushProvider {
  readonly name: string;
  /** Returns tokens the provider reported as invalid so they can be removed. */
  send(tokens: string[], msg: PushMessage): Promise<string[]>;
}

export class LogPushProvider implements PushProvider {
  readonly name = 'log';
  readonly sent: { tokens: string[]; msg: PushMessage }[] = [];
  constructor(private log?: Logger) {}
  async send(tokens: string[], msg: PushMessage) {
    this.sent.push({ tokens, msg });
    this.log?.debug({ count: tokens.length, title: msg.title }, 'PUSH (log provider)');
    return [];
  }
}

export class FcmPushProvider implements PushProvider {
  readonly name = 'fcm';
  private messaging: any;
  constructor(private serviceAccountFile: string) {}
  private async init() {
    if (this.messaging) return this.messaging;
    const { initializeApp, getApps, cert } = await import('firebase-admin/app');
    const { getMessaging } = await import('firebase-admin/messaging');
    const cred = JSON.parse(readFileSync(this.serviceAccountFile, 'utf8'));
    const app = getApps()[0] ?? initializeApp({ credential: cert(cred) });
    this.messaging = getMessaging(app);
    return this.messaging;
  }
  async send(tokens: string[], msg: PushMessage) {
    if (!tokens.length) return [];
    const m = await this.init();
    const res = await m.sendEachForMulticast({
      tokens,
      notification: { title: msg.title, body: msg.body },
      data: msg.data ?? {},
      android: { priority: 'high', notification: { channelId: msg.channel ?? 'default', ...(msg.tag ? { tag: msg.tag } : {}) } },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    const invalid: string[] = [];
    res.responses.forEach((r: any, i: number) => {
      const code = r.error?.code ?? '';
      if (code.includes('registration-token-not-registered') || code.includes('invalid-argument')) invalid.push(tokens[i]);
    });
    return invalid;
  }
}
