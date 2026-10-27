import type { Redis } from 'ioredis';
import { tooMany } from '../lib/errors.js';

export class RateLimiter {
  /** multiplier > 1 relaxes every limit (load tests, functional tests that are not about limits). */
  constructor(private redis: Redis, private prefix: string, private multiplier = 1) {}

  /** Fixed-window counter. Returns the count after this hit. */
  async hit(key: string, windowSec: number): Promise<number> {
    const k = `${this.prefix}:rl:${key}:${Math.floor(Date.now() / 1000 / windowSec)}`;
    const n = await this.redis.incr(k);
    if (n === 1) await this.redis.expire(k, windowSec + 1);
    return n;
  }

  /** Non-throwing variant for sockets. */
  async allow(key: string, limit: number, windowSec: number): Promise<boolean> {
    return (await this.hit(key, windowSec)) <= limit * this.multiplier;
  }

  async enforce(key: string, limit: number, windowSec: number, code = 'RATE_LIMITED'): Promise<void> {
    const n = await this.hit(key, windowSec);
    if (n > limit * this.multiplier) throw tooMany(code, 'Too many requests, please wait a moment.');
  }
}
