require 'test_helper'

require 'cloudflare/turnstile/rails/constants/error_code'
require 'cloudflare/turnstile/rails/constants/error_message'

module Cloudflare
  module Turnstile
    module Rails
      class ErrorMessageI18nTest < Minitest::Test
        def setup
          # Load the gem's locale files
          locale_path = File.expand_path('../../../../lib/cloudflare/turnstile/rails/locales/*.yml', __dir__)
          I18n.load_path += Dir[locale_path]
          I18n.backend.load_translations

          # Store original settings to restore after each test
          @original_locale = I18n.locale
          @original_available_locales = I18n.available_locales.dup
        end

        def teardown
          I18n.locale = @original_locale
          I18n.available_locales = @original_available_locales
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

        def test_unsupported_locale_falls_back_to_english
          # Add Yoruba to available locales (but we have no translations for it)
          I18n.available_locales = %i[en de yo]
          I18n.locale = :yo

          result = ErrorMessage.send(:translate, :default)

          assert_equal "We could not verify that you're human. Please try again.", result
        end

        def test_unsupported_locale_with_known_code_falls_back_to_english
          # Add Yoruba to available locales (but we have no translations for it)
          I18n.available_locales = %i[en de yo]
          I18n.locale = :yo

          result = ErrorMessage.for(ErrorCode::TIMEOUT_OR_DUPLICATE)

          # Should contain the English translation
          assert_match(/token/i, result)
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
      end
    end
  end
end
