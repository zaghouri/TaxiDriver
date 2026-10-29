import type { Logger } from '../logger.js';

/** What a saved emergency contact receives when the user presses SOS (D71). */
export interface EmergencyMessage {
  /** First name of the person who pressed SOS. */
  from: string;
  /** Live trip-share link. */
  url: string;
}

/**
 * A channel that can deliver a one-time phone verification code (never used for login, D7) and, through the same
 * WhatsApp account, the SOS alert to saved emergency contacts (D71).
 * `sendEmergency` returns `sent` when a message left, `logged` when it was only written to the log (no template yet).
 */
export interface OtpChannel {
  readonly name: string;
  sendCode(phone: string, code: string, locale: 'ar' | 'fr' | 'en'): Promise<void>;
  sendEmergency(phone: string, m: EmergencyMessage, locale: 'ar' | 'fr' | 'en'): Promise<'sent' | 'logged'>;
}

export class LogOtpChannel implements OtpChannel {
  readonly name = 'log';
  readonly sent: { phone: string; code: string }[] = [];
  readonly emergency: { phone: string; message: EmergencyMessage; locale: string }[] = [];
  constructor(private log?: Logger) {}
  async sendCode(phone: string, code: string) {
    this.sent.push({ phone, code });
    this.log?.info({ phone, otp: code }, 'PHONE CODE (log channel)');
  }
  async sendEmergency(phone: string, message: EmergencyMessage, locale: 'ar' | 'fr' | 'en') {
    this.emergency.push({ phone, message, locale });
    this.log?.warn({ phone, from: message.from, url: message.url }, 'SOS CONTACT ALERT (log channel)');
    return 'logged' as const;
  }
}

/** Meta WhatsApp Business Cloud API, authentication template with a copy-code button. */
export class WhatsAppOtpChannel implements OtpChannel {
  readonly name = 'whatsapp';
  constructor(private opts: { phoneNumberId: string; token: string; template: string; apiVersion: string; sosTemplate?: string; log?: Logger }) {}

  /**
   * Utility template `WHATSAPP_SOS_TEMPLATE` with two body parameters: the user's first name and the live trip link.
   * Until Meta approves it (B3) the alert is only logged, so operators still see it in the admin SOS view.
   */
  async sendEmergency(phone: string, m: EmergencyMessage, locale: 'ar' | 'fr' | 'en') {
    if (!this.opts.sosTemplate) {
      this.opts.log?.warn({ phone, from: m.from, url: m.url }, 'SOS CONTACT ALERT not sent: WHATSAPP_SOS_TEMPLATE is not set');
      return 'logged' as const;
    }
    const url = `https://graph.facebook.com/${this.opts.apiVersion}/${this.opts.phoneNumberId}/messages`;
    const res = await fetch(url, {
      method: 'POST',
      headers: { authorization: `Bearer ${this.opts.token}`, 'content-type': 'application/json' },
      body: JSON.stringify({
        messaging_product: 'whatsapp',
        to: phone.replace('+', ''),
        type: 'template',
        template: {
          name: this.opts.sosTemplate,
          language: { code: locale },
          components: [{ type: 'body', parameters: [{ type: 'text', text: m.from }, { type: 'text', text: m.url }] }],
        },
      }),
    });
    if (!res.ok) throw new Error(`WhatsApp SOS send failed: ${res.status} ${await res.text()}`);
    return 'sent' as const;
  }
  async sendCode(phone: string, code: string, locale: 'ar' | 'fr' | 'en') {
    const url = `https://graph.facebook.com/${this.opts.apiVersion}/${this.opts.phoneNumberId}/messages`;
    const res = await fetch(url, {
      method: 'POST',
      headers: { authorization: `Bearer ${this.opts.token}`, 'content-type': 'application/json' },
      body: JSON.stringify({
        messaging_product: 'whatsapp',
        to: phone.replace('+', ''),
        type: 'template',
        template: {
          name: this.opts.template,
          language: { code: locale },
          components: [
            { type: 'body', parameters: [{ type: 'text', text: code }] },
            { type: 'button', sub_type: 'url', index: '0', parameters: [{ type: 'text', text: code }] },
          ],
        },
      }),
    });
    if (!res.ok) throw new Error(`WhatsApp send failed: ${res.status} ${await res.text()}`);
  }
}

/** SMS slot required by the brief: present behind the same interface, switched off. */
export class DisabledSmsChannel implements OtpChannel {
  readonly name = 'sms-disabled';
  async sendCode(): Promise<void> {
    throw new Error('SMS channel is disabled');
  }
  async sendEmergency(): Promise<'sent' | 'logged'> {
    throw new Error('SMS channel is disabled');
  }
}
