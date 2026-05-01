# Cloudflare Turnstile Rails

[![Gem Version](https://img.shields.io/gem/v/cloudflare-turnstile-rails.svg)](https://rubygems.org/gems/cloudflare-turnstile-rails)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Lint Status](https://github.com/vkononov/cloudflare-turnstile-rails/actions/workflows/lint.yml/badge.svg)](https://github.com/vkononov/cloudflare-turnstile-rails/actions/workflows/lint.yml)
[![Test Status](https://github.com/vkononov/cloudflare-turnstile-rails/actions/workflows/test.yml/badge.svg)](https://github.com/vkononov/cloudflare-turnstile-rails/actions/workflows/test.yml)

Cloudflare Turnstile gem for Ruby on Rails with built-in Turbo and Turbolinks support and CSP compliance.

Supports `Rails >= 5.0` with `Ruby >= 2.6.0`.

[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/yellow_img.png)](https://www.buymeacoffee.com/vkononov)

## Features

* **One‑line integration**: `<%= cloudflare_turnstile_tag %>` in views, `valid_turnstile?(model:)` in controllers — no extra wiring.
* **Lazy mounting (v2.0+)**: Cloudflare's `api.js` and the widget itself are deferred until the user scrolls to it, touches the page, or your code asks for them — no wasted bandwidth on widgets below the fold or in hidden modals.
* **Turbo & Turbo Streams aware**: Automatically re‑initializes widgets on `turbo:load`, `turbo:before-stream-render`, and DOM mutations.
* **Legacy Turbolinks support**: Includes a helper for Turbolinks to handle remote form submissions with validation errors.
* **CSP nonce support**: Honours Rails' `content_security_policy_nonce` for secure inline scripts.
* **Rails Engine & Asset pipeline**: Ships a precompiled JS helper via Railtie — no manual asset setup.
* **Lightweight**: Pure Ruby/Rails with only `net/http` and `json` dependencies.


## Table of Contents

- [Getting Started](#getting-started)
  - [Installation](#installation)
  - [Frontend Integration](#frontend-integration)
  - [Lazy Mounting](#lazy-mounting)
  - [Backend Validation](#backend-validation)
  - [CSP Nonce Support](#csp-nonce-support)
  - [Turbo & Turbo Streams Support](#turbo--turbo-streams-support)
  - [Turbolinks Support](#turbolinks-support)
- [Internationalization (I18n)](#internationalization-i18n)
  - [Overriding Translations](#overriding-translations)
  - [Locale Fallbacks](#locale-fallbacks)
  - [Adding New Languages](#adding-new-languages)
  - [Available Translation Keys](#available-translation-keys)
- [Automated Testing of Your Integration](#automated-testing-of-your-integration)
- [Upgrade Guide](#upgrade-guide)
  - [Upgrading from v1.x to v2.0](#upgrading-from-v1x-to-v20)
- [Troubleshooting](#troubleshooting)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)


## Getting Started

### Installation

* Add the gem to your Gemfile and bundle:

  ```ruby
  gem 'cloudflare-turnstile-rails'
  ```

* Run the following command to install the gem:

  ```bash
  bundle install
  ```

* Generate the default initializer:

  ```bash
  bin/rails generate cloudflare_turnstile:install
  ```

* Configure your **Site Key** and **Secret Key** in `config/initializers/cloudflare_turnstile.rb`:

  ```ruby
  Cloudflare::Turnstile::Rails.configure do |config|
    # Set your Cloudflare Turnstile Site Key and Secret Key.
    config.site_key   = ENV.fetch('CLOUDFLARE_TURNSTILE_SITE_KEY', nil)
    config.secret_key = ENV.fetch('CLOUDFLARE_TURNSTILE_SECRET_KEY', nil)
  end
  ```

  If you don't have Cloudflare Turnstile keys yet, you can use dummy keys for development and testing. See the [Automated Testing of Your Integration](#automated-testing-of-your-integration) section for more details.

  > For production use, you can obtain your keys from the Cloudflare dashboard. Follow the instructions in the [Cloudflare Turnstile documentation](https://developers.cloudflare.com/turnstile/get-started/) to create a new site key and secret key.

### Frontend Integration

* Include the widget in your views or forms:

   ```erb
   <%= cloudflare_turnstile_tag %>
   ```

  That's it! Though it is recommended to match your `theme` and `language` to your app's design and locale:

   ```erb
   <%= cloudflare_turnstile_tag data: { theme: 'light', language: 'en' } %>
   ```

* For all available **data-**\* options (e.g., `action`, `cdata`, `theme`, etc.), refer to the official Cloudflare client-side rendering docs:
  [https://developers.cloudflare.com/turnstile/get-started/client-side-rendering/#configuration-options](https://developers.cloudflare.com/turnstile/get-started/client-side-rendering/#configuration-options)
* **Supported locales** for the widget UI can be found here:
  [https://developers.cloudflare.com/turnstile/reference/supported-languages/](https://developers.cloudflare.com/turnstile/reference/supported-languages/)

### Lazy Mounting

Starting in **v2.0**, the gem defers loading Cloudflare's `api.js` and rendering the widget until one of the following happens:

* the widget scrolls into (or near) the viewport (`IntersectionObserver`),
* the user touches, clicks, or types anywhere on the page (first-gesture trigger), or
* your own JavaScript calls `cfTurnstile.mount(el)` / `cfTurnstile.mountAll()`.

This means widgets in modals, accordions, or below the fold no longer trigger a network round-trip on every page load.

#### Configuration

Lazy mounting is on by default. The two related knobs in `config/initializers/cloudflare_turnstile.rb` are:

```ruby
Cloudflare::Turnstile::Rails.configure do |config|
  config.lazy_mount = true # default — defer loading until needed
  config.render = 'explicit' # default — required for lazy_mount to take effect
end
```

`config.render` defaults to `'explicit'` so that Cloudflare's auto-render observer doesn't race the gem's lazy triggers. If you set `config.render = 'auto'` while leaving `config.lazy_mount = true`, the gem logs a warning and degrades to eager loading (Cloudflare will render every widget the moment `api.js` arrives).

#### Public JavaScript API

The helper exposes a small API on `window.cfTurnstile`:

| Method                       | Description                                                                                                                                                |
|------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `cfTurnstile.ensureLoaded(cb)` | Loads `api.js` if it isn't already loaded, then invokes `cb()`. Use this if you want to call `turnstile.render(...)` yourself but still benefit from lazy loading. |
| `cfTurnstile.mount(el)`      | Renders a single placeholder `<div class="cf-turnstile">` element. Idempotent — already-rendered widgets are skipped.                                       |
| `cfTurnstile.mountAll()`     | Renders every pending placeholder on the page. Useful when you reveal a hidden modal or want to force-render in tests.                                      |

```javascript
// Programmatically reveal a modal containing a Turnstile widget. You don't
// usually need to call mountAll() yourself — the IntersectionObserver picks
// up newly-visible widgets automatically — but mountAll() is the explicit
// escape hatch when you want to pre-warm a widget right before it appears.
modalEl.classList.add('open');
window.cfTurnstile.mountAll();
```

#### Hidden modals & dialogs

The first-gesture trigger (`pointerdown` / `keydown`) deliberately **skips
widgets that are inside a `display: none` ancestor** — closed modals,
hidden tabs, collapsed accordions, etc. Those widgets stay pending until
the container becomes visible, at which point the IntersectionObserver
mounts them. This means a random click anywhere on the page won't pre-warm
a widget the user can't see (which would defeat the purpose of lazy
mounting it).

If you need to override that — e.g. you're about to programmatically open
a modal and want the widget pre-rendered — call `cfTurnstile.mountAll()`
explicitly. It bypasses the visibility filter on purpose.

`visibility: hidden` and `opacity: 0` widgets are *not* treated as hidden;
the IntersectionObserver fires for both, so the helper does too.

#### Cumulative Layout Shift (CLS)

The gem reserves a `min-height` on the placeholder div that matches what
Cloudflare's iframe will eventually render at, so the page doesn't jump
when the widget swaps in:

| `data-size` | Reserved `min-height` |
|---|---|
| `normal` (default) / `flexible` | `65px` |
| `compact` | `120px` |
| `invisible` | (none — the widget takes no space) |

The reservation is skipped automatically when:

* you supply your own `style:` attribute,
* you set `class: nil` (signalling that you'll handle styling yourself),
* you're using an invisible widget (`data: { size: 'invisible' }`), or
* `config.lazy_mount = false` (the iframe is already there before paint).

#### Disabling Lazy Mounting

If you'd rather load `api.js` eagerly (the v1.x behaviour), set:

```ruby
config.lazy_mount = false
```

This is the right choice if you were already calling `turnstile.render(...)` from your own JavaScript with `config.render = 'explicit'` in v1.x. Leave `config.render = 'explicit'` and turn `lazy_mount` off — your existing manual rendering will keep working unchanged.

### Backend Validation

#### Simple Validation

* To validate a Turnstile response in your controller, use either `valid_turnstile?` or `turnstile_valid?`. Both methods behave identically and return a `boolean`. The `model` parameter is optional:

  ```ruby
  if valid_turnstile?(model: @user)
    # Passed: returns true
  else
    # Failed: returns false, adds errors to @user.errors
    render :new, status: :unprocessable_entity
  end
  ```

* When **no model is provided** and verification fails, `valid_turnstile?` automatically sets `flash[:alert]` with the error message. This is useful for redirect-based flows:

  ```ruby
  def create
    if valid_turnstile?
      # Passed: no model needed
      redirect_to dashboard_path, notice: 'Success!'
    else
      # Failed: flash[:alert] is automatically set
      redirect_to contact_path
    end
  end
  ```

* You may also pass additional **siteverify** parameters (e.g., `secret`, `response`, `remoteip`, `idempotency_key`) supported by Cloudflare's API:
  [Cloudflare Server-Side Validation Parameters](https://developers.cloudflare.com/turnstile/get-started/server-side-validation/#required-parameters)

  For example, to pass a custom remote IP address:

  ```ruby
  if valid_turnstile?(model: @user, remoteip: request.remote_ip)
    # Passed with custom IP verification
  else
    # Failed
    render :new, status: :unprocessable_entity
  end
  ```

#### Advanced Validation

* To inspect the entire verification payload, use `verify_turnstile`. It returns a `VerificationResponse` object with detailed information:

  ```ruby
  result = verify_turnstile(model: @user)
  ```

  This method adds errors to the model if verification fails, but unlike `valid_turnstile?`, it does **not** automatically set flash messages. This gives you full control over error handling:

  ```ruby
  if result.success?
    # Passed
  else
    # Failed — handle errors yourself
    flash[:error] = "Custom message: #{result.errors.join(', ')}"
  end
  ```

* The `VerificationResponse` object contains the raw response from Cloudflare:

  ```ruby
  # Success:
  Cloudflare::Turnstile::Rails::VerificationResponse @raw = {
    'success' => true,
    'error-codes' => [],
    'challenge_ts' => '2025-05-19T02:52:31.179Z',
    'hostname' => 'example.com',
    'metadata' => { 'result_with_testing_key' => true }
  }

  # Failure:
  Cloudflare::Turnstile::Rails::VerificationResponse @raw = {
    'success' => false,
    'error-codes' => ['invalid-input-response'],
    'messages' => [],
    'metadata' => { 'result_with_testing_key' => true }
  }
  ```

* The following instance methods are available in `VerificationResponse`:

  ```plaintext
  action, cdata, challenge_ts, errors, hostname, metadata, raw, success?, to_h
  ```

### CSP Nonce Support

The `cloudflare_turnstile_tag` helper injects the Turnstile widget and accompanying JavaScript inline by default (honouring Rails' `content_security_policy_nonce`), so there's no need to allow `unsafe-inline` in your CSP.

### Turbo & Turbo Streams Support

All widgets will re‑initialize automatically on Turbo navigations (`turbo:render`) and on `<turbo-stream>` renders (`turbo:before-stream-render`) — no extra wiring needed.

### Turbolinks Support

If your Rails app still uses Turbolinks (rather than Turbo), you can add a small helper to your JavaScript pack so that remote form submissions returning HTML correctly display validation errors without a full page reload. Simply copy the file:

```plaintext
templates/shared/cloudflare_turbolinks_ajax_cache.js
```

into your application's JavaScript entrypoint (for example `app/javascript/packs/application.js`). This script listens for Rails UJS `ajax:complete` events that return HTML, caches the response as a Turbolinks snapshot, and then restores it via `Turbolinks.visit`, ensuring forms with validation errors are re‑rendered seamlessly.

## Internationalization (I18n)

Error messages are fully internationalized using Rails I18n. See [all languages](lib/cloudflare/turnstile/rails/locales) bundled with the gem.

### Overriding Translations

To customize error messages, add your own translations in your application's locale files:

```yaml
# config/locales/cloudflare_turnstile/en.yml
en:
  cloudflare_turnstile:
    errors:
      default: "Verification failed. Please try again."
      timeout_or_duplicate: "Session expired. Please try again."
```

Your application's translations take precedence over the gem's defaults.

### Locale Fallbacks

This gem respects Rails' built-in I18n fallback configuration. When `config.i18n.fallbacks = true`, Rails will try fallback locales (including `default_locale`) before using the gem's default message.

For example, with fallbacks enabled and a chain of `:pt → :es`, if a Portuguese translation is missing, Rails will automatically try Spanish before falling back to the gem's default message.

> **Note:** If you use regional locales (e.g., `:pt-BR`, `:zh-CN`), you should enable fallbacks. Without `config.i18n.fallbacks = true`, a locale like `:pt-BR` will **not** automatically fall back to `:pt`, and users will see the generic fallback message instead of the Portuguese translation.

### Adding New Languages

To add a language not bundled with the gem (e.g. Yoruba), create a new locale file:

```yaml
# config/locales/cloudflare_turnstile/yo.yml
yo:
  cloudflare_turnstile:
    errors:
      default: "A ko le jẹrisi pe o jẹ ènìyàn. Jọwọ gbìyànjú lẹ́ẹ̀kansi."
      missing_input_secret: "Kọkọrọ̀ ìkọkọ Turnstile kò sí."
      invalid_input_secret: "Kọkọrọ̀ ìkọkọ Turnstile kò bófin mu, kò sí, tàbí pé ó jẹ́ akọsọ ìdánwò pẹ̀lú ìdáhùn tí kì í ṣe ìdánwò."
      missing_input_response: "A kò fi ìdáhùn Turnstile ránṣẹ́."
      invalid_input_response: "Ìbáṣepọ̀ ìdáhùn Turnstile kò bófin mu."
      bad_request: "Ìbéèrè Turnstile kọjá àṣìṣe nítorí pé a kọ ọ̀ ní ọna tí kò tó."
      timeout_or_duplicate: "Àmì-ẹ̀rí Turnstile ti lo tẹlẹ̀ tàbí pé ó ti parí."
      internal_error: "Àṣìṣe inú Turnstile ṣẹlẹ̀ nígbà ìmúdájú ìdáhùn. Jọwọ gbìyànjú lẹ́ẹ̀kansi."
```

### Available Translation Keys

| Key                      | Cloudflare Error Code      | Description                         |
|--------------------------|----------------------------|-------------------------------------|
| `default`                | —                          | Fallback message for unknown errors |
| `missing_input_secret`   | `missing-input-secret`     | Secret key not configured           |
| `invalid_input_secret`   | `invalid-input-secret`     | Invalid or missing secret key       |
| `missing_input_response` | `missing-input-response`   | Response parameter not provided     |
| `invalid_input_response` | `invalid-input-response`   | Invalid response parameter          |
| `bad_request`            | `bad-request`              | Malformed request                   |
| `timeout_or_duplicate`   | `timeout-or-duplicate`     | Token expired or already used       |
| `internal_error`         | `internal-error`           | Cloudflare internal error           |

For more details on these error codes, see Cloudflare's [error codes reference](https://developers.cloudflare.com/turnstile/get-started/server-side-validation/#error-codes-reference).

## Automated Testing of Your Integration

Cloudflare provides dummy sitekeys and secret keys for development and testing. You can use these to simulate every possible outcome of a Turnstile challenge without touching your production configuration. For future updates, see [https://developers.cloudflare.com/turnstile/troubleshooting/testing/](https://developers.cloudflare.com/turnstile/troubleshooting/testing/).

### Dummy Sitekeys

| Sitekey                    | Description                     | Visibility |
|----------------------------|---------------------------------|------------|
| `1x00000000000000000000AA` | Always passes                   | visible    |
| `2x00000000000000000000AB` | Always blocks                   | visible    |
| `1x00000000000000000000BB` | Always passes                   | invisible  |
| `2x00000000000000000000BB` | Always blocks                   | invisible  |
| `3x00000000000000000000FF` | Forces an interactive challenge | visible    |

### Dummy Secret Keys

| Secret key                            | Description                          |
|---------------------------------------|--------------------------------------|
| `1x0000000000000000000000000000000AA` | Always passes                        |
| `2x0000000000000000000000000000000AA` | Always fails                         |
| `3x0000000000000000000000000000000AA` | Yields a "token already spent" error |

Use these dummy values in your **development** environment to verify all flows. Ensure you match a dummy secret key with its corresponding sitekey when calling `verify_turnstile`. Development tokens will look like `XXXX.DUMMY.TOKEN.XXXX`.

### Overriding Configuration in Tests

You may also directly override site or secret keys at runtime within individual tests or in setup blocks:

```ruby
Cloudflare::Turnstile::Rails.configuration.site_key   = '1x00000000000000000000AA'
Cloudflare::Turnstile::Rails.configuration.secret_key = '2x0000000000000000000000000000000AA'
```

### Controller Tests

As long as `config.auto_populate_response_in_test_env` is set to `true` (default) in `cloudflare_turnstile.rb` and you're using a dummy secret key that always passes, your existing controller tests will pass without changes.

If `config.auto_populate_response_in_test_env` is set to `false`, then you will need to manually include the `cf-turnstile-response` parameter in your test cases with any `value`. For example:

```ruby
post :create, params: { 'cf-turnstile-response': 'XXXX.DUMMY.TOKEN.XXXX' }
```

This will ensure that the Turnstile response is included in the request, allowing your controller to validate it as expected.

### Feature/System Tests

Assuming you're using a dummy key, you can confirm that the Turnstile widget is rendered correctly in Minitest with:

```ruby
assert_selector "input[name='cf-turnstile-response'][value*='DUMMY']", visible: :all, wait: 5
```

Or, if using RSpec:

```ruby
expect(page).to have_selector("input[name='cf-turnstile-response'][value*='DUMMY']", visible: :all, wait: 5)
```

This will cause the browser to wait up to 5 seconds for the widget to appear.

## Upgrade Guide

This gem is fully compatible with Rails **5.0 and above**, and no special upgrade steps are required:

* **Simply update Rails** in your application as usual.
* Continue using the same `cloudflare_turnstile_tag` helper in your views and `valid_turnstile?` in your controllers.
* All Turbo, Turbo Streams, and Turbolinks integrations continue to work without changes.

If you run into any issues after upgrading Rails, please [open an issue](https://github.com/vkononov/cloudflare-turnstile-rails/issues) so we can address it promptly.

### Upgrading from v1.x to v2.0

v2.0 introduces lazy mounting and changes a handful of defaults. Here's what to expect.

**TL;DR — most apps need zero changes.** The widget will start rendering on first user interaction (or scroll-into-view) instead of on `DOMContentLoaded`, and that's it.

#### What changed

| | v1.x | v2.0 |
|---|---|---|
| Default `config.render` | `nil` (Cloudflare auto-renders) | `'explicit'` (gem drives rendering) |
| `api.js` load timing | On every page load | When the widget is needed |
| Widget render timing | Immediately after `api.js` loads | When the widget enters the viewport, on first user gesture, or via `cfTurnstile.mountAll()` |
| New JS API | – | `window.cfTurnstile.{ensureLoaded, mount, mountAll}` |
| Placeholder `min-height` | None | Size-aware (`65px` / `120px` / none) reserved by default to prevent CLS |

#### Decision matrix

Your upgrade path depends on whether you customised `config.render` in v1.x:

* **You never set `config.render` in v1.x** (the most common case): no action required. Lazy mounting is on by default and works out of the box.
* **You set `config.render = 'explicit'` in v1.x and called `turnstile.render(...)` yourself from JavaScript**: keep `config.render = 'explicit'` (this is now the default anyway) and add `config.lazy_mount = false`. Your manual rendering code continues to work exactly as before, and the gem will load `api.js` eagerly the way it used to.
  * If you'd rather hand control of rendering over to the gem, delete your manual `turnstile.render(...)` calls instead and leave `config.lazy_mount = true`.
* **You set `config.render = 'auto'` in v1.x** (rare; `'auto'` is also Cloudflare's default): set `config.lazy_mount = false` to silence the boot-time warning, or switch to `config.render = 'explicit'` to opt into lazy mounting.

#### Boot-time warnings

The gem emits a `Rails.logger.warn` on boot in two situations:

* You have `config.render = 'explicit'` but no `config.lazy_mount` (the v1.x-explicit upgrade fingerprint). Set `config.lazy_mount` explicitly (true or false) to silence it.
* You have `config.lazy_mount = true` together with `config.render = 'auto'` — these two contradict each other. The gem behaves as if `lazy_mount` were false until you fix one or the other.

#### Edge case: mixing eager and lazy widgets on the same page

If you have an unusual setup where some widgets need to render eagerly and others lazily, choose **lazy mode** globally and use a custom CSS class for the eager widgets so the gem's auto-mounting machinery skips them:

```erb
<%= cloudflare_turnstile_tag class: 'cf-turnstile-eager' %>
```

Then call `turnstile.render` yourself for those, e.g. inside `cfTurnstile.ensureLoaded(...)`.

## Troubleshooting

**Lazy mounting in tests**
- Capybara's `visit` doesn't fire a pointer event, so the first-gesture trigger doesn't kick in until your test actually clicks something. If you want a system test to render a widget immediately, either click somewhere first or call the gem's helper:

  ```ruby
  visit new_book_url
  mount_turnstile_widgets! # calls window.cfTurnstile.mountAll() under the hood
  wait_for_turnstile_inputs(1)
  ```

  In your own apps, use `page.execute_script('window.cfTurnstile.mountAll()')`.

**Explicit Rendering**
- If you've configured explicit mode (`config.render = 'explicit'`) but widgets still auto-render, override the default container class:

  ```erb
  <%= cloudflare_turnstile_tag class: nil %>
  ```

  or

  ```erb
  <%= cloudflare_turnstile_tag class: 'my-widget-class' %>
  ```

- By default Turnstile targets elements with the `cf-turnstile` class. For more details, see Cloudflare's [https://developers.cloudflare.com/turnstile/get-started/client-side-rendering/#explicit-rendering](https://developers.cloudflare.com/turnstile/get-started/client-side-rendering/#explicit-rendering).

**CSP Nonce Issues**
- When using Rails' CSP nonces, make sure `content_security_policy_nonce` is available in your view context — otherwise the Turnstile script may be blocked.

**Server Validation Errors**
- Validation failures (invalid, expired, or already‑used tokens) surface as model errors. Consult Cloudflare's [server-side troubleshooting](https://developers.cloudflare.com/turnstile/troubleshooting/testing/) for common [error codes](https://developers.cloudflare.com/turnstile/troubleshooting/client-side-errors/error-codes/) and [test keys](https://developers.cloudflare.com/turnstile/troubleshooting/testing/#test-sitekeys).

> Still stuck? Check the Cloudflare Turnstile docs: [https://developers.cloudflare.com/turnstile/get-started/](https://developers.cloudflare.com/turnstile/get-started/)

## Development

### Setup

Install dependencies, linters, and prepare everything in one step:

```bash
bin/setup
```

### Running the Test Suite

[Appraisal](https://github.com/thoughtbot/appraisal) is used to run the full test suite against multiple Rails versions by generating separate Gemfiles and isolating each environment.

Execute **all** tests (unit, integration, system) across every Ruby & Rails combination:

```bash
bundle exec appraisal install
bundle exec appraisal rake test
```

> **CI Note:** The GitHub Action [.github/workflows/test.yml](https://github.com/vkononov/cloudflare-turnstile-rails/blob/main/.github/workflows/test.yml) runs this command on each Ruby/Rails combo and captures screenshots from system specs.

### JavaScript Unit Tests

The asset-pipeline helper script (`cloudflare_turnstile_helper.js`) has its own [vitest](https://vitest.dev) suite that runs in a fresh JSDOM per test, with no dependency on Ruby/Rails or a real browser. It covers the lazy-mount state machine, the public `cfTurnstile` API, the `IntersectionObserver` / `MutationObserver` / Turbo / gesture trigger paths, and every failure mode (`api.js` `onerror`, missing `data-script-url`, `turnstile.render` throwing, callback isolation, race-protected double-`mount`, etc.).

```bash
npm test          # one-shot run
npm run test:watch # watch mode
```

The full `rake` default also runs the JS suite alongside Minitest and RuboCop.

> **CI Note:** Runs as the `JavaScript unit tests` job in [.github/workflows/test.yml](https://github.com/vkononov/cloudflare-turnstile-rails/blob/main/.github/workflows/test.yml), independent of the Ruby/browser matrix.

### Code Linting

Enforce code style with RuboCop (latest Ruby only):

```bash
bundle exec rubocop
```

> **CI Note:** We run this via [.github/workflows/lint.yml](https://github.com/vkononov/cloudflare-turnstile-rails/blob/main/.github/workflows/lint.yml) on the latest Ruby only.

### Generating Rails Apps Locally

To replicate the integration examples on your machine, you can generate a Rails app directly from the template:

```bash
rails new test_app \
  --skip-git --skip-action-mailer --skip-active-record \
  --skip-action-cable --skip-sprockets --skip-javascript \
  -m templates/template.rb
```

Get the exact command from the `test/integration/` folder, where each integration test has a corresponding Rails app template. For example, to replicate the `test/integration/rails7_template_test.rb` test for Rails `v7.0.4`, run:

```bash
gem install rails -v 7.0.4

rails _7.0.4_ new test_app \
  --skip-git --skip-keeps \
  --skip-action-mailer --skip-action-mailbox --skip-action-text \
  --skip-active-record --skip-active-job --skip-active-storage \
  --skip-action-cable --skip-jbuilder --skip-bootsnap --skip-api \
  -m templates/template.rb
```

Then:

```bash
cd test_app
bin/rails server
```

This bootstraps an app preconfigured for Cloudflare Turnstile matching the versions under `test/integration/`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/vkononov/cloudflare-turnstile-rails.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
