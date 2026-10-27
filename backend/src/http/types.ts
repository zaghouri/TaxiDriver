import type { Role, Scope } from './tokens.js';

export type AuthMode = 'none' | 'optional' | 'user' | Role;

export interface RouteConfig {
  auth?: AuthMode;
  /** Writes need an Idempotency-Key unless false. */
  idempotent?: boolean;
  /** Allowed for admins still in TOTP enrolment. */
  enrollOk?: boolean;
}

export interface AuthUser {
  id: string;
  role: Role;
  sid: string;
  scp: Scope;
}

declare module 'fastify' {
  interface FastifyRequest {
    user?: AuthUser;
    idem?: { scope: string; key: string };
  }
  // eslint-disable-next-line @typescript-eslint/no-empty-object-type
  interface FastifyContextConfig extends RouteConfig {}
}
