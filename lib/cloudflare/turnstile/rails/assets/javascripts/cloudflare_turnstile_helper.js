/*
 * cloudflare_turnstile_helper.js
 *
 * Written deliberately in ES5 syntax (var, function declarations, no
 * arrow functions, no let/const, no template literals). Sprockets
 * serves this file to browsers as-is — there is no Babel, no bundler,
 * no transpilation step. ES5 keeps us compatible with every browser
 * that can actually run Cloudflare Turnstile (Chrome 87+, Firefox 78+,
 * Safari 14+ per Cloudflare's own support matrix).
 *
 * The lint config enforces this: eslint.config.js sets ecmaVersion: 5,
 * so any ES6+ syntax slipped in here will be caught by `bin/lint`
 * (which the CI pipeline runs) before it can reach a release.
 *
 * Browser-API support is handled at runtime instead of at parse time:
 *   - IntersectionObserver  -> falls back to mountAll() if missing
 *   - MutationObserver      -> falls back to a one-shot dispatch only
 *   - turnstile.render      -> Cloudflare's own api.js is the source of
 *                              truth for browser support; if a user's
 *                              browser can't run Turnstile, Cloudflare
 *                              surfaces that, not us.
 */
(function() {
  'use strict';

  /*
   * Module-level state captured once when this script first executes.
   *
   * helperScript - the <script> tag that loaded this helper. Read once because
   *                document.currentScript is null in async callbacks.
   * apiUrl       - Cloudflare api.js URL (defaults to ?render=explicit).
   * lazyMount    - false when config.lazy_mount = false in the host app.
   * nonce        - CSP nonce, copied to the dynamically injected api.js tag.
   * loadState    - 'idle' | 'loading' | 'ready'.
   * loadCallbacks- queue of fns waiting for api.js to be ready.
   * observer     - shared IntersectionObserver, created lazily.
   */
  var helperScript = document.currentScript;
  var apiUrl = helperScript ? helperScript.getAttribute('data-script-url') : null;
  var lazyMount = helperScript ? helperScript.getAttribute('data-lazy-mount') !== 'false' : true;
  var nonce = helperScript ? helperScript.nonce : null;
  var loadState = 'idle';
  var loadCallbacks = [];
  var observer = null;

  /**
   * Drains the queue of callbacks that were waiting for Cloudflare's api.js
   * to load. Each callback runs in its own try/catch so a misbehaving
   * consumer-supplied callback can't take out the rest. Errors are
   * console.warn'd but never re-thrown.
   *
   * Called exactly once per successful api.js load (from `<script>.onload`).
   *
   * @returns {void}
   */
  function flushCallbacks() {
    var cbs, i;

    cbs = loadCallbacks;
    loadCallbacks = [];

    for (i = 0; i < cbs.length; i++) {
      try {
        cbs[i]();
      }
      catch (e) {
        // eslint-disable-next-line no-console
        console.warn('cloudflare-turnstile-rails: api.js callback failed', e);
      }
    }
  }

  /**
   * Inject Cloudflare's api.js into <head>, once per page-load lifecycle.
   *
   * No-ops if a load is already in progress or has completed (`loadState`
   * !== 'idle'). On `<script>` `error` we reset back to 'idle' so a
   * subsequent ensureLoaded() can transparently retry. The CSP nonce of the
   * helper script tag — if any — is copied onto the injected tag so strict
   * Content-Security-Policy environments stay happy.
   *
   * Does not throw. Failures are logged to console.warn.
   *
   * @returns {void}
   */
  function injectApiScript() {
    var script;

    if (loadState !== 'idle') {
      return;
    }

    if (!apiUrl) {
      // eslint-disable-next-line no-console
      console.warn('cloudflare-turnstile-rails: missing data-script-url on helper script tag');
      return;
    }

    loadState = 'loading';
    script = document.createElement('script');
    script.src = apiUrl;
    script.async = true;
    script.defer = true;

    if (nonce) {
      script.nonce = nonce;
    }

    script.onload = function() {
      loadState = 'ready';
      flushCallbacks();
    };

    script.onerror = function() {
      loadState = 'idle';
      // eslint-disable-next-line no-console
      console.warn('cloudflare-turnstile-rails: failed to load Cloudflare Turnstile api.js');
    };

    document.head.appendChild(script);
  }

  /**
   * Public API.
   *
   * Run `cb` after Cloudflare's api.js is loaded and `window.turnstile` is
   * available. If api.js is already loaded, the callback is invoked
   * asynchronously via setTimeout(0) so callers can rely on consistent
   * "after this tick" ordering. Otherwise the callback is queued and api.js
   * injection is kicked off (idempotent).
   *
   * Non-function arguments are silently ignored — that's a deliberate design
   * choice so consumer code can pass `undefined` without guarding.
   *
   * Errors thrown inside `cb` are caught by flushCallbacks() and logged.
   *
   * @param {Function} cb - invoked once api.js is ready.
   * @returns {void}
   */
  function ensureLoaded(cb) {
    if (typeof cb !== 'function') {
      return;
    }

    if (typeof window.turnstile !== 'undefined') {
      setTimeout(cb, 0);
      return;
    }

    loadCallbacks.push(cb);

    if (loadState === 'idle') {
      injectApiScript();
    }
  }

  /**
   * True when this placeholder has already been turned into a Turnstile
   * widget. Two signals are checked:
   *
   *   1. `data-turnstile-rendered="true"` — the marker we set ourselves once
   *      `turnstile.render()` succeeds.
   *   2. `el.childElementCount > 0` — Cloudflare's auto-render mode
   *      (`render=auto`) drops the iframe in directly without going through
   *      our mount() path, so the marker is never set. The child-count check
   *      catches that case and prevents `cfTurnstile.mount()` from
   *      double-rendering it.
   *
   * @param {Element} el
   * @returns {boolean}
   */
  function isAlreadyMounted(el) {
    return el.dataset.turnstileRendered === 'true' || el.childElementCount > 0;
  }

  /**
   * Public API.
   *
   * Render `el` as a Turnstile widget once api.js is available. Safe to
   * call multiple times on the same element — the second call is a no-op
   * because the first call has either set `data-turnstile-rendered` or
   * already populated the element with the iframe.
   *
   * Stops observing `el` via the shared IntersectionObserver so an
   * intersection event can't queue a redundant render.
   *
   * Errors from `window.turnstile.render` are caught, logged, and not
   * re-thrown. The `data-turnstile-rendered` marker is only set on success
   * so that a future mount() call can still retry.
   *
   * @param {Element} el - the `.cf-turnstile` placeholder div.
   * @returns {void}
   */
  function mount(el) {
    if (!el || isAlreadyMounted(el)) {
      return;
    }

    if (observer) {
      observer.unobserve(el);
    }

    ensureLoaded(function() {
      if (typeof window.turnstile === 'undefined') {
        return;
      }

      if (isAlreadyMounted(el)) {
        return;
      }

      try {
        window.turnstile.render(el);
        el.dataset.turnstileRendered = 'true';
      }
      catch (e) {
        // eslint-disable-next-line no-console
        console.warn('cloudflare-turnstile-rails: turnstile.render failed', e);
      }
    });
  }

  /**
   * Walk an element's ancestor chain and decide whether it currently
   * occupies a layout box — i.e. neither it nor any ancestor is
   * `display: none`.
   *
   * Used in two places:
   *
   *   1. As an extra filter in handleIntersections(), because headless
   *      Chrome happily reports `isIntersecting: true` for targets
   *      nested under a `display: none` ancestor (their (0,0,0,0) box
   *      overlaps our rootMargin-expanded root). We don't want to
   *      render those — they're invisible to the user.
   *   2. By the first-gesture trigger via mountAllVisible() so that
   *      clicking somewhere on the page doesn't force-mount widgets
   *      that are stashed inside a closed modal / dialog / collapsed
   *      panel.
   *
   * `visibility:hidden` and `opacity:0` are intentionally NOT treated as
   * hidden — IntersectionObserver fires for both, so we should too.
   *
   * Defensive: if getComputedStyle ever throws (detached node, exotic
   * environment), we fall back to "yes, mount it".
   *
   * @param {Element} el
   * @returns {boolean}
   */
  function isLaidOut(el) {
    var node, view, display;

    view = el.ownerDocument && el.ownerDocument.defaultView;

    if (!view || typeof view.getComputedStyle !== 'function') {
      return true;
    }

    node = el;

    while (node && node.nodeType === 1) {
      try {
        display = view.getComputedStyle(node).display;
      }
      // eslint-disable-next-line no-unused-vars
      catch (e) {
        return true;
      }

      if (display === 'none') {
        return false;
      }

      node = node.parentNode;
    }

    return true;
  }

  /**
   * IntersectionObserver callback. Mounts every entry that crossed into the
   * viewport's expanded rootMargin. Non-intersecting entries (the element
   * leaving the viewport) are intentionally ignored — once a widget is
   * mounted, it stays mounted.
   *
   * `isLaidOut()` filters out entries whose target sits under a
   * `display: none` ancestor; those widgets stay observed and will
   * mount the moment the layout makes them visible (e.g. when a
   * modal opens).
   *
   * @param {IntersectionObserverEntry[]} entries
   * @returns {void}
   */
  function handleIntersections(entries) {
    var i, entry;

    for (i = 0; i < entries.length; i++) {
      entry = entries[i];

      if (entry.isIntersecting && isLaidOut(entry.target)) {
        mount(entry.target);
      }
    }
  }

  /**
   * Lazily build (and cache) the page's single shared IntersectionObserver.
   *
   * Returns null when the browser doesn't support IntersectionObserver at
   * all — callers must fall back to mountAll() in that case.
   *
   * The 200px rootMargin gives api.js a head start on loading just before
   * the widget actually scrolls into view, so the user rarely sees a blank
   * placeholder.
   *
   * @returns {?IntersectionObserver}
   */
  function getObserver() {
    if (observer) {
      return observer;
    }

    if (!('IntersectionObserver' in window)) {
      return null;
    }

    observer = new IntersectionObserver(handleIntersections, {rootMargin: '200px'});
    return observer;
  }

  /**
   * NodeList of every `.cf-turnstile` placeholder on the page that hasn't
   * been rendered yet. The selector excludes any element already carrying
   * the `data-turnstile-rendered` marker.
   *
   * @returns {NodeListOf<Element>}
   */
  function pendingPlaceholders() {
    return document.querySelectorAll('.cf-turnstile:not([data-turnstile-rendered])');
  }

  /**
   * Public API.
   *
   * Force-mount every pending placeholder on the page right now,
   * regardless of viewport position or visibility. Use this before
   * programmatically submitting a form whose Turnstile widget hasn't had
   * a chance to render yet, or in tests.
   *
   * Each individual mount goes through mount(), so already-rendered
   * widgets are skipped and api.js loads at most once.
   *
   * @returns {void}
   */
  function mountAll() {
    var els, i;

    els = pendingPlaceholders();

    for (i = 0; i < els.length; i++) {
      mount(els[i]);
    }
  }

  /**
   * Mount every pending placeholder that's currently part of the rendered
   * layout (see isLaidOut). Internal — used by the first-gesture trigger.
   *
   * Hidden-in-modal widgets are deliberately skipped so opening a closed
   * modal isn't the side-effect of any random click on the page. They'll
   * still get rendered the moment they become visible via the
   * IntersectionObserver path.
   *
   * @returns {void}
   */
  function mountAllVisible() {
    var els, i, el;

    els = pendingPlaceholders();

    for (i = 0; i < els.length; i++) {
      el = els[i];

      if (isLaidOut(el)) {
        mount(el);
      }
    }
  }

  /**
   * Hand a single placeholder to the IntersectionObserver (or mount it
   * immediately if IO isn't available). Internal — used by both the
   * initial sweep (observePending) and the MutationObserver path when a
   * new `.cf-turnstile` shows up in the DOM after boot.
   *
   * Records (on the element itself) whether the placeholder was hidden
   * — i.e. inside a `display: none` ancestor — at the moment we started
   * observing it. mountIfRevealed() consults this flag to decide whether
   * a later attribute mutation might have just made it visible. Storing
   * it as a JavaScript property (not a `data-` attribute) keeps it from
   * triggering our own MutationObserver.
   *
   * @param {Element} el
   * @returns {void}
   */
  function observeOne(el) {
    var io;

    if (isAlreadyMounted(el)) {
      return;
    }

    io = getObserver();

    if (io) {
      el._cfWasHidden = !isLaidOut(el);
      io.observe(el);
    }
    else {
      mount(el);
    }
  }

  /**
   * Hand every currently-pending placeholder to the IntersectionObserver
   * so it can mount each one when it scrolls into view. If IO isn't
   * available in this browser we fall back to mountAll() — the lazy
   * trigger silently degrades to "load it all up front", which is
   * functionally identical to v1 behaviour.
   *
   * @returns {void}
   */
  function observePending() {
    var els, i;

    if (!getObserver()) {
      // No IntersectionObserver support — fall back to mounting everything now.
      mountAll();
      return;
    }

    els = pendingPlaceholders();

    for (i = 0; i < els.length; i++) {
      observeOne(els[i]);
    }
  }

  /**
   * The single "do whatever the current mode says to do for new
   * placeholders" entry point. In lazy mode that means observePending();
   * in eager mode it means mountAll(). Bound to Turbo/Turbolinks events
   * so re-rendered pages get re-scanned.
   *
   * @returns {void}
   */
  function dispatch() {
    if (lazyMount) {
      observePending();
    }
    else {
      mountAll();
    }
  }

  /**
   * Wire up the first-gesture trigger.
   *
   * Listens (in capture phase, so we beat consumer click handlers) for
   * `pointerdown` and `keydown` anywhere on the document. The first time
   * any of them fires we mount every visible pending widget and then tear
   * the listeners down — this is a one-shot signal, not a per-event one.
   *
   * Hidden-in-modal widgets are skipped via mountAllVisible(); they wait
   * for the IntersectionObserver path instead.
   *
   * @returns {void}
   */
  function setupGestureListeners() {
    var events, i, gestureHandled;

    events = ['pointerdown', 'keydown'];
    gestureHandled = false;

    function onGesture() {
      var j;

      if (gestureHandled) {
        return;
      }

      gestureHandled = true;

      for (j = 0; j < events.length; j++) {
        document.removeEventListener(events[j], onGesture, true);
      }

      mountAllVisible();
    }

    for (i = 0; i < events.length; i++) {
      document.addEventListener(events[i], onGesture, true);
    }
  }

  /**
   * Apply observeOne() to one freshly-added DOM node and any
   * `.cf-turnstile` descendants of it. Called once per added node by the
   * MutationObserver callback.
   *
   * @param {Node} node
   * @returns {void}
   */
  function handleAddedNode(node) {
    var nested, k;

    if (node.classList && node.classList.contains('cf-turnstile')) {
      observeOne(node);
    }

    if (node.querySelectorAll) {
      nested = node.querySelectorAll('.cf-turnstile');

      for (k = 0; k < nested.length; k++) {
        observeOne(nested[k]);
      }
    }
  }

  /**
   * After an attribute mutation somewhere in the DOM (style / class /
   * hidden), check whether any placeholder that was hidden when we
   * first observed it has just been revealed — typically a modal
   * opening — and mount it directly.
   *
   * We deliberately do NOT lean on IntersectionObserver to fire again
   * here: Firefox doesn't re-fire IO when an element transitions out
   * of `display: none`, and Chrome can briefly report a stale
   * isIntersecting=true during rapid unobserve/observe cycles. A
   * direct mount() is browser-independent.
   *
   * Targeting only placeholders that were originally hidden
   * (`_cfWasHidden`) keeps below-the-fold widgets — which are
   * laid out from the start — from being force-mounted by unrelated
   * page mutations. Their viewport-laziness still flows through IO.
   *
   * @returns {void}
   */
  function mountIfRevealed() {
    var els, i, el;

    els = pendingPlaceholders();

    if (els.length === 0) {
      return;
    }

    for (i = 0; i < els.length; i++) {
      el = els[i];

      if (el._cfWasHidden && isLaidOut(el)) {
        mount(el);
      }
    }
  }

  /**
   * MutationObserver callback. Two responsibilities:
   *
   *   1. childList: forward newly-inserted Elements to handleAddedNode()
   *      so freshly-rendered widgets get observed.
   *   2. attributes (style/class/hidden): a previously-hidden
   *      ancestor might have just become visible (e.g. a modal opening).
   *      Re-check placeholders that were hidden at observe-time and
   *      mount any that are now laid out.
   *
   * Text and comment nodes are ignored.
   *
   * @param {MutationRecord[]} mutations
   * @returns {void}
   */
  function handleMutations(mutations) {
    var i, j, mutation, added, node, sawAttributeChange;

    sawAttributeChange = false;

    for (i = 0; i < mutations.length; i++) {
      mutation = mutations[i];

      if (mutation.type === 'attributes') {
        sawAttributeChange = true;
      }
      else {
        added = mutation.addedNodes;

        for (j = 0; j < added.length; j++) {
          node = added[j];

          if (node.nodeType === 1) {
            handleAddedNode(node);
          }
        }
      }
    }

    if (sawAttributeChange) {
      mountIfRevealed();
    }
  }

  /**
   * Wire up the MutationObserver. This is what catches non-Turbo dynamic
   * insertions: Bootstrap modals, jQuery `.html()`, Stimulus controllers,
   * fetch+innerHTML, etc. Without it, lazy mounting wouldn't work for
   * widgets that are added to the page after initial paint.
   *
   * The attribute filter (style / class / hidden) lets us also notice
   * when a previously-hidden ancestor becomes visible — important
   * because Firefox does not re-fire IntersectionObserver when an
   * element transitions out of `display: none` (see
   * mountIfRevealed).
   *
   * Silently no-ops in environments without MutationObserver (very old
   * browsers / non-DOM hosts).
   *
   * @returns {void}
   */
  function setupMutationObserver() {
    var target, mo;

    if (!('MutationObserver' in window)) {
      return;
    }

    target = document.body || document.documentElement;

    if (!target) {
      return;
    }

    mo = new MutationObserver(handleMutations);
    mo.observe(target, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['style', 'class', 'hidden']
    });
  }

  /**
   * Subscribe `dispatch` to Turbo and Turbolinks navigation events so a
   * re-rendered page gets its widgets re-discovered. MutationObserver
   * already catches most of these mutations, but the explicit hooks are
   * cheap belt-and-suspenders for full-body replacements where MO timing
   * could lag.
   *
   * Only registered in lazy mode. In eager mode either Cloudflare's own
   * api.js (render=auto) or the consumer's manual `turnstile.render()`
   * code is in charge across navigations.
   *
   * @returns {void}
   */
  function setupTurboHooks() {
    document.addEventListener('turbo:render', dispatch);
    document.addEventListener('turbo:frame-load', dispatch);
    document.addEventListener('turbolinks:load', dispatch);
  }

  /**
   * One-time boot for the helper.
   *
   * `_turnstileHelperLoaded` on `window` guards against double-execution
   * — Turbolinks can re-execute cached `<script>` tags on restored pages,
   * and we don't want N copies of every observer or listener.
   *
   * On first run we publish the public API on `window.cfTurnstile`, then
   * either:
   *
   *   - lazy mode: install observers + the first-gesture trigger + Turbo
   *     hooks. api.js is NOT loaded yet — it'll load when something
   *     actually needs it.
   *   - eager mode: load api.js immediately and stay completely out of
   *     the way. Either Cloudflare's api.js (render='auto') or the
   *     consumer's manual `turnstile.render()` (render='explicit', the
   *     v1-explicit upgrade path) is now responsible for rendering,
   *     including across Turbo navigations, so we install no observers,
   *     listeners, or hooks.
   *
   * On subsequent runs we just re-dispatch so newly-added placeholders
   * get picked up.
   *
   * @returns {void}
   */
  function init() {
    if (window._turnstileHelperLoaded) {
      dispatch();
      return;
    }

    window._turnstileHelperLoaded = true;
    window.cfTurnstile = {
      ensureLoaded: ensureLoaded,
      mount: mount,
      mountAll: mountAll
    };

    if (lazyMount) {
      observePending();
      setupGestureListeners();
      setupMutationObserver();
      setupTurboHooks();
    }
    else {
      injectApiScript();
    }
  }

  init();
}());
