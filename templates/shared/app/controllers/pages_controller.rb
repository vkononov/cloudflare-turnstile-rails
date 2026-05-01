class PagesController < ApplicationController
  def home; end

  # Demo + regression target for the lazy-mount path. The system tests
  # submit this form to verify that:
  #   1. the gem actually mounts the widget when triggered, AND
  #   2. the resulting Turnstile token makes it into the form payload
  #      and validates server-side (a regression that mounted the
  #      widget in a detached iframe, scoped it to the wrong form,
  #      cached a stale token, etc., would fail this assertion).
  def lazy_demo
    return unless request.post?

    if valid_turnstile?
      redirect_to lazy_demo_path, notice: 'Lazy demo verified.'
    else
      # `valid_turnstile?` already populated flash[:alert] with the
      # gem's default error message on failure; just redirect.
      redirect_to lazy_demo_path
    end
  end

  # Demo + regression target for the modal-hidden path. Same purpose
  # as lazy_demo above, but the widget has to survive being inside a
  # `display: none` ancestor that opens via JS before submission.
  def modal_demo
    return unless request.post?

    if valid_turnstile?
      redirect_to modal_demo_path, notice: 'Modal demo verified.'
    else
      redirect_to modal_demo_path
    end
  end
end
