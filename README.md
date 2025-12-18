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
* **Turbo & Turbo Streams aware**: Automatically re‑initializes widgets on `turbo:load`, `turbo:before-stream-render`, and DOM mutations.
* **Legacy Turbolinks support**: Includes a helper for Turbolinks to handle remote form submissions with validation errors.
* **CSP nonce support**: Honours Rails' `content_security_policy_nonce` for secure inline scripts.
* **Rails Engine & Asset pipeline**: Ships a precompiled JS helper via Railtie — no manual asset setup.
* **Lightweight**: Pure Ruby/Rails with only `net/http` and `json` dependencies.


## Table of Contents

- [Getting Started](#getting-started)
  - [Installation](#installation)
  - [Frontend Integration](#frontend-integration)
  - [Backend Validation](#backend-validation)
  - [CSP Nonce Support](#csp-nonce-support)
  - [Turbo & Turbo Streams Support](#turbo--turbo-streams-support)
  - [Turbolinks Support](#turbolinks-support)
- [Internationalization (I18n)](#internationalization-i18n)
- [Automated Testing of Your Integration](#automated-testing-of-your-integration)
- [Upgrade Guide](#upgrade-guide)
- [Troubleshooting](#troubleshooting)
- [Development](#development)
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
   <%= cloudflare_turnstile_tag data: { theme: 'auto', language: 'en' } %>
   ```

* For all available **data-**\* options (e.g., `action`, `cdata`, `theme`, etc.), refer to the official Cloudflare client-side rendering docs:
  [https://developers.cloudflare.com/turnstile/get-started/client-side-rendering/#configuration-options](https://developers.cloudflare.com/turnstile/get-started/client-side-rendering/#configuration-options)
* **Supported locales** for the widget UI can be found here:
  [https://developers.cloudflare.com/turnstile/reference/supported-languages/](https://developers.cloudflare.com/turnstile/reference/supported-languages/)

### Backend Validation

#### Simple Validation

* To validate a Turnstile response in your controller, use either `valid_turnstile?` or `turnstile_valid?`. Both methods behave identically and return a `boolean`. The `model` parameter is optional but recommended for automatic error handling:

  ```ruby
  if valid_turnstile?(model: @user)
    # Passed: returns true
  else
    # Failed: returns false, adds errors to @user
    render :new, status: :unprocessable_entity
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

  This method still adds errors to the model if verification fails. You can query the response:

  ```ruby
  if result.success?
    # Passed
  else
    # Failed — inspect result.errors or result.raw
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

All widgets will re‑initialize automatically on full and soft navigations (`turbo:load`), on `<turbo-stream>` renders (`turbo:before-stream-render`), and on DOM mutations — no extra wiring needed.

### Turbolinks Support

If your Rails app still uses Turbolinks (rather than Turbo), you can add a small helper to your JavaScript pack so that remote form submissions returning HTML correctly display validation errors without a full page reload. Simply copy the file:

```
templates / shared / cloudflare_turbolinks_ajax_cache.js
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

## Troubleshooting

**Duplicate Widgets**
- If more than one Turnstile widget appears in the same container, this indicates a bug in the gem—please [open an issue](https://github.com/vkononov/cloudflare-turnstile-rails/issues) so it can be addressed.

**Explicit Rendering**
- If you've configured explicit mode (`config.render = 'explicit'` or `cloudflare_turnstile_tag render: 'explicit'`) but widgets still auto-render, override the default container class:

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
- Validation failures (invalid, expired, or already‑used tokens) surface as model errors. Consult Cloudflare's [server-side troubleshooting](https://developers.cloudflare.com/turnstile/troubleshooting/testing/) for common [error codes](https://developers.cloudflare.com/turnstile/troubleshooting/client-side-errors/error-codes/) and [test keys](https://developers.cloudflare.com/turnstile/troubleshooting/testing/#dummy-sitekeys-and-secret-keys).

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

Get the exact command from the `test/integration/` folder, where each integration test has a corresponding Rails app template. For example, to replicate the `test/integration/rails7.rb` test for Rails `v7.0.4`, run:

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
