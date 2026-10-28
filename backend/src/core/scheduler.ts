import { Queue } from 'bullmq';
import type { Redis } from 'ioredis';

export type JobName = 'ride-expire' | 'bid-expire' | 'ride-wave' | 'ride-late';
export const TIMEOUT_QUEUE = 'ridema-timeouts';

export interface Scheduler {
  schedule(name: JobName, data: Record<string, string>, delayMs: number, jobId: string): Promise<void>;
  close(): Promise<void>;
}

/** Ride and bid timeouts as BullMQ delayed jobs. Handlers re-check state, so duplicates are harmless. */
export class BullScheduler implements Scheduler {
  private queue: Queue;
  constructor(connection: Redis, prefix: string) {
    this.queue = new Queue(TIMEOUT_QUEUE, { connection, prefix: `${prefix}:bull` });
  }
  async schedule(name: JobName, data: Record<string, string>, delayMs: number, jobId: string) {
    await this.queue.add(name, data, {
      delay: Math.max(0, delayMs),
      jobId,
      attempts: 5,
      backoff: { type: 'exponential', delay: 1000 },
      removeOnComplete: 1000,
      removeOnFail: 5000,
    });
  }
  get bullQueue() {
    return this.queue;
  }
  async close() {
    await this.queue.close();
  }
}

export class MemoryScheduler implements Scheduler {
  readonly jobs: { name: JobName; data: Record<string, string>; delayMs: number; jobId: string }[] = [];
  async schedule(name: JobName, data: Record<string, string>, delayMs: number, jobId: string) {
    this.jobs.push({ name, data, delayMs, jobId });
  }
  async close() {}
}
