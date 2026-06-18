import {defineConfig} from 'vitest/config';

export default defineConfig({
  test: {
    // We construct a fresh JSDOM per test for isolation, so the runner itself doesn't need a DOM.
    environment: 'node',
    include: ['test/javascript/**/*.test.js'],
    globals: false,
    reporters: 'default'
  }
});
