import fs from 'fs';
import path from 'path';
import { marked } from 'marked';

const input = process.argv[2];
const output = process.argv[3];

const md = fs.readFileSync(input, 'utf8');
const title = path.basename(input, path.extname(input));

marked.setOptions({ gfm: true, breaks: false });
const body = marked.parse(md);

const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>${title}</title>
<style>
  @page { size: A4; margin: 18mm 16mm; }
  body {
    font-family: "Segoe UI", Arial, Helvetica, sans-serif;
    font-size: 11pt; line-height: 1.5; color: #1a1a1a;
    max-width: 100%; margin: 0;
  }
  h1, h2, h3, h4, h5, h6 { color: #10243e; line-height: 1.25; margin-top: 1.2em; }
  h1 { font-size: 22pt; border-bottom: 2px solid #10243e; padding-bottom: 6px; }
  h2 { font-size: 17pt; border-bottom: 1px solid #ccc; padding-bottom: 4px; }
  h3 { font-size: 14pt; }
  h4 { font-size: 12pt; }
  code {
    font-family: "Cascadia Code", Consolas, monospace; font-size: 9.5pt;
    background: #f2f4f7; padding: 1px 4px; border-radius: 3px;
  }
  pre {
    background: #f6f8fa; border: 1px solid #e1e4e8; border-radius: 6px;
    padding: 12px; overflow-x: auto; font-size: 9pt; line-height: 1.4;
    page-break-inside: avoid;
  }
  pre code { background: none; padding: 0; }
  table { border-collapse: collapse; width: 100%; margin: 12px 0; font-size: 9.5pt; }
  th, td { border: 1px solid #cbd5e0; padding: 6px 10px; text-align: left; vertical-align: top; }
  th { background: #eef2f7; font-weight: 600; }
  tr:nth-child(even) td { background: #fafbfc; }
  blockquote {
    border-left: 4px solid #b0c4de; margin: 12px 0; padding: 4px 14px;
    color: #444; background: #f7f9fc;
  }
  a { color: #1a5fb4; text-decoration: none; }
  img { max-width: 100%; }
  ul, ol { padding-left: 22px; }
  li { margin: 3px 0; }
  hr { border: none; border-top: 1px solid #ddd; margin: 20px 0; }
</style>
</head>
<body>
${body}
</body>
</html>`;

fs.writeFileSync(output, html, 'utf8');
console.log('HTML written to', output);
