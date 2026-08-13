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
  - the user focusing or hovering any field in the same `<form>` as the
    widget, so the token is already on its way before they can submit,
  - the widget being revealed — a native `<dialog>` opening, a `<details>`
    expanding, a popover showing, or a `display: none` ancestor becoming
    visible,
  - the user touching, clicking, or pressing a key anywhere on the page
    (first-gesture listener), and
  - host-app code calling the new `cfTurnstile.mount(el)` /
    `cfTurnstile.mountAll()` JS API.
- **Three explicit mounting modes**, resolved server-side and published to
  the helper script as `data-mount-mode`:
  - `lazy` (default) — the gem renders widgets, deferred as above,
  - `eager` (`config.lazy_mount = false`) — the gem renders every widget as
    soon as `api.js` is ready and keeps following Turbo navigations, Turbo
    Stream renders, and DOM mutations. This is the v1.x behaviour.
  - `passive` (`config.manual_render = true`) — the gem loads `api.js` and
    renders nothing; the host app calls `turnstile.render()` itself.
- **`window.cfTurnstile` public JS API**: `ensureLoaded(cb)`, `mount(el)`,
  `mountAll()`, and `mountMode` for explicit control over loading and
  rendering.
- **`config.lazy_mount`** (default `true`): toggle the lazy-mount machinery.
- **`config.manual_render`** (default `false`): hand rendering to the host
  app entirely. Takes precedence over `lazy_mount`.
- **`config.reserve_space`** (default `true`) and a per-tag
  `reserve_space:` option: opt out of the CLS reservation, e.g. for a
  sitekey configured as invisible in the Cloudflare dashboard.
- **CLS prevention** (size-aware): in lazy mode the placeholder carries a
  `data-reserve-height` matching what Cloudflare's iframe will actually
  render at — `65 px` for `normal` and `flexible` widgets, `120 px` for
  `compact` ones. The helper applies it as a `min-height` through the CSSOM
  when the widget starts being observed and releases it once the widget
  mounts. Nothing is emitted into a server-rendered `style` attribute, so no
  `style-src-attr 'unsafe-inline'` CSP relaxation is needed. An
  author-supplied `min-height` is never overridden.
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
- **Boot-time warning** when `config.lazy_mount` is on but the resolved
  `api.js` URL doesn't carry `render=explicit` — whether because
  `config.render = 'auto'` or because a custom `config.script_url` omits
  the parameter. The gem names the offending URL and falls back to eager
  mounting.
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
- The helper script tag now carries `data-mount-mode` (`lazy` / `eager` /
  `passive`) so the helper JS can pick the right mode at runtime.

### Migration notes

- Most apps need no changes — the lazy mode is on by default and works out
  of the box.
- If you were on v1.x with `config.render = 'explicit'` and called
  `turnstile.render(...)` from your own JavaScript, set
  `config.manual_render = true`. The gem loads `api.js` for you and renders
  nothing, so your code keeps working unchanged. Otherwise, drop your manual
  `render` calls and let the gem drive.
- The README has a full
  [v1.x → v2.0 upgrade guide](README.md#upgrading-from-v1x-to-v20)
  including a decision matrix and edge cases.
