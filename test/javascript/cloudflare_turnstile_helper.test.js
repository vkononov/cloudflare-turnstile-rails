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
    mountMode = 'lazy', // 'lazy' | 'eager' | 'passive', or null to omit the attribute
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
    if (mountMode !== null) helperScriptTag.setAttribute('data-mount-mode', mountMode);
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

// Resolve api.js and run every callback the helper queued behind it.
function resolveApiJs() {
  const render = vi.fn();
  win.turnstile = { render };
  const apiScript = getInjectedApiScript();
  if (apiScript) apiScript.onload();
  return render;
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

// When window.turnstile already exists, ensureLoaded() defers the callback with
// setTimeout(cb, 0) — a macrotask. Awaiting microtasks alone is not enough to
// see the render happen, so tests that mount against an already-loaded api.js
// must await this instead.
function flushMacrotasks() {
  return new Promise((resolve) => setTimeout(resolve, 0));
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
    expect(reAddedEvents).not.toContain('turbo:before-stream-render');
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

  test('skips mount when the element already contains an iframe (Cloudflare auto-render)', () => {
    // render=auto drops the iframe in without going through our mount()
    // path, so the marker is never set. The iframe lookup catches this.
    const el = placeholder();
    el.appendChild(doc.createElement('iframe'));
    bootHelper();

    win.cfTurnstile.mount(el);
    expect(getInjectedApiScript()).toBeUndefined();
  });

  test('proceeds with mount when the element contains a non-iframe placeholder child (e.g. a spinner)', () => {
    // Consumers sometimes put loading/fallback content inside the
    // placeholder. That content must NOT lock the widget out of being
    // mounted — only an actual Cloudflare iframe should.
    const el = placeholder();
    const spinner = doc.createElement('span');
    spinner.textContent = 'Loading...';
    el.appendChild(spinner);
    bootHelper();

    win.cfTurnstile.mount(el);

    // mount() must reach ensureLoaded() and inject api.js.
    expect(getInjectedApiScript()).toBeTruthy();

    const render = vi.fn();
    win.turnstile = { render };
    getInjectedApiScript().onload();

    expect(render).toHaveBeenCalledWith(el);
    expect(el.dataset.turnstileRendered).toBe('true');
  });

  test('skips mount when an iframe is nested deep inside the placeholder', () => {
    // The marker normally lives directly under the placeholder, but be
    // defensive — Cloudflare could change the structure. querySelector
    // (vs childElementCount) walks the subtree.
    const el = placeholder();
    const wrapper = doc.createElement('div');
    wrapper.appendChild(doc.createElement('iframe'));
    el.appendChild(wrapper);
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

  test('opening a closed modal mounts the previously-hidden placeholder', async () => {
    // Real-browser regression: Firefox does NOT re-fire IO when an
    // element transitions from `display: none` to `display: block`,
    // and Chrome can briefly mis-report intersection during rapid
    // unobserve/observe cycles. We sidestep both by mounting the
    // revealed placeholder directly the moment its layout becomes
    // non-`display: none`.
    const modal = doc.createElement('div');
    modal.style.display = 'none';
    const el = doc.createElement('div');
    el.className = 'cf-turnstile';
    modal.appendChild(el);
    doc.body.appendChild(modal);

    const renderSpy = vi.fn();
    bootHelper();
    win.turnstile = { render: renderSpy };
    await flushMicrotasks();

    // Initially hidden — should not have mounted.
    expect(renderSpy).not.toHaveBeenCalled();

    modal.style.display = '';
    await flushMicrotasks();
    // mount() routes through ensureLoaded → setTimeout(0); wait for the
    // macrotask to fire so window.turnstile.render gets called.
    await new Promise((resolve) => win.setTimeout(resolve, 5));

    expect(renderSpy).toHaveBeenCalledTimes(1);
    expect(renderSpy.mock.calls[0][0]).toBe(el);
  });

  test('attribute mutations on an unrelated element do not mount below-fold widgets', async () => {
    // Below-fold widgets that were already laid out at observe-time
    // should NOT get force-mounted just because some unrelated style
    // changed elsewhere on the page — that would defeat viewport
    // laziness.
    const el = placeholder();

    const renderSpy = vi.fn();
    bootHelper();
    win.turnstile = { render: renderSpy };
    await flushMicrotasks();

    const unrelated = doc.createElement('div');
    doc.body.appendChild(unrelated);
    await flushMicrotasks();
    unrelated.style.color = 'red';
    await flushMicrotasks();
    await new Promise((resolve) => win.setTimeout(resolve, 5));

    expect(renderSpy).not.toHaveBeenCalled();
    expect(el.dataset.turnstileRendered).toBeUndefined();
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

  test('turbo:before-stream-render wraps detail.render so the stream payload is observed', () => {
    // Turbo Stream actions (append/replace/update/morph) do NOT fire
    // turbo:render. Instead Turbo dispatches turbo:before-stream-render
    // with `event.detail.render` set to the function that does the
    // actual DOM insert. The helper must wrap that function so widgets
    // delivered via stream get picked up immediately.
    bootHelper();
    expect(ioInstances[0].observed.length).toBe(0);

    let originalCalled = false;
    const ev = new win.Event('turbo:before-stream-render', { bubbles: true });
    ev.detail = {
      render: function() {
        originalCalled = true;
        // Simulate Turbo applying the stream payload by inserting a placeholder.
        doc.body.insertAdjacentHTML('beforeend', '<div class="cf-turnstile"></div>');
      }
    };

    doc.dispatchEvent(ev);
    // The handler should have replaced detail.render with a wrapper.
    ev.detail.render();

    expect(originalCalled).toBe(true);
    const added = doc.body.lastElementChild;
    expect(ioInstances[0].observed).toContain(added);
  });

  test('turbo:before-stream-render with no event.detail does not throw', () => {
    bootHelper();

    const ev = new win.Event('turbo:before-stream-render', { bubbles: true });
    // No detail set — exercise the defensive branch.
    expect(() => doc.dispatchEvent(ev)).not.toThrow();
  });

  test('turbo:before-stream-render with non-function detail.render is left alone', () => {
    bootHelper();

    const ev = new win.Event('turbo:before-stream-render', { bubbles: true });
    ev.detail = { render: 'not a function' };
    doc.dispatchEvent(ev);

    expect(ev.detail.render).toBe('not a function');
  });
});

describe('eager mode (data-mount-mode=eager)', () => {
  test('loads api.js immediately at boot, even with no placeholder on the page', () => {
    bootHelper({ mountMode: 'eager' });

    const injected = getInjectedApiScript();
    expect(injected).toBeTruthy();
    expect(injected.src).toBe(DEFAULT_API_URL);
  });

  test('renders every placeholder on the page', () => {
    // The whole point of the mode: turning lazy mounting off must not mean
    // "nobody renders anything". This is v1.x behaviour.
    const a = placeholder();
    const b = placeholder();
    bootHelper({ mountMode: 'eager' });

    const render = resolveApiJs();

    expect(render).toHaveBeenCalledWith(a);
    expect(render).toHaveBeenCalledWith(b);
    expect(a.dataset.turnstileRendered).toBe('true');
    expect(b.dataset.turnstileRendered).toBe('true');
  });

  test('does not register an IntersectionObserver', () => {
    placeholder();
    bootHelper({ mountMode: 'eager' });

    expect(ioInstances.length).toBe(0);
  });

  test('re-renders on Turbo navigation', async () => {
    bootHelper({ mountMode: 'eager' });
    const render = resolveApiJs();

    const el = placeholder();
    fireGesture('turbo:render');
    await flushMacrotasks();

    expect(render).toHaveBeenCalledWith(el);
  });

  test('renders placeholders delivered by a Turbo Stream', async () => {
    bootHelper({ mountMode: 'eager' });
    const render = resolveApiJs();

    const ev = new win.Event('turbo:before-stream-render', { bubbles: true });
    let el;
    ev.detail = { render: function() { el = placeholder(); } };
    doc.dispatchEvent(ev);
    ev.detail.render();
    await flushMacrotasks();

    expect(render).toHaveBeenCalledWith(el);
  });

  test('renders placeholders added to the DOM later', async () => {
    bootHelper({ mountMode: 'eager' });
    const render = resolveApiJs();

    const el = placeholder();
    await flushMicrotasks();
    await flushMacrotasks();

    expect(render).toHaveBeenCalledWith(el);
  });

  test('does not register the first-gesture trigger', () => {
    placeholder({ 'data-turnstile-rendered': 'true' });
    bootHelper({ mountMode: 'eager' });

    const mountAllSpy = vi.spyOn(win.cfTurnstile, 'mountAll');
    fireGesture('pointerdown');
    fireGesture('keydown');

    expect(mountAllSpy).not.toHaveBeenCalled();
  });
});

describe('passive mode (data-mount-mode=passive)', () => {
  test('loads api.js and renders nothing at all', async () => {
    const el = placeholder();
    bootHelper({ mountMode: 'passive' });

    const injected = getInjectedApiScript();
    expect(injected).toBeTruthy();

    const render = resolveApiJs();
    await flushMacrotasks();

    expect(render).not.toHaveBeenCalled();
    expect(el.dataset.turnstileRendered).toBeUndefined();
  });

  test('registers no observers, triggers or Turbo hooks', async () => {
    placeholder();
    bootHelper({ mountMode: 'passive' });
    resolveApiJs();

    expect(ioInstances.length).toBe(0);

    // A DOM insertion, a gesture and a Turbo navigation must all be ignored:
    // the host app owns rendering in this mode.
    const el = placeholder();
    fireGesture('pointerdown');
    fireGesture('turbo:render');
    await flushMicrotasks();
    await flushMacrotasks();

    expect(win.turnstile.render).not.toHaveBeenCalled();
    expect(el.dataset.turnstileRendered).toBeUndefined();

    const ev = new win.Event('turbo:before-stream-render', { bubbles: true });
    ev.detail = { render: function() {} };
    const originalRender = ev.detail.render;
    doc.dispatchEvent(ev);
    expect(ev.detail.render).toBe(originalRender);
  });

  test('still exposes the public API so the host app can use it', () => {
    bootHelper({ mountMode: 'passive' });

    expect(typeof win.cfTurnstile.ensureLoaded).toBe('function');
    expect(typeof win.cfTurnstile.mount).toBe('function');
    expect(typeof win.cfTurnstile.mountAll).toBe('function');
    expect(win.cfTurnstile.mountMode).toBe('passive');
  });
});

describe('mount mode attribute parsing', () => {
  test.each([[null], ['bogus'], ['']])(
    'falls back to lazy when data-mount-mode is %o',
    (mode) => {
      placeholder();
      bootHelper({ mountMode: mode });

      // Lazy is the only mode that observes instead of loading api.js at boot.
      expect(win.cfTurnstile.mountMode).toBe('lazy');
      expect(ioInstances.length).toBe(1);
      expect(getInjectedApiScript()).toBeUndefined();
    }
  );
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

describe('attribute-driven reveal (native <dialog> and friends)', () => {
  // A closed <dialog> is hidden by the UA rule `dialog:not([open])
  // { display: none }`, and showModal() reveals it by setting the `open`
  // attribute — no style, class or hidden mutation to observe. This models
  // that mechanism with a stylesheet rather than a real <dialog>, so the test
  // doesn't depend on how completely JSDOM implements dialog.
  function dialogWithWidget() {
    const style = doc.createElement('style');
    style.textContent = '.dialog:not([open]) { display: none; } .dialog[open] { display: block; }';
    doc.head.appendChild(style);

    const dialog = doc.createElement('div');
    dialog.className = 'dialog';
    const el = doc.createElement('div');
    el.className = 'cf-turnstile';
    dialog.appendChild(el);
    doc.body.appendChild(dialog);

    return { dialog, el };
  }

  test('the wrapper really is hidden before the open attribute is set', () => {
    const { dialog, el } = dialogWithWidget();

    // Guards the test itself: if JSDOM stopped applying the stylesheet, the
    // assertions below would pass for the wrong reason.
    expect(win.getComputedStyle(dialog).display).toBe('none');
    expect(el).toBeTruthy();
  });

  test('setting the open attribute mounts the widget inside', async () => {
    const { dialog, el } = dialogWithWidget();
    bootHelper();

    // The one-shot gesture trigger is consumed while the dialog is still
    // closed, so there is no fallback path left to rescue this widget.
    fireGesture('pointerdown');
    expect(getInjectedApiScript()).toBeUndefined();

    dialog.setAttribute('open', '');
    await flushMicrotasks();

    expect(getInjectedApiScript()).toBeTruthy();
    const render = resolveApiJs();

    expect(render).toHaveBeenCalledTimes(1);
    expect(render.mock.calls[0][0]).toBe(el);
    expect(el.dataset.turnstileRendered).toBe('true');
  });

  test('a style-driven reveal still works (regression check)', async () => {
    const modal = doc.createElement('div');
    modal.style.display = 'none';
    const el = doc.createElement('div');
    el.className = 'cf-turnstile';
    modal.appendChild(el);
    doc.body.appendChild(modal);

    bootHelper();
    modal.style.display = 'block';
    await flushMicrotasks();

    const render = resolveApiJs();

    expect(render).toHaveBeenCalledTimes(1);
    expect(render.mock.calls[0][0]).toBe(el);
  });

  test('a toggle event mounts a revealed widget (<details> and popovers)', async () => {
    const style = doc.createElement('style');
    style.textContent = '.panel { display: none; } .panel.shown { display: block; }';
    doc.head.appendChild(style);

    const panel = doc.createElement('div');
    panel.className = 'panel';
    const el = doc.createElement('div');
    el.className = 'cf-turnstile';
    panel.appendChild(el);
    doc.body.appendChild(panel);

    bootHelper();
    expect(win.getComputedStyle(panel).display).toBe('none');

    // Popovers reveal without mutating an observable attribute, so the toggle
    // event is the only signal available. Dispatch it non-bubbling, exactly as
    // the real event behaves, to prove the listener is capture-phase.
    panel.className = 'panel shown';
    panel.dispatchEvent(new win.Event('toggle', { bubbles: false }));

    const render = resolveApiJs();
    await flushMacrotasks();

    expect(render).toHaveBeenCalledTimes(1);
    expect(render.mock.calls[0][0]).toBe(el);
  });

  test('a reveal does not force-mount below-the-fold widgets that were never hidden', async () => {
    const visible = placeholder();
    const modal = doc.createElement('div');
    modal.style.display = 'none';
    const hidden = doc.createElement('div');
    hidden.className = 'cf-turnstile';
    modal.appendChild(hidden);
    doc.body.appendChild(modal);

    bootHelper();
    modal.style.display = 'block';
    await flushMicrotasks();

    const render = resolveApiJs();

    // Only the widget that was hidden at observe time gets mounted; the
    // always-visible one stays with the IntersectionObserver.
    expect(render).toHaveBeenCalledTimes(1);
    expect(render.mock.calls[0][0]).toBe(hidden);
    expect(visible.dataset.turnstileRendered).toBeUndefined();
  });
});

describe('form-interaction trigger', () => {
  function formWithWidget() {
    const form = doc.createElement('form');
    const input = doc.createElement('input');
    const el = doc.createElement('div');
    el.className = 'cf-turnstile';
    form.appendChild(input);
    form.appendChild(el);
    doc.body.appendChild(form);
    return { form, input, el };
  }

  function fireOn(target, type) {
    target.dispatchEvent(new win.Event(type, { bubbles: true }));
  }

  test.each([['focusin'], ['pointerover']])(
    '%s inside a form mounts that form\'s widget before any submit happens',
    (eventName) => {
      const { input, el } = formWithWidget();
      bootHelper();
      expect(getInjectedApiScript()).toBeUndefined();

      fireOn(input, eventName);

      // api.js is already on its way well before the user reaches submit.
      expect(getInjectedApiScript()).toBeTruthy();
      const render = resolveApiJs();

      expect(render).toHaveBeenCalledWith(el);
      expect(el.dataset.turnstileRendered).toBe('true');
    }
  );

  test('interacting with one form leaves another form\'s widget pending', () => {
    const first = formWithWidget();
    const second = formWithWidget();
    bootHelper();

    fireOn(first.input, 'focusin');
    const render = resolveApiJs();

    expect(render).toHaveBeenCalledTimes(1);
    expect(render).toHaveBeenCalledWith(first.el);
    expect(second.el.dataset.turnstileRendered).toBeUndefined();
  });

  test('interaction outside any form mounts nothing', () => {
    formWithWidget();
    const loose = doc.createElement('div');
    doc.body.appendChild(loose);
    bootHelper();

    fireOn(loose, 'pointerover');

    expect(getInjectedApiScript()).toBeUndefined();
  });

  test('a form that arrives via Turbo is covered too', async () => {
    bootHelper();
    const { input, el } = formWithWidget();
    await flushMicrotasks();

    fireOn(input, 'focusin');
    const render = resolveApiJs();

    expect(render).toHaveBeenCalledWith(el);
  });

  test('mounts a form widget even when the first-gesture trigger already fired', () => {
    // The gesture trigger is one-shot; the form listeners are not, so a form
    // shown after that first click is still covered.
    fireGesture('pointerdown');
    const { input, el } = formWithWidget();
    bootHelper();
    fireGesture('pointerdown');

    fireOn(input, 'focusin');
    const render = resolveApiJs();

    expect(render).toHaveBeenCalledWith(el);
  });

  test('still fires for a form that arrives after every earlier widget mounted', async () => {
    // The form listener short-circuits on an internal pending count so that
    // pointerover doesn't walk the DOM forever once everything has mounted.
    // That count has to climb back up when a new placeholder shows up, or a
    // Turbo-delivered form would silently lose the trigger.
    const first = placeholder();
    bootHelper();
    win.cfTurnstile.mountAll();
    const render = resolveApiJs();

    expect(render).toHaveBeenCalledWith(first);
    expect(render).toHaveBeenCalledTimes(1);

    // Interact while the count is zero. A listener that unsubscribed itself
    // here instead of short-circuiting would pass every other test in this
    // block and still break the Turbo case below.
    fireOn(doc.body, 'focusin');
    fireOn(doc.body, 'pointerover');

    const { input, el } = formWithWidget();
    await flushMicrotasks();

    fireOn(input, 'focusin');
    await flushMacrotasks();

    expect(render).toHaveBeenCalledWith(el);
  });
});

describe('space reservation (CLS)', () => {
  test('applies data-reserve-height as an inline min-height at observe time', () => {
    const el = placeholder({ 'data-reserve-height': '65' });
    bootHelper();

    expect(el.style.minHeight).toBe('65px');
  });

  test('honours a compact widget\'s taller reservation', () => {
    const el = placeholder({ 'data-reserve-height': '120' });
    bootHelper();

    expect(el.style.minHeight).toBe('120px');
  });

  test('leaves elements without the attribute untouched', () => {
    const el = placeholder();
    bootHelper();

    expect(el.style.minHeight).toBe('');
  });

  test('releases the reservation once the widget has rendered', () => {
    const el = placeholder({ 'data-reserve-height': '65' });
    bootHelper();
    expect(el.style.minHeight).toBe('65px');

    ioInstances[0].trigger(el);
    resolveApiJs();

    // Cloudflare's iframe sizes the element from here on. Releasing the
    // reservation also means an invisible sitekey that forgot to set
    // config.reserve_space = false doesn't keep a permanent gap.
    expect(el.dataset.turnstileRendered).toBe('true');
    expect(el.style.minHeight).toBe('');
  });

  test('never overrides an author-supplied min-height', () => {
    const el = placeholder({ 'data-reserve-height': '65', style: 'min-height: 300px' });
    bootHelper();

    expect(el.style.minHeight).toBe('300px');

    ioInstances[0].trigger(el);
    resolveApiJs();

    // Not ours to clear, either.
    expect(el.style.minHeight).toBe('300px');
  });

  test('preserves other inline styles when releasing the reservation', () => {
    const el = placeholder({ 'data-reserve-height': '65', style: 'width: 300px' });
    bootHelper();
    expect(el.style.minHeight).toBe('65px');

    ioInstances[0].trigger(el);
    resolveApiJs();

    expect(el.style.minHeight).toBe('');
    expect(el.style.width).toBe('300px');
  });

  test('reserves space for placeholders added after boot', async () => {
    bootHelper();
    const el = placeholder({ 'data-reserve-height': '65' });
    await flushMicrotasks();

    expect(el.style.minHeight).toBe('65px');
  });

  test('does not reserve in eager mode, where there is nothing to defer', () => {
    const el = placeholder({ 'data-reserve-height': '65' });
    bootHelper({ mountMode: 'eager' });

    expect(el.style.minHeight).toBe('');
  });
});
