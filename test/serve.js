/*
 * What doGet actually serves, as JSON on stdout.
 *
 * The page a headless run should look at is not Index.html off the disk: that
 * file still has the bootstrap placeholder in it, and the client script throws
 * without real config. doGet is what a phone receives, so doGet is what gets
 * rendered — including the meta tags it adds, which Apps Script injects rather
 * than reading out of the file.
 *
 * This runs as its own process on purpose. test/harness.js replaces setTimeout
 * and setInterval with a virtual clock that only advances when a test says so,
 * and a browser driver sharing that process would wait forever for timers that
 * never fire.
 */
require('./harness.js');

const out = doGet();
process.stdout.write(JSON.stringify({
  html: out.getContent(),
  metas: out.metas,
  title: out.title,
  categories: clientConfig_().categories.map(function (c) { return c.key; })
}));
