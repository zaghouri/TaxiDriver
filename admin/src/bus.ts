import { useEffect, useRef } from 'react';

type Handler = (data: any) => void;

/** In-app event bus: socket events are re-published here so pages can subscribe. */
class Bus {
  private map = new Map<string, Set<Handler>>();
  on(event: string, h: Handler) {
    let s = this.map.get(event);
    if (!s) this.map.set(event, (s = new Set()));
    s.add(h);
    return () => void s!.delete(h);
  }
  emit(event: string, data?: unknown) {
    for (const h of [...(this.map.get(event) ?? [])]) h(data);
  }
  clear() {
    this.map.clear();
  }
}

export const bus = new Bus();

export function useBusEvent(event: string, handler: Handler) {
  const ref = useRef(handler);
  ref.current = handler;
  useEffect(() => bus.on(event, (d) => ref.current(d)), [event]);
}
