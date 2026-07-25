/**
 * Renders a Markdown file to a standalone HTML page styled like site/index.html.
 *
 *   node site/build.mjs SETUP.md _site/setup.html "timetap — setup"
 *
 * Deliberately no dependencies: it handles exactly the subset of Markdown the
 * docs in this repo use — headings, paragraphs, tables, fenced code, lists,
 * rules, links, bold, inline code. Anything fancier belongs in the prose, not
 * in a build chain.
 */

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

function inline(s) {
  const codes = [];
  s = s.replace(/`([^`]+)`/g, (_, c) => { codes.push(c); return '\u0000' + (codes.length - 1) + '\u0000'; });
  s = esc(s);
  s = s.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (_, t, h) => `<a href="${h}">${t}</a>`);
  s = s.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  s = s.replace(/(^|[^*])\*([^*\s][^*]*)\*/g, '$1<em>$2</em>');
  return s.replace(/\u0000(\d+)\u0000/g, (_, i) => `<code>${esc(codes[+i])}</code>`);
}

const cells = row => row.replace(/^\s*\|/, '').replace(/\|\s*$/, '').split('|').map(c => c.trim());

function render(md) {
  const lines = md.replace(/\r\n?/g, '\n').split('\n');
  const out = [];
  let i = 0, para = [];

  const flush = () => { if (para.length) { out.push('<p>' + inline(para.join(' ')) + '</p>'); para = []; } };

  while (i < lines.length) {
    const line = lines[i];

    // fenced code
    const fence = /^```(\w*)\s*$/.exec(line);
    if (fence) {
      flush();
      const body = [];
      for (i++; i < lines.length && !/^```\s*$/.test(lines[i]); i++) body.push(lines[i]);
      i++;
      out.push('<pre><code>' + esc(body.join('\n')) + '</code></pre>');
      continue;
    }

    if (!line.trim()) { flush(); i++; continue; }

    const h = /^(#{1,6})\s+(.*)$/.exec(line);
    if (h) { flush(); out.push(`<h${h[1].length}>${inline(h[2].trim())}</h${h[1].length}>`); i++; continue; }

    if (/^\s*(---+|\*\*\*+|___+)\s*$/.test(line)) { flush(); out.push('<hr>'); i++; continue; }

    // table: a pipe row followed by a |---|---| separator
    if (/^\s*\|/.test(line) && i + 1 < lines.length && /^\s*\|[\s:|-]+\|\s*$/.test(lines[i + 1])) {
      flush();
      const head = cells(line);
      i += 2;
      const body = [];
      while (i < lines.length && /^\s*\|/.test(lines[i])) body.push(cells(lines[i++]));
      const hasHead = head.some(c => c !== '');
      out.push('<div class="tw"><table>' +
        (hasHead ? '<thead><tr>' + head.map(c => `<th>${inline(c)}</th>`).join('') + '</tr></thead>' : '') +
        '<tbody>' + body.map(r => '<tr>' + r.map(c => `<td>${inline(c)}</td>`).join('') + '</tr>').join('') +
        '</tbody></table></div>');
      continue;
    }

    // lists, with lazy continuation lines folded into the item
    const item = /^(\s*)([-*]|\d+\.)\s+(.*)$/.exec(line);
    if (item) {
      flush();
      const ordered = /\d/.test(item[2]);
      const items = [];
      while (i < lines.length) {
        const m = /^(\s*)([-*]|\d+\.)\s+(.*)$/.exec(lines[i]);
        if (m && /\d/.test(m[2]) === ordered) {
          items.push([m[3]]);
          i++;
        } else if (items.length && lines[i].trim() && !/^\s*(#{1,6}\s|```|\|)/.test(lines[i])) {
          items[items.length - 1].push(lines[i].trim());
          i++;
        } else break;
      }
      const tag = ordered ? 'ol' : 'ul';
      out.push(`<${tag}>` + items.map(p => `<li>${inline(p.join(' '))}</li>`).join('') + `</${tag}>`);
      continue;
    }

    para.push(line.trim());
    i++;
  }
  flush();
  return out.join('\n');
}

const CSS = `
  :root { --bg:#0b0b0c; --panel:#131417; --panel2:#1b1d21; --fg:#f2f3f5; --dim:#8b9098; --dimmer:#5d626a; --line:#2a2d33; }
  * { box-sizing: border-box; }
  body { margin:0; background:var(--bg); color:var(--fg);
    font:400 16px/1.65 -apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif; }
  .wrap { max-width:760px; margin:0 auto; padding:40px 20px 120px; }
  .back { display:inline-block; color:var(--dim); text-decoration:none; font-size:13px;
    letter-spacing:.14em; text-transform:uppercase; margin-bottom:32px; }
  .back:hover { color:var(--fg); }
  h1 { font-size:34px; letter-spacing:-.01em; margin:0 0 28px; }
  h2 { font-size:13px; font-weight:700; letter-spacing:.17em; color:var(--dim);
    text-transform:uppercase; margin:52px 0 16px; }
  h3 { font-size:17px; margin:34px 0 12px; }
  p { margin:0 0 15px; }
  a { color:var(--fg); }
  hr { border:0; border-top:1px solid var(--line); margin:40px 0; }
  code { font:400 13px/1.5 ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    background:var(--panel2); padding:2px 3px; border-radius:3px; overflow-wrap:anywhere; }
  pre { background:var(--panel); border-radius:10px; padding:16px; overflow-x:auto; margin:0 0 18px;
    font:400 13px/1.6 ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }
  pre code { background:none; padding:0; overflow-wrap:normal; }
  ul, ol { margin:0 0 18px; padding-left:24px; }
  li { margin-bottom:9px; }
  .tw { overflow-x:auto; margin:0 0 20px; }
  table { border-collapse:collapse; width:100%; font-size:15px; }
  th, td { text-align:left; padding:10px 14px 10px 0; border-bottom:1px solid var(--line);
    vertical-align:top; }
  th { font-size:11px; font-weight:700; letter-spacing:.14em; text-transform:uppercase; color:var(--dim); }
  td:first-child { white-space:nowrap; padding-right:22px; }
  @media (prefers-color-scheme: light) {
    :root { --bg:#ffffff; --panel:#f4f5f7; --panel2:#eceef1; --fg:#16181d; --dim:#5d626a; --dimmer:#8b9098; --line:#e2e4e8; }
  }`;

const [, , src, dest, title] = process.argv;
if (!src || !dest) {
  console.error('usage: node site/build.mjs <input.md> <output.html> [title]');
  process.exit(1);
}

const body = render(readFileSync(src, 'utf8'));
const page = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title || src)}</title>
<style>${CSS}
</style>
</head>
<body>
<div class="wrap">
<a class="back" href="./">&larr; timetap</a>
${body}
</div>
</body>
</html>
`;
mkdirSync(dirname(dest), { recursive: true });
writeFileSync(dest, page);
console.log(`${src} -> ${dest} (${page.length} bytes)`);
