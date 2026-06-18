# Changelog

All notable changes to this gem are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0]

### Added

- **Lazy mounting**: Cloudflare's `api.js` and the widget itself are now
  deferred until the user actually needs them. Triggers include:
  - the widget scrolling into (or near) the viewport
    (`IntersectionObserver`, with a generous `rootMargin: '200px'`),
  - the user touching, clicking, or pressing a key anywhere on the page
    (first-gesture listener), and
  - host-app code calling the new `cfTurnstile.mount(el)` /
    `cfTurnstile.mountAll()` JS API.
- **`window.cfTurnstile` public JS API**: `ensureLoaded(cb)`, `mount(el)`,
  and `mountAll()` for explicit control over loading and rendering.
- **`config.lazy_mount`** (default `true`): toggle the lazy-mount machinery.
- **CLS prevention** (size-aware): the placeholder div carries a
  `min-height` reservation that matches what Cloudflare's iframe will
  actually render at — `65 px` for `normal` and `flexible` widgets,
  `120 px` for `compact` widgets, and nothing for `invisible` widgets.
  Also skipped automatically when the caller supplies their own `style:`
  or `class: nil`.
- **Modal-aware first-gesture trigger**: clicking or typing anywhere on
  the page no longer mounts widgets that are inside a `display: none`
  modal/dialog/tab. Those widgets stay pending until the container
  actually becomes visible, at which point the IntersectionObserver
  mounts them. The public `cfTurnstile.mountAll()` is the deliberate
  escape hatch that bypasses this filter.
- **System tests for hidden-modal widgets** (`modal_demo_test.rb`):
  verifies the widget doesn't render before the modal opens, that an
  unrelated gesture (click outside / keypress) doesn't force-render it,
  and that `cfTurnstile.mountAll()` still does.
- **Boot-time upgrade warnings** to flag the v1.x-explicit upgrade
  fingerprint and the contradictory `(lazy_mount=true, render='auto')`
  combination.
- **`post_install_message`** in the gemspec to surface upgrade notes.
- New system test (`lazy_mount_test.rb`) and `mount_turnstile_widgets!`
  helper covering the new behaviour end-to-end.
- New consumer-facing integration test (`test/integration/turnstile_helper_test.rb`)
  asserting the rendered helper-script attributes, CLS placeholder reservation,
  and the server-side verification round-trip.
- New JavaScript unit-test suite ([vitest](https://vitest.dev) + JSDOM) for
  `cloudflare_turnstile_helper.js`, covering every branch including the failure
  modes that aren't reachable from a real browser (api.js `onerror`, missing
  `data-script-url`, `turnstile.render` throwing, callback isolation, race-
  protected double-`mount`, IO-unavailable fallback, init-guard idempotency,
  eager mode wiring, and the gesture / Turbo / MutationObserver paths).

### Changed

- **`config.render` now defaults to `'explicit'`** so the gem can lazy-mount
  safely without racing Cloudflare's own auto-render observer. v1.x users
  who never touched `config.render` get the new behaviour transparently;
  see the v1.x → v2.0 upgrade guide in the README for details.
- The internal "rendered" marker on placeholder elements moved from
  `data-cf-rendered` (which looked like a Cloudflare-owned attribute) to
  `data-turnstile-rendered`.
- The widget's HTML data attributes for the helper script tag now include
  `data-lazy-mount` so the helper JS can pick the right mode at runtime.

### Migration notes

- Most apps need no changes — the lazy mode is on by default and works out
  of the box.
- If you were on v1.x with `config.render = 'explicit'` and called
  `turnstile.render(...)` from your own JavaScript, set
  `config.lazy_mount = false` to keep the eager-load v1 behaviour while
  retaining your manual rendering. Otherwise, drop your manual `render`
  calls and let the gem drive.
- The README has a full
  [v1.x → v2.0 upgrade guide](README.md#upgrading-from-v1x-to-v20)
  including a decision matrix and edge cases.
