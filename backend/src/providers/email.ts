import nodemailer from 'nodemailer';
import type { Logger } from '../logger.js';

export interface Mail {
  to: string;
  subject: string;
  text: string;
  html?: string;
}

export interface EmailProvider {
  readonly name: string;
  send(mail: Mail): Promise<void>;
}

/** Development/mock: prints the email (codes included) to the log and keeps it in memory for tests. */
export class LogEmailProvider implements EmailProvider {
  readonly name = 'log';
  readonly sent: Mail[] = [];
  constructor(private log?: Logger) {}
  async send(mail: Mail) {
    this.sent.push(mail);
    this.log?.info({ to: mail.to, subject: mail.subject, text: mail.text }, 'EMAIL (log provider)');
  }
}

export class SmtpEmailProvider implements EmailProvider {
  readonly name = 'smtp';
  private transport;
  constructor(opts: { host: string; port: number; user: string; pass: string; from: string }) {
    this.transport = nodemailer.createTransport({
      host: opts.host,
      port: opts.port,
      secure: opts.port === 465,
      auth: { user: opts.user, pass: opts.pass },
    });
    this.from = opts.from;
  }
  private from: string;
  async send(mail: Mail) {
    await this.transport.sendMail({ from: this.from, ...mail });
  }
}
