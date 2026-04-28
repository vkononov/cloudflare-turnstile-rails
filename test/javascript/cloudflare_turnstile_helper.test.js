/*
 * Unit tests for lib/cloudflare/turnstile/rails/assets/javascripts/cloudflare_turnstile_helper.js
 *
 * Each test boots the helper inside a fresh JSDOM window so module-level
 * state, `document` event listeners, IntersectionObserver/MutationObserver
 * registrations, etc. cannot leak across cases. The helper file itself is
 * never modified; we just `dom.window.eval(HELPER_SRC)` after stubbing
 * `document.currentScript` and `window.IntersectionObserver`.
 */
import { afterEach, beforeEach, describe, expect, test, vi } from 'vitest';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { JSDOM } from 'jsdom';

const HELPER_PATH = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  '../../lib/cloudflare/turnstile/rails/assets/javascripts/cloudflare_turnstile_helper.js'
);
const HELPER_SRC = readFileSync(HELPER_PATH, 'utf8');

const DEFAULT_API_URL = 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';

// ---------- per-test fixture ----------

let dom;
let win;
let doc;
let warnSpy;
let ioInstances; // FakeIntersectionObserver instances
let withoutIO;   // when true, do not install IntersectionObserver on window

beforeEach(() => {
  dom = new JSDOM('<!DOCTYPE html><html><head></head><body></body></html>', {
    url: 'http://localhost/',
    runScripts: 'outside-only',
    pretendToBeVisual: true
  });
  win = dom.window;
  doc = win.document;
  ioInstances = [];
  withoutIO = false;

  // Quiet the helper's console.warn calls but keep them inspectable.
  warnSpy = vi.spyOn(win.console, 'warn').mockImplementation(() => {});
});

afterEach(() => {
  warnSpy.mockRestore();
  dom.window.close();
});

// ---------- helpers ----------

class FakeIntersectionObserver {
  constructor(callback, options) {
    this.callback = callback;
    this.options = options;
    this.observed = [];
    this.unobserved = [];
    ioInstances.push(this);
  }
  observe(el) { this.observed.push(el); }
  unobserve(el) { this.unobserved.push(el); }
  disconnect() { this.observed = []; }
  // Test-only: simulate the element entering the viewport.
  trigger(el, isIntersecting = true) {
    this.callback([{ target: el, isIntersecting }]);
  }
}

function placeholder(attrs = {}) {
  const div = doc.createElement('div');
  div.className = 'cf-turnstile';
  for (const [k, v] of Object.entries(attrs)) {
    div.setAttribute(k, v);
  }
  doc.body.appendChild(div);
  return div;
}

function bootHelper(options = {}) {
  const {
    scriptUrl = DEFAULT_API_URL,
    lazyMount = 'true', // string or null to omit the attribute entirely
    nonce = null,
    omitCurrentScript = false
  } = options;

  if (!withoutIO) {
    win.IntersectionObserver = FakeIntersectionObserver;
  }

  let helperScriptTag = null;
  if (!omitCurrentScript) {
    helperScriptTag = doc.createElement('script');
    helperScriptTag.id = 'cf-turnstile-helper-tag';
    if (scriptUrl !== null) helperScriptTag.setAttribute('data-script-url', scriptUrl);
    if (lazyMount !== null) helperScriptTag.setAttribute('data-lazy-mount', lazyMount);
    if (nonce !== null) helperScriptTag.setAttribute('nonce', nonce);
    doc.head.appendChild(helperScriptTag);
    Object.defineProperty(doc, 'currentScript', {
      configurable: true,
      get: () => helperScriptTag
    });
  }

  win.eval(HELPER_SRC);
  return helperScriptTag;
}

function getInjectedApiScript() {
  return Array.from(doc.head.querySelectorAll('script'))
    .find((s) => s.src && s.src.indexOf('api.js') !== -1);
}

function fireGesture(type) {
  const ev = new win.Event(type, { bubbles: true });
  doc.dispatchEvent(ev);
}

// MutationObserver in jsdom fires asynchronously on a microtask. Awaiting two
// microtasks gives the queued callback a chance to run.
async function flushMicrotasks() {
  await Promise.resolve();
  await Promise.resolve();
}

// ---------- tests ----------

describe('public API surface', () => {
  test('exposes window.cfTurnstile with ensureLoaded, mount, mountAll', () => {
    bootHelper();

    expect(typeof win.cfTurnstile).toBe('object');
    expect(typeof win.cfTurnstile.ensureLoaded).toBe('function');
    expect(typeof win.cfTurnstile.mount).toBe('function');
    expect(typeof win.cfTurnstile.mountAll).toBe('function');
  });

  test('init guard: re-running the helper script does not re-install global listeners', () => {
    placeholder();
    bootHelper();
    const firstApi = win.cfTurnstile;

    // Re-evaluate the helper as if Turbolinks restored a cached page that
    // re-executed the <script> tag. The init guard should kick in.
    const addSpy = vi.spyOn(doc, 'addEventListener');
    win.eval(HELPER_SRC);
    const reAddedEvents = addSpy.mock.calls.map((c) => c[0]);

    // Public API is preserved (not re-assigned).
    expect(win.cfTurnstile).toBe(firstApi);
    // None of the global listeners are re-added.
    expect(reAddedEvents).not.toContain('pointerdown');
    expect(reAddedEvents).not.toContain('keydown');
    expect(reAddedEvents).not.toContain('turbo:render');
    expect(reAddedEvents).not.toContain('turbo:frame-load');
    expect(reAddedEvents).not.toContain('turbolinks:load');
  });
});

describe('injectApiScript', () => {
  test('first mount() injects api.js with the configured script URL', () => {
    const el = placeholder();
    bootHelper();

    win.cfTurnstile.mount(el);

    const injected = getInjectedApiScript();
    expect(injected).toBeTruthy();
    expect(injected.src).toBe(DEFAULT_API_URL);
    expect(injected.async).toBe(true);
    expect(injected.defer).toBe(true);
  });

  test('CSP nonce on the helper tag is propagated to the injected api.js tag', () => {
    bootHelper({ nonce: 'abc123' });
    win.cfTurnstile.ensureLoaded(() => {});

    const injected = getInjectedApiScript();
    expect(injected.nonce).toBe('abc123');
  });

  test('warns and bails when data-script-url is missing', () => {
    bootHelper({ scriptUrl: null });
    win.cfTurnstile.ensureLoaded(() => {});

    expect(getInjectedApiScript()).toBeUndefined();
    expect(warnSpy).toHaveBeenCalledWith(
      expect.stringContaining('missing data-script-url')
    );
  });

  test('onerror resets loadState so a later mount() retries the injection', () => {
    bootHelper();
    win.cfTurnstile.ensureLoaded(() => {});
    const first = getInjectedApiScript();
    expect(first).toBeTruthy();

    first.onerror();
    expect(warnSpy).toHaveBeenCalledWith(
      expect.stringContaining('failed to load Cloudflare Turnstile api.js')
    );

    // Drop the failed tag so the next call creates a fresh one we can assert on.
    first.remove();

    win.cfTurnstile.ensureLoaded(() => {});
    expect(getInjectedApiScript()).toBeTruthy();
  });

  test('does not double-inject api.js while already loading', () => {
    bootHelper();
    win.cfTurnstile.ensureLoaded(() => {});
    win.cfTurnstile.ensureLoaded(() => {});
    win.cfTurnstile.ensureLoaded(() => {});

    const allApi = Array.from(doc.head.querySelectorAll('script'))
      .filter((s) => s.src && s.src.indexOf('api.js') !== -1);
    expect(allApi.length).toBe(1);
  });
});

describe('ensureLoaded', () => {
  test('ignores non-function arguments without throwing', () => {
    bootHelper();
    expect(() => win.cfTurnstile.ensureLoaded('not a fn')).not.toThrow();
    expect(() => win.cfTurnstile.ensureLoaded(null)).not.toThrow();
    expect(() => win.cfTurnstile.ensureLoaded()).not.toThrow();
    expect(getInjectedApiScript()).toBeUndefined();
  });

  test('queued callbacks all fire when api.js onload resolves', () => {
    bootHelper();
    const a = vi.fn();
    const b = vi.fn();
    const c = vi.fn();
    win.cfTurnstile.ensureLoaded(a);
    win.cfTurnstile.ensureLoaded(b);
    win.cfTurnstile.ensureLoaded(c);

    expect(a).not.toHaveBeenCalled();

    win.turnstile = { render: vi.fn() };
    getInjectedApiScript().onload();

    expect(a).toHaveBeenCalledOnce();
    expect(b).toHaveBeenCalledOnce();
    expect(c).toHaveBeenCalledOnce();
  });

  test('a throwing callback does not block subsequent callbacks (try/catch isolation)', () => {
    bootHelper();
    const bad = vi.fn(() => { throw new Error('boom'); });
    const good = vi.fn();
    win.cfTurnstile.ensureLoaded(bad);
    win.cfTurnstile.ensureLoaded(good);

    win.turnstile = { render: vi.fn() };
    getInjectedApiScript().onload();

    expect(bad).toHaveBeenCalled();
    expect(good).toHaveBeenCalledOnce();
    expect(warnSpy).toHaveBeenCalledWith(
      expect.stringContaining('api.js callback failed'),
      expect.any(Error)
    );
  });

  test('when window.turnstile is already defined the callback fires asynchronously', async () => {
    bootHelper();
    win.turnstile = { render: vi.fn() };
    const cb = vi.fn();

    win.cfTurnstile.ensureLoaded(cb);
    expect(cb).not.toHaveBeenCalled(); // setTimeout(cb, 0), not synchronous

    await new Promise((resolve) => win.setTimeout(resolve, 5));
    expect(cb).toHaveBeenCalledOnce();
    // Crucially, no api.js was injected — turnstile was already loaded.
    expect(getInjectedApiScript()).toBeUndefined();
  });
});

describe('isAlreadyMounted (via mount)', () => {
  test('skips mount when data-turnstile-rendered="true"', () => {
    const el = placeholder({ 'data-turnstile-rendered': 'true' });
    bootHelper();

    win.cfTurnstile.mount(el);
    // Already-mounted means we never need api.js.
    expect(getInjectedApiScript()).toBeUndefined();
  });

  test('skips mount when the element already has child elements', () => {
    const el = placeholder();
    el.appendChild(doc.createElement('iframe'));
    bootHelper();

    win.cfTurnstile.mount(el);
    expect(getInjectedApiScript()).toBeUndefined();
  });
});

describe('IntersectionObserver path', () => {
  test('observes every pending .cf-turnstile placeholder at boot', () => {
    placeholder();
    placeholder();
    placeholder({ 'data-turnstile-rendered': 'true' }); // already done, skip
    bootHelper();

    expect(ioInstances.length).toBe(1);
    expect(ioInstances[0].observed.length).toBe(2);
  });

  test('intersection event renders the widget and marks it data-turnstile-rendered', () => {
    const el = placeholder();
    bootHelper();

    // Trigger the intersection FIRST, before window.turnstile exists, so the
    // helper takes the queue-and-inject branch of ensureLoaded.
    ioInstances[0].trigger(el);
    const apiScript = getInjectedApiScript();
    expect(apiScript).toBeTruthy();

    const render = vi.fn();
    win.turnstile = { render };
    apiScript.onload();

    expect(render).toHaveBeenCalledWith(el);
    expect(el.dataset.turnstileRendered).toBe('true');
  });

  test('non-intersecting entries are ignored', () => {
    const el = placeholder();
    bootHelper();

    win.turnstile = { render: vi.fn() };
    ioInstances[0].trigger(el, false);

    // No api.js injected because no mount() was called.
    expect(getInjectedApiScript()).toBeUndefined();
  });

  test('mount() unobserves the element so it cannot fire twice', () => {
    const el = placeholder();
    bootHelper();

    win.cfTurnstile.mount(el);
    expect(ioInstances[0].unobserved).toContain(el);
  });

  test('falls back to mountAll() when IntersectionObserver is not available', () => {
    withoutIO = true;
    const el = placeholder();
    bootHelper();
    // Confirm we really have no IO available in this test.
    expect(typeof win.IntersectionObserver).toBe('undefined');

    win.turnstile = { render: vi.fn() };
    getInjectedApiScript().onload();

    expect(win.turnstile.render).toHaveBeenCalledWith(el);
  });
});

describe('MutationObserver path', () => {
  test('a .cf-turnstile added directly to the body is observed', async () => {
    bootHelper();
    expect(ioInstances[0].observed.length).toBe(0);

    const el = placeholder();
    await flushMicrotasks();

    expect(ioInstances[0].observed).toContain(el);
  });

  test('a nested .cf-turnstile inside an added subtree is observed', async () => {
    bootHelper();

    const wrapper = doc.createElement('section');
    const inner = doc.createElement('div');
    inner.className = 'cf-turnstile';
    wrapper.appendChild(inner);
    doc.body.appendChild(wrapper);
    await flushMicrotasks();

    expect(ioInstances[0].observed).toContain(inner);
  });

  test('an already-rendered .cf-turnstile added later is not re-observed', async () => {
    bootHelper();

    const el = placeholder({ 'data-turnstile-rendered': 'true' });
    await flushMicrotasks();

    expect(ioInstances[0].observed).not.toContain(el);
  });
});

describe('Turbo / Turbolinks hooks', () => {
  test.each([
    ['turbo:render'],
    ['turbo:frame-load'],
    ['turbolinks:load']
  ])('%s re-dispatches and observes newly-present placeholders', (eventName) => {
    bootHelper();
    expect(ioInstances[0].observed.length).toBe(0);

    // Add a placeholder via innerHTML so MutationObserver is guaranteed not
    // to have fired yet for it on the same tick we dispatch the event.
    doc.body.insertAdjacentHTML('beforeend', '<div class="cf-turnstile"></div>');
    fireGesture(eventName);

    const added = doc.body.lastElementChild;
    expect(ioInstances[0].observed).toContain(added);
  });
});

describe('eager mode (data-lazy-mount=false)', () => {
  test('loads api.js immediately at boot', () => {
    bootHelper({ lazyMount: 'false' });

    const injected = getInjectedApiScript();
    expect(injected).toBeTruthy();
    expect(injected.src).toBe(DEFAULT_API_URL);
  });

  test('does not register an IntersectionObserver', () => {
    placeholder();
    bootHelper({ lazyMount: 'false' });

    expect(ioInstances.length).toBe(0);
  });

  test('does not register Turbo hooks (regression check)', () => {
    bootHelper({ lazyMount: 'false' });

    const dispatchSpy = vi.spyOn(win.cfTurnstile, 'mountAll');
    fireGesture('turbo:render');
    fireGesture('turbo:frame-load');
    fireGesture('turbolinks:load');

    expect(dispatchSpy).not.toHaveBeenCalled();
  });

  test('does not register gesture listeners', () => {
    bootHelper({ lazyMount: 'false' });

    const beforeApi = getInjectedApiScript();
    fireGesture('pointerdown');
    fireGesture('keydown');
    const afterApi = getInjectedApiScript();
    // Same single api.js tag — no extra triggering happened.
    expect(afterApi).toBe(beforeApi);
  });
});

describe('gesture trigger', () => {
  test.each([['pointerdown'], ['keydown']])(
    'first %s mounts pending placeholders',
    (eventName) => {
      const el = placeholder();
      bootHelper();
      expect(getInjectedApiScript()).toBeUndefined();

      fireGesture(eventName);

      expect(getInjectedApiScript()).toBeTruthy();
      win.turnstile = { render: vi.fn() };
      getInjectedApiScript().onload();
      expect(win.turnstile.render).toHaveBeenCalledWith(el);
    }
  );

  test('subsequent gestures are no-ops (one-shot)', () => {
    placeholder();
    bootHelper();

    fireGesture('pointerdown');
    const firstApi = getInjectedApiScript();

    // Add another placeholder after the first gesture; a second gesture
    // should NOT trigger a fresh mountAll, because the listeners were torn
    // down after the first one fired. New placeholders rely on the
    // MutationObserver path instead.
    const second = placeholder();
    fireGesture('pointerdown');

    // Still only one api.js, and the second placeholder was discovered by
    // MutationObserver (so it's in IO.observed), not by gesture-driven mount.
    const allApi = Array.from(doc.head.querySelectorAll('script'))
      .filter((s) => s.src && s.src.indexOf('api.js') !== -1);
    expect(allApi.length).toBe(1);
    expect(firstApi).toBe(allApi[0]);
    // No render was forced on `second` from the gesture; it should still be
    // pending an intersection (or a manual mountAll).
    expect(second.dataset.turnstileRendered).toBeUndefined();
  });
});

describe('hidden-in-modal visibility filter', () => {
  test('first gesture skips a placeholder whose ancestor is display:none', () => {
    // Simulate a closed modal: a hidden wrapper containing the widget.
    const modal = doc.createElement('div');
    modal.id = 'modal';
    modal.style.display = 'none';
    const el = doc.createElement('div');
    el.className = 'cf-turnstile';
    modal.appendChild(el);
    doc.body.appendChild(modal);

    bootHelper();
    fireGesture('pointerdown');

    // Gesture must NOT have caused api.js to load — the widget is still
    // pending, waiting for the modal to open.
    expect(getInjectedApiScript()).toBeUndefined();
    expect(el.dataset.turnstileRendered).toBeUndefined();
  });

  test('first gesture skips a placeholder that is itself display:none', () => {
    const el = placeholder();
    el.style.display = 'none';

    bootHelper();
    fireGesture('keydown');

    expect(getInjectedApiScript()).toBeUndefined();
  });

  test('first gesture still mounts visible (laid-out) placeholders', () => {
    const visibleEl = placeholder();
    const hiddenWrapper = doc.createElement('div');
    hiddenWrapper.style.display = 'none';
    const hiddenEl = doc.createElement('div');
    hiddenEl.className = 'cf-turnstile';
    hiddenWrapper.appendChild(hiddenEl);
    doc.body.appendChild(hiddenWrapper);

    bootHelper();
    fireGesture('pointerdown');

    // api.js loaded (because the visible widget needs it),
    expect(getInjectedApiScript()).toBeTruthy();

    win.turnstile = { render: vi.fn() };
    getInjectedApiScript().onload();

    // ...but only the visible widget actually rendered.
    expect(win.turnstile.render).toHaveBeenCalledTimes(1);
    expect(win.turnstile.render).toHaveBeenCalledWith(visibleEl);
  });

  test('IntersectionObserver entries for display:none targets are filtered out', () => {
    // Headless Chrome (and some other engines) report isIntersecting=true
    // for elements whose ancestors are display:none — their (0,0,0,0)
    // bounding box overlaps the viewport+rootMargin. The helper must not
    // render those; that's the entire point of lazy-mounting widgets that
    // live inside closed modals.
    const modal = doc.createElement('div');
    modal.style.display = 'none';
    const el = doc.createElement('div');
    el.className = 'cf-turnstile';
    modal.appendChild(el);
    doc.body.appendChild(modal);

    bootHelper();

    ioInstances[0].trigger(el, true);

    expect(getInjectedApiScript()).toBeUndefined();
    expect(el.dataset.turnstileRendered).toBeUndefined();
  });

  test('once the modal "opens", the IntersectionObserver path mounts the widget', () => {
    const modal = doc.createElement('div');
    modal.style.display = 'none';
    const el = doc.createElement('div');
    el.className = 'cf-turnstile';
    modal.appendChild(el);
    doc.body.appendChild(modal);

    bootHelper();
    fireGesture('pointerdown');
    expect(getInjectedApiScript()).toBeUndefined();

    // "Open the modal" — IO would automatically fire in a real browser.
    // Our FakeIntersectionObserver requires manual triggering.
    modal.style.display = '';
    ioInstances[0].trigger(el);

    expect(getInjectedApiScript()).toBeTruthy();
    const renderSpy = vi.fn();
    win.turnstile = { render: renderSpy };
    getInjectedApiScript().onload();

    expect(renderSpy).toHaveBeenCalledTimes(1);
    // .toHaveBeenCalledWith(el) is avoided here because vitest's diff
    // formatter chokes on JSDOM elements that live under a display:none
    // ancestor — direct reference equality side-steps the printer.
    expect(renderSpy.mock.calls[0][0]).toBe(el);
  });

  test('public cfTurnstile.mountAll() still force-mounts hidden widgets', () => {
    const modal = doc.createElement('div');
    modal.style.display = 'none';
    const el = doc.createElement('div');
    el.className = 'cf-turnstile';
    modal.appendChild(el);
    doc.body.appendChild(modal);

    bootHelper();
    win.cfTurnstile.mountAll();

    expect(getInjectedApiScript()).toBeTruthy();
    const renderSpy = vi.fn();
    win.turnstile = { render: renderSpy };
    getInjectedApiScript().onload();

    expect(renderSpy).toHaveBeenCalledTimes(1);
    expect(renderSpy.mock.calls[0][0]).toBe(el);
  });
});

describe('mount() race protection and error handling', () => {
  test('calling mount(el) twice synchronously results in exactly one render', () => {
    const el = placeholder();
    bootHelper();

    win.cfTurnstile.mount(el);
    win.cfTurnstile.mount(el);

    win.turnstile = { render: vi.fn() };
    getInjectedApiScript().onload();

    expect(win.turnstile.render).toHaveBeenCalledTimes(1);
  });

  test('a throwing turnstile.render is caught and logged, not bubbled', () => {
    const el = placeholder();
    bootHelper();

    win.cfTurnstile.mount(el);
    win.turnstile = { render: vi.fn(() => { throw new Error('cf says no'); }) };

    expect(() => getInjectedApiScript().onload()).not.toThrow();
    expect(warnSpy).toHaveBeenCalledWith(
      expect.stringContaining('turnstile.render failed'),
      expect.any(Error)
    );
    // Marker NOT set when render threw — a later mount can retry.
    expect(el.dataset.turnstileRendered).toBeUndefined();
  });
});
