/**
 * This script improves UX for Rails 6 applications using Rails UJS + Turbolinks.
 *
 * Problem:
 * When submitting a form remotely (`remote: true`), if the server responds with
 * HTML (e.g., `render :new` or `render :edit` with validation errors),
 * Rails UJS fires `ajax:complete`, but nothing is automatically updated in the DOM.
 *
 * This results in poor UX — users see no feedback when form validation fails.
 *
 * Solution:
 * This listener catches AJAX responses that return full HTML content.
 * If the content type is `text/html`, we:
 *   1. Wrap the response in a Turbolinks snapshot.
 *   2. Cache the snapshot against the current URL.
 *   3. Trigger `Turbolinks.visit()` with `action: 'restore'` to re-render the page.
 *
 * This causes a soft reload (via Turbolinks) that displays the server-rendered
 * form with validation errors — giving users proper feedback without a full reload.
 */

(function() {
  'use strict';

  document.addEventListener('ajax:complete', function(event) {
    var referrer, snapshot;
    var xhr = event.detail[0];

    // Check if the response is HTML (e.g., a rendered form with errors)
    if ((xhr.getResponseHeader('Content-Type') || '').substring(0, 9) === 'text/html') {
      referrer = window.location.href;

      // Wrap the response in a Turbolinks snapshot
      snapshot = Turbolinks.Snapshot.wrap(xhr.response);

      // Store the snapshot in Turbolinks' cache
      Turbolinks.controller.cache.put(referrer, snapshot);

      // Revisit the current page to restore the updated form view with errors
      return Turbolinks.visit(referrer, {
        action: 'restore'
      });
    }

    // For non-HTML responses (e.g., JSON), do nothing
    return true;
  }, false);
}());
