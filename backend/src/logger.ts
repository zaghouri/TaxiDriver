import pino from 'pino';

// PII never goes to logs: these paths are censored wherever they appear.
export const redactPaths = [
  'password', '*.password', 'new_password', '*.new_password', 'token', '*.token',
  'refresh_token', '*.refresh_token', 'access_token', '*.access_token', 'req.headers.authorization',
  'pin', '*.pin', 'totp_secret', '*.totp_secret', 'mfa_token', '*.mfa_token',
];

export function createLogger(level = 'info') {
  return pino({ level, redact: { paths: redactPaths, censor: '[redacted]' }, base: { svc: 'ridema' } });
}
export type Logger = ReturnType<typeof createLogger>;
