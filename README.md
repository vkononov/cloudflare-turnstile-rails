# Cloudflare Turnstile Rails

[![Gem Version](https://badge.fury.io/rb/cloudflare-turnstile-rails.svg)](https://rubygems.org/gems/cloudflare-turnstile-rails)
[![Lint Status](https://github.com/vkononov/cloudflare-turnstile-rails/actions/workflows/lint.yml/badge.svg)](https://github.com/vkononov/cloudflare-turnstile-rails/actions/workflows/lint.yml)
[![Test Status](https://github.com/vkononov/cloudflare-turnstile-rails/actions/workflows/test.yml/badge.svg)](https://github.com/vkononov/cloudflare-turnstile-rails/actions/workflows/test.yml)

A lightweight Rails helper for effortless Cloudflare Turnstile integration with Turbo support and CSP compliance.

## Features

* **One‑line integration**: `<%= cloudflare_turnstile_tag %>` in views, `verify_turnstile(model:)` in controllers — no extra wiring.
* **CSP nonce support**: Honors Rails’s `content_security_policy_nonce` for secure inline scripts.
* **Turbo & Turbo Streams aware**: Automatically re‑initializes widgets on `turbo:load`, `turbo:before-stream-render`, and DOM mutations.
* **Error‑code mappings**: Human‑friendly messages for Cloudflare’s test keys and common failure codes.
* **Rails Engine & Asset pipeline**: Ships a precompiled JS helper via Railtie — no manual asset setup.
* **Lightweight**: Pure Ruby/Rails with only `net/http` and `json` dependencies.

> **Note:** Even legacy Rails applications (5+) can leverage Cloudflare Turnstile by adding this gem.

## Getting Started

### Prerequisites

Before you begin, you should have your own Cloudflare Turnstile keys:

- **Site Key** and **Secret Key** from Cloudflare.

> Cloudflare provides extensive documentation for Turnstile [here](https://developers.cloudflare.com/turnstile/). It is highly recommended to read it to understand its options and idiosyncrasies.

### Installation

Add the gem to your Gemfile and bundle:

```ruby
gem 'cloudflare-turnstile-rails'
```

```bash
bundle install
```

Generate the default initializer:

```bash
bin/rails generate cloudflare_turnstile:install
```

Configure your **Site Key** and **Secret Key** in `config/initializers/cloudflare_turnstile.rb`:

```ruby
Cloudflare::Turnstile::Rails.configure do |config|
  # Set your Cloudflare Turnstile Site Key and Secret Key.
  config.site_key   = ENV.fetch('CLOUDFLARE_TURNSTILE_SITE_KEY', nil)
  config.secret_key = ENV.fetch('CLOUDFLARE_TURNSTILE_SECRET_KEY', nil)

  # Optional: Append render or onload query params
  # config.render = 'explicit'
  # config.onload = 'onloadMyCallback'
end
```

### Frontend Integration

> The helper injects the Turnstile widget and accompanying JavaScript inline by default (honoring Rails' `content_security_policy_nonce`), so there's no need to allow `unsafe-inline` in your CSP.

Include the widget in your views or forms:

```erb
<%= cloudflare_turnstile_tag %>
```

However, it is recommended to match your `theme` and `language` to your app’s design and locale. You can do this by passing `data` attributes to the helper:

```erb
<%= cloudflare_turnstile_tag data: { theme: 'auto', language: 'en' } %>
```

* For all available **data-**\* options (e.g., `action`, `cdata`, `theme`, etc.), refer to the official Cloudflare client-side rendering docs:
  [https://developers.cloudflare.com/turnstile/get-started/client-side-rendering/#configurations](https://developers.cloudflare.com/turnstile/get-started/client-side-rendering/#configurations)
* **Supported locales** for the widget UI can be found here:
  [https://developers.cloudflare.com/turnstile/reference/supported-languages/](https://developers.cloudflare.com/turnstile/reference/supported-languages/)

### Backend Validation

In your controller, call:

```ruby
if verify_turnstile(model: @user)
  # success → returns a VerificationResponse object
else
  # failure → returns false and adds errors to `@user`
  render :new, status: :unprocessable_entity
end
```

* In addition to the `model` option, you can pass any **siteverify** parameters (e.g., `secret`, `remoteip`, `idempotency_key`) supported by Cloudflare’s server-side validation API:
  [https://developers.cloudflare.com/turnstile/get-started/server-side-validation/#accepted-parameters](https://developers.cloudflare.com/turnstile/get-started/server-side-validation/#accepted-parameters)

* On success, `verify_turnstile` returns a `VerificationResponse` (with methods like `.success?`, `.errors`, `.action`, `.cdata`), so you can inspect frontend-set values (`data-action`, `data-cdata`, etc.). On failure it returns `false` and adds a validation error to your model (if provided).

### Turbo & Turbo Streams Support

All widgets will re‑initialize automatically on full and soft navigations (`turbo:load`), on `<turbo-stream>` renders (`turbo:before-stream-render`), and on DOM mutations — no extra wiring needed.

### Turbolinks Support

If your Rails app still uses Turbolinks (rather than Turbo), you can add a small helper to your JavaScript pack so that remote form submissions returning HTML correctly display validation errors without a full page reload. Simply copy the file:

```
templates / shared / cloudflare_turbolinks_ajax_cache.js
```

into your application’s JavaScript entrypoint (for example `app/javascript/packs/application.js`). This script listens for Rails UJS `ajax:complete` events that return HTML, caches the response as a Turbolinks snapshot, and then restores it via `Turbolinks.visit`, ensuring forms with validation errors are re‑rendered seamlessly.

## Testing Your Integration

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

## Upgrade Guide

This gem is fully compatible with Rails **5.0 and above**, and no special upgrade steps are required:

* **Simply update Rails** in your application as usual.
* Continue using the same `cloudflare_turnstile_tag` helper in your views and `verify_turnstile` in your controllers.
* All Turbo, Turbo Streams, and Turbolinks integrations continue to work without changes.

If you run into any issues after upgrading Rails, please [open an issue](https://github.com/vkononov/cloudflare-turnstile-rails/issues) so we can address it promptly.

## Troubleshooting

**Duplicate Widgets**
- If more than one Turnstile widget appears in the same container, this indicates a bug in the gem—please [open an issue](https://github.com/vkononov/cloudflare-turnstile-rails/issues) so it can be addressed.

**Explicit Rendering**
- If you’ve configured explicit mode (`config.render = 'explicit'` or `cloudflare_turnstile_tag render: 'explicit'`) but widgets still auto-render, override the default container class:

  ```erb
  <%= cloudflare_turnstile_tag class: nil %>
  ```

  or

  ```erb
  <%= cloudflare_turnstile_tag class: 'my-widget-class' %>
  ```

- By default Turnstile targets elements with the `cf-turnstile` class. For more details, see Cloudflare’s [https://developers.cloudflare.com/turnstile/get-started/client-side-rendering/#explicitly-render-the-turnstile-widget](https://developers.cloudflare.com/turnstile/get-started/client-side-rendering/#explicitly-render-the-turnstile-widget).

**CSP Nonce Issues**
- When using Rails’ CSP nonces, make sure `content_security_policy_nonce` is available in your view context — otherwise the Turnstile script may be blocked.

**Server Validation Errors**
- Validation failures (invalid, expired, or already‑used tokens) surface as model errors. Consult Cloudflare’s [server-side troubleshooting](https://developers.cloudflare.com/turnstile/troubleshooting/testing/) for common error codes and test keys.

> Still stuck? Check the Cloudflare Turnstile docs: [https://developers.cloudflare.com/turnstile/get-started/](https://developers.cloudflare.com/turnstile/get-started/)

## Development

### Setup

Install dependencies, linters, and prepare everything in one step:

```bash
bin/setup
```

### Running the Test Suite

[Appraisal](https://github.com/thoughtbot/appraisal) is used to run the full test suite against multiple Rails versions by generating separate Gemfiles and isolating each environment. To install dependencies and exercise all unit, integration and system tests:

Execute **all** tests (unit, integration, system) across every Ruby & Rails combination:

```bash
bundle exec appraisal install
bundle exec appraisal rake test
```

> **CI Note:** Our GitHub Actions [.github/workflows/test.yml](https://github.com/vkononov/cloudflare-turnstile-rails/blob/main/.github/workflows/test.yml) runs this command on each Ruby/Rails combo and captures screenshots from system specs.

### Code Linting

Enforce code style with RuboCop (latest Ruby only)::

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

Get the exact command from the `test/integration/` folder, where each integration test has a corresponding Rails app template. For example, to replicate the `test/integration/rails7.rb` test for Rails `v7.0.4`, run:

```bash
gem install rails -v 7_0_4

rails _7_0_4_ new test_app \
  --skip-git --skip-keeps \
  --skip-action-mailer --skip-action-mailbox --skip-action-text \
  --skip-active-record --skip-active-job --skip-active-storage \
  --skip-action-cable --skip-jbuilder --skip-bootsnap --skip-api \
  -m test/integration/rails_7_0_4.rb
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
