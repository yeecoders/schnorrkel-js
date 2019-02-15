#!/usr/bin/env node

console.log('+++ Fixing nodejs imports.\n');

const fs = require('fs');
const buffer = fs.readFileSync('./pkg/schnorrkel_js_bg.wasm');

fs.writeFileSync('./pkg/schnorrkel_js_wasm.js', `
module.exports = Buffer.from('${buffer.toString('base64')}', 'base64');
`);

fs.writeFileSync('./pkg/schnorrkel_js_bg.js', `
const bytes = require('./schnorrkel_js_wasm.js');

module.exports = function createExportPromise (wasmImports) {
  const imports = {
    './schnorrkel_js': wasmImports
  };

  return WebAssembly
    .instantiate(bytes, imports)
    .then((wasm) => wasm.instance.exports);
}
`);
