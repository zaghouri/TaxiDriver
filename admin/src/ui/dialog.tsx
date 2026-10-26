import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from 'react';
import { useT } from '../i18n';

interface ConfirmOpts {
  title: string;
  message?: ReactNode;
  confirmLabel?: string;
  danger?: boolean;
}
interface PromptOpts extends ConfirmOpts {
  label: string;
  initial?: string;
  multiline?: boolean;
  minLength?: number;
  placeholder?: string;
  /** Typed confirmation: the text must equal this exactly. */
  expect?: string;
}
interface DialogApi {
  confirm(o: ConfirmOpts): Promise<boolean>;
  prompt(o: PromptOpts): Promise<string | null>;
}

type State = { kind: 'confirm'; o: ConfirmOpts; resolve: (v: boolean) => void } | { kind: 'prompt'; o: PromptOpts; resolve: (v: string | null) => void } | null;

const Ctx = createContext<DialogApi>({ confirm: async () => false, prompt: async () => null });

export function DialogProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<State>(null);
  const confirm = useCallback((o: ConfirmOpts) => new Promise<boolean>((resolve) => setState({ kind: 'confirm', o, resolve })), []);
  const prompt = useCallback((o: PromptOpts) => new Promise<string | null>((resolve) => setState({ kind: 'prompt', o, resolve })), []);
  return (
    <Ctx.Provider value={{ confirm, prompt }}>
      {children}
      {state && <DialogView state={state} close={() => setState(null)} />}
    </Ctx.Provider>
  );
}

function DialogView({ state, close }: { state: NonNullable<State>; close: () => void }) {
  const t = useT();
  const [text, setText] = useState(state.kind === 'prompt' ? (state.o.initial ?? '') : '');
  const inputRef = useRef<HTMLInputElement & HTMLTextAreaElement>(null);
  useEffect(() => inputRef.current?.focus(), []);
  const o = state.o;
  const p = state.kind === 'prompt' ? state.o : null;
  const valid = !p || (p.expect !== undefined ? text === p.expect : text.trim().length >= (p.minLength ?? 1));
  const cancel = () => {
    if (state.kind === 'confirm') state.resolve(false);
    else state.resolve(null);
    close();
  };
  const ok = () => {
    if (!valid) return;
    if (state.kind === 'confirm') state.resolve(true);
    else state.resolve(text.trim());
    close();
  };
  return (
    <div className="modal-back" onKeyDown={(e) => e.key === 'Escape' && cancel()}>
      <form
        role="dialog"
        aria-modal="true"
        aria-label={o.title}
        className="modal"
        onSubmit={(e) => {
          e.preventDefault();
          ok();
        }}
      >
        <h3>{o.title}</h3>
        {o.message && <div className="modal-msg">{o.message}</div>}
        {p && (
          <label className="field">
            <span>{p.label}</span>
            {p.multiline ? (
              <textarea ref={inputRef} rows={4} value={text} placeholder={p.placeholder} onChange={(e) => setText(e.target.value)} />
            ) : (
              <input ref={inputRef} value={text} placeholder={p.placeholder} onChange={(e) => setText(e.target.value)} />
            )}
            {p.minLength && p.expect === undefined ? <small className="muted">{t('min_chars', { n: p.minLength })}</small> : null}
          </label>
        )}
        <div className="row-end">
          <button type="button" className="btn" onClick={cancel}>
            {t('cancel')}
          </button>
          <button type="submit" className={`btn ${o.danger ? 'btn-danger' : 'btn-primary'}`} disabled={!valid}>
            {o.confirmLabel ?? t('confirm')}
          </button>
        </div>
      </form>
    </div>
  );
}

export const useDialog = () => useContext(Ctx);
