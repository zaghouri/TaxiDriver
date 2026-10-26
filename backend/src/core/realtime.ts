export type Target =
  | { user: string }
  | { ride: string }
  | { cityDrivers: string }
  | { admins: true }
  | { share: string };

/** Fan-out of realtime events. Implemented by Socket.IO in the API; recorded in tests. */
export interface Realtime {
  emit(target: Target, event: string, data: unknown): void;
}

export class RecordingRealtime implements Realtime {
  readonly events: { target: Target; event: string; data: any }[] = [];
  emit(target: Target, event: string, data: unknown) {
    this.events.push({ target, event, data });
  }
  for(target: Partial<Record<keyof any, unknown>>, event?: string) {
    const k = Object.keys(target)[0] as string;
    const v = (target as any)[k];
    return this.events.filter((e) => (e.target as any)[k] === v && (!event || e.event === event));
  }
  clear() {
    this.events.length = 0;
  }
}

export const roomOf = (t: Target): string => {
  if ('user' in t) return `user:${t.user}`;
  if ('ride' in t) return `ride:${t.ride}`;
  if ('cityDrivers' in t) return `drivers:${t.cityDrivers}`;
  if ('share' in t) return `share:${t.share}`;
  return 'admins';
};
