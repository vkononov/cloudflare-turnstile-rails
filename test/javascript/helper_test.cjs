/* global __dirname, console */
const assert = require('node:assert/strict');
const { test } = require('node:test');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname,
  '../../lib/cloudflare/turnstile/rails/assets/javascripts/cloudflare_turnstile_helper.js'), 'utf8');

test('explicit widgets render once api.js loads and on subsequent Turbolinks visits', () => {
  const events = {};
  const scriptEvents = {};
  let widgets = [{ dataset: {}, childElementCount: 0 }];
  let renders = 0;
  let apiScript;
  let appended = 0;
  const context = {
    console,
    document: {
      currentScript: { getAttribute: () => 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit', nonce: 'nonce' },
      createElement: () => ({ addEventListener: (name, callback) => { scriptEvents[name] = callback; } }),
      head: { appendChild: (script) => { appended++; apiScript = script; assert.equal(script.nonce, 'nonce'); } },
      addEventListener: (name, callback) => { events[name] = callback; },
      querySelectorAll: () => widgets
    }
  };
  context.window = context;
  vm.createContext(context);
  vm.runInContext(source, context);
  assert.equal(renders, 0);
  // Like the real api.js, ready() refuses to run when the script was loaded async or deferred.
  context.turnstile = {
    ready: () => {
      if (apiScript.async || apiScript.defer) {
        throw new Error('Remove async/defer from the Turnstile api.js script tag before using turnstile.ready()');
      }
    },
    render: () => { renders++; }
  };
  scriptEvents.load();
  assert.equal(renders, 1);
  events['turbolinks:load']();
  assert.equal(renders, 1);
  widgets = [{ dataset: {}, childElementCount: 0 }];
  events['turbolinks:load']();
  assert.equal(renders, 2);
  vm.runInContext(source, context);
  assert.equal(appended, 1);
  assert.equal(renders, 2);
});
