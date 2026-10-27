import type { Logger } from '../logger.js';

/** A channel that can deliver a one-time phone verification code. Never used for login (D7). */
export interface OtpChannel {
  readonly name: string;
  sendCode(phone: string, code: string, locale: 'ar' | 'fr' | 'en'): Promise<void>;
}

export class LogOtpChannel implements OtpChannel {
  readonly name = 'log';
  readonly sent: { phone: string; code: string }[] = [];
  constructor(private log?: Logger) {}
  async sendCode(phone: string, code: string) {
    this.sent.push({ phone, code });
    this.log?.info({ phone, otp: code }, 'PHONE CODE (log channel)');
  }
}

/** Meta WhatsApp Business Cloud API, authentication template with a copy-code button. */
export class WhatsAppOtpChannel implements OtpChannel {
  readonly name = 'whatsapp';
  constructor(private opts: { phoneNumberId: string; token: string; template: string; apiVersion: string }) {}
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
}
