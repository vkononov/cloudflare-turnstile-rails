(function(){
    function reinitializeTurnstile() {
        if (typeof turnstile !== "undefined") {
            document.querySelectorAll('.cf-turnstile').forEach(function(el) {
                if (!el.dataset.initialized && el.childElementCount === 0) {
                    turnstile.render(el);
                    el.dataset.initialized = true;
                }
            });
        }
    }

    if (!window._turnstileHelperLoaded) {
        window._turnstileHelperLoaded = true;

        // read our data-attribute to know which CF script URL to use:
        var me      = document.currentScript;
        var cfUrl   = me.getAttribute('data-script-url');
        var helper  = document.createElement('script');
        helper.src  = cfUrl;
        helper.async = true;
        helper.defer = true;
        var nonce   = me.getAttribute('nonce');
        if (nonce) helper.nonce = nonce;
        document.head.appendChild(helper);

        // set up Turbo hooks only once
        document.addEventListener("turbo:load",   reinitializeTurnstile);
        document.addEventListener("turbo:before-stream-render", function(event) {
            var orig = event.detail.render.bind(event.detail);
            event.detail.render = function() {
                orig.apply(this, arguments);
                reinitializeTurnstile();
            };
        });
    }

    // always try to render any containers already in the DOM
    reinitializeTurnstile();
})();