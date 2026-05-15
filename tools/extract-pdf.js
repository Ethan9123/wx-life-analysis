#!/usr/bin/env node
/**
 * extract-pdf.js — extract text from a PDF using pdf-parse
 *
 * Usage:
 *   node tools/extract-pdf.js <path-to-pdf> [startPage] [endPage]
 *
 * Examples:
 *   node tools/extract-pdf.js my.pdf
 *   node tools/extract-pdf.js my.pdf 1 20
 *
 * Notes:
 *   - Resolves pdf-parse from the global npm root so users don't need a local
 *     node_modules. Install once with: npm install -g pdf-parse
 *   - Prints METADATA + TEXT to stdout. Errors to stderr.
 *   - Page range is inclusive. Pass 1 999 (or omit) for "all".
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const pdfPath = process.argv[2];
const startPage = parseInt(process.argv[3] || '1', 10);
const endPage = parseInt(process.argv[4] || '999', 10);

if (!pdfPath) {
  console.error('ERR: missing PDF path');
  console.error('usage: node tools/extract-pdf.js <path-to-pdf> [startPage] [endPage]');
  process.exit(2);
}

if (!fs.existsSync(pdfPath)) {
  console.error(`ERR: file not found: ${pdfPath}`);
  process.exit(2);
}

if (isNaN(startPage) || isNaN(endPage) || startPage < 1 || endPage < startPage) {
  console.error(`ERR: invalid page range: ${startPage}..${endPage}`);
  process.exit(2);
}

// Locate pdf-parse from global npm install
let pdfParse;
try {
  const npmGlobal = execSync('npm root -g', { encoding: 'utf8' }).trim();
  pdfParse = require(path.join(npmGlobal, 'pdf-parse'));
} catch (err) {
  console.error('ERR: cannot find pdf-parse. Install it globally:');
  console.error('  npm install -g pdf-parse');
  console.error(`  (underlying error: ${err.message})`);
  process.exit(3);
}

const buf = fs.readFileSync(pdfPath);

// pdf-parse's `pagerender` is called once per page. We use it to filter
// by page range and join page texts with a separator.
let currentPage = 0;
const pageRender = (pageData) => {
  currentPage += 1;
  if (currentPage < startPage || currentPage > endPage) {
    return Promise.resolve(''); // skip
  }
  return pageData.getTextContent().then((tc) => {
    const text = tc.items.map((i) => i.str).join(' ');
    return `\n\n=== Page ${currentPage} ===\n${text}`;
  });
};

pdfParse(buf, { pagerender: pageRender })
  .then((data) => {
    console.log('=== METADATA ===');
    console.log(`File:     ${path.basename(pdfPath)}`);
    console.log(`Pages:    ${data.numpages}`);
    console.log(`Range:    ${startPage}..${Math.min(endPage, data.numpages)}`);
    console.log(`Info:     ${JSON.stringify(data.info || {}, null, 2)}`);
    console.log('=== TEXT ===');
    console.log(data.text);
  })
  .catch((err) => {
    console.error(`ERR: ${err.message}`);
    process.exit(1);
  });
