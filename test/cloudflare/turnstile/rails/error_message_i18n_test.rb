require 'test_helper'

require 'cloudflare/turnstile/rails/constants/error_code'
require 'cloudflare/turnstile/rails/constants/error_message'

module Cloudflare
  module Turnstile
    module Rails
      class ErrorMessageI18nTest < Minitest::Test # rubocop:disable Metrics/ClassLength
        def setup
          # Load the gem's locale files
          locale_path = File.expand_path('../../../../lib/cloudflare/turnstile/rails/locales/*.yml', __dir__)
          I18n.load_path += Dir[locale_path]
          I18n.backend.load_translations

          # Store original settings to restore after each test
          @original_locale = I18n.locale
          @original_default_locale = I18n.default_locale
          @original_available_locales = I18n.available_locales.dup
          @original_fallbacks = I18n.fallbacks.dup if I18n.respond_to?(:fallbacks)
        end

        def teardown
          I18n.locale = @original_locale
          I18n.default_locale = @original_default_locale
          I18n.available_locales = @original_available_locales
          # Reset fallbacks to prevent test pollution
          I18n.fallbacks = @original_fallbacks if @original_fallbacks
        end

        def test_english_translations_are_loaded
          I18n.locale = :en

          result = ErrorMessage.send(:translate, :default)

          assert_equal "We could not verify that you're human. Please try again.", result
        end

        def test_german_translations_are_loaded
          I18n.locale = :de

          result = ErrorMessage.send(:translate, :default)

          assert_equal 'Wir konnten nicht bestätigen, dass Sie ein Mensch sind. Bitte versuchen Sie es erneut.', result
        end

        def test_all_english_keys_are_present
          I18n.locale = :en

          ErrorCode::ALL.each do |code|
            key = ErrorMessage.send(:key_for, code)
            result = I18n.t(key, scope: ErrorMessage::SCOPE, default: nil)

            refute_nil result, "Expected English translation for #{key}"
            refute_empty result
          end
        end

        def test_all_german_keys_are_present
          I18n.locale = :de

          ErrorCode::ALL.each do |code|
            key = ErrorMessage.send(:key_for, code)
            result = I18n.t(key, scope: ErrorMessage::SCOPE, default: nil)

            refute_nil result, "Expected German translation for #{key}"
            refute_empty result
          end
        end

        def test_locale_switching_returns_correct_language
          # Test English
          I18n.locale = :en
          en_message = ErrorMessage.send(:translate, :timeout_or_duplicate)

          # Test German
          I18n.locale = :de
          de_message = ErrorMessage.send(:translate, :timeout_or_duplicate)

          refute_equal en_message, de_message, 'English and German messages should be different'
          assert_match(/token/i, en_message)
          assert_match(/Token/i, de_message)
        end

        def test_unsupported_locale_falls_back_to_fallback
          # Add Yoruba to available locales (but we have no translations for it)
          # Without Rails fallbacks configured, it should use FALLBACK
          I18n.available_locales = %i[en de yo]
          I18n.locale = :yo

          result = ErrorMessage.send(:translate, :default)

          # Falls back to FALLBACK constant (Rails fallbacks not configured in test)
          assert_equal ErrorMessage::FALLBACK, result
        end

        def test_unsupported_locale_with_known_code_falls_back_to_fallback
          # Add Yoruba to available locales (but we have no translations for it)
          I18n.available_locales = %i[en de yo]
          I18n.locale = :yo

          result = ErrorMessage.for(ErrorCode::TIMEOUT_OR_DUPLICATE)

          # Falls back to FALLBACK (Rails fallbacks not configured in test)
          assert result.start_with?(ErrorMessage::FALLBACK)
          assert result.end_with?("(#{ErrorCode::TIMEOUT_OR_DUPLICATE})")
        end

        def test_for_method_uses_current_locale
          I18n.locale = :de

          result = ErrorMessage.for(ErrorCode::TIMEOUT_OR_DUPLICATE)

          assert_match(/Token/i, result)
          assert result.end_with?("(#{ErrorCode::TIMEOUT_OR_DUPLICATE})")
        end

        def test_default_method_uses_current_locale
          I18n.locale = :de

          result = ErrorMessage.default

          assert_equal 'Wir konnten nicht bestätigen, dass Sie ein Mensch sind. Bitte versuchen Sie es erneut.', result
        end

        def test_unknown_key_falls_back_to_fallback
          I18n.locale = :de

          result = ErrorMessage.send(:translate, :nonexistent_key_xyz)

          assert_equal ErrorMessage::FALLBACK, result
        end

        def test_all_bundled_locales_have_complete_translations # rubocop:disable Metrics/AbcSize
          # Get all locale files bundled with the gem
          locale_dir = File.expand_path('../../../../lib/cloudflare/turnstile/rails/locales', __dir__)
          locale_files = Dir[File.join(locale_dir, '*.yml')]

          # Extract expected keys from ErrorCode::ALL + :default
          expected_keys = ErrorCode::ALL.map { |code| ErrorMessage.send(:key_for, code) } + [:default]

          locale_files.each do |file|
            locale = File.basename(file, '.yml').to_sym
            I18n.available_locales |= [locale]

            expected_keys.each do |key|
              result = I18n.t(key, scope: ErrorMessage::SCOPE, locale: locale, default: nil)

              refute_nil result, "Missing translation for #{key.inspect} in #{locale}.yml"
              refute_empty result, "Empty translation for #{key.inspect} in #{locale}.yml"
            end
          end
        end

        # --- Rails fallback chain tests ---
        # These tests verify behavior when config.i18n.fallbacks = true

        def test_rails_fallbacks_single_fallback_to_available_locale
          with_fallbacks_enabled do
            # Yoruba → English (we have English translations)
            I18n.available_locales = %i[en de yo]
            I18n.fallbacks = I18n::Locale::Fallbacks.new(yo: :en)
            I18n.locale = :yo

            result = ErrorMessage.send(:translate, :default)

            # Should fall back to English, not FALLBACK
            assert_equal "We could not verify that you're human. Please try again.", result
          end
        end

        def test_rails_fallbacks_single_fallback_to_unavailable_locale
          with_fallbacks_enabled do
            # Yoruba → Swedish (we don't have Swedish translations)
            I18n.available_locales = %i[en de yo sv]
            I18n.fallbacks = I18n::Locale::Fallbacks.new(yo: :sv)
            I18n.locale = :yo

            result = ErrorMessage.send(:translate, :default)

            # Should use FALLBACK since neither yo nor sv have translations
            assert_equal ErrorMessage::FALLBACK, result
          end
        end

        def test_rails_fallbacks_chain_first_unavailable_second_available
          with_fallbacks_enabled do
            # Yoruba → Swedish → German
            # Swedish has no translations, German does
            I18n.available_locales = %i[en de yo sv]
            I18n.fallbacks = I18n::Locale::Fallbacks.new(yo: %i[sv de])
            I18n.locale = :yo

            result = ErrorMessage.send(:translate, :default)

            # Should skip Swedish (no translations) and use German
            assert_equal 'Wir konnten nicht bestätigen, dass Sie ein Mensch sind. Bitte versuchen Sie es erneut.',
                         result
          end
        end

        def test_rails_fallbacks_chain_all_unavailable
          with_fallbacks_enabled do
            # Yoruba → Swedish → Finnish (none have translations)
            I18n.available_locales = %i[en de yo sv fi]
            I18n.fallbacks = I18n::Locale::Fallbacks.new(yo: %i[sv fi])
            I18n.locale = :yo

            result = ErrorMessage.send(:translate, :default)

            # Should use FALLBACK since no locale in chain has translations
            assert_equal ErrorMessage::FALLBACK, result
          end
        end

        def test_rails_fallbacks_for_method_respects_chain
          with_fallbacks_enabled do
            # Yoruba → German
            I18n.available_locales = %i[en de yo]
            I18n.fallbacks = I18n::Locale::Fallbacks.new(yo: :de)
            I18n.locale = :yo

            result = ErrorMessage.for(ErrorCode::TIMEOUT_OR_DUPLICATE)

            # Should use German translation
            assert_match(/Token/i, result) # German uses "Token"
            assert result.end_with?("(#{ErrorCode::TIMEOUT_OR_DUPLICATE})")
          end
        end

        def test_rails_fallbacks_respects_default_locale
          with_fallbacks_enabled do
            # Set Spanish as default_locale
            # Yoruba has no translations, should fall back to default_locale (Spanish)
            I18n.available_locales = %i[en de es yo]
            I18n.default_locale = :es
            I18n.fallbacks = I18n::Locale::Fallbacks.new
            I18n.fallbacks.defaults = [I18n.default_locale]
            I18n.locale = :yo

            result = ErrorMessage.send(:translate, :default)

            # Should fall back to Spanish (default_locale)
            assert_equal 'No pudimos verificar que eres humano. Por favor, inténtalo de nuevo.', result
          end
        end

        def test_app_translations_override_gem_translations # rubocop:disable Metrics/MethodLength
          I18n.locale = :en

          # Store original value
          original = ErrorMessage.send(:translate, :default)

          # Simulate app providing custom translation (loaded after gem)
          I18n.backend.store_translations(
            :en, {cloudflare_turnstile: { errors: { default: 'CUSTOM APP MESSAGE' } }}
          )

          result = ErrorMessage.send(:translate, :default)

          assert_equal 'CUSTOM APP MESSAGE', result
          refute_equal original, result
        ensure
          # Restore original by re-storing it
          if defined?(original) && original
            I18n.backend.store_translations(
              :en, { cloudflare_turnstile: { errors: { default: original } } }
            )
          end
        end

        def test_regional_locale_without_fallbacks_uses_fallback_constant
          # en-US has no translations, and without fallbacks, it won't try :en
          I18n.available_locales = %i[en en-US]
          I18n.locale = :'en-US'

          result = ErrorMessage.send(:translate, :default)

          # Without fallbacks, goes straight to FALLBACK constant
          assert_equal ErrorMessage::FALLBACK, result
        end

        def test_regional_locale_with_fallbacks_uses_base_locale
          with_fallbacks_enabled do
            # en-US should fall back to :en when fallbacks are enabled
            I18n.available_locales = %i[en en-US]
            I18n.fallbacks = I18n::Locale::Fallbacks.new
            I18n.locale = :'en-US'

            result = ErrorMessage.send(:translate, :default)

            # Should fall back to English
            assert_equal "We could not verify that you're human. Please try again.", result
          end
        end

        private

        def with_fallbacks_enabled
          # Include the Fallbacks module (what Rails does with config.i18n.fallbacks = true)
          original_backend = I18n.backend
          I18n::Backend::Simple.include(I18n::Backend::Fallbacks)

          yield
        ensure
          I18n.backend = original_backend
        end
      end
    end
  end
end
