#!/usr/bin/env node

console.log('+++ Fixing nodejs imports.\n');

const fs = require('fs');
const buffer = fs.readFileSync('./pkg/schnorrkel_js_bg.wasm');

fs.writeFileSync('./pkg/schnorrkel_js_wasm.js', `
module.exports = Buffer.from('${buffer.toString('base64')}', 'base64');
`);

fs.writeFileSync('./pkg/schnorrkel_js_bg.js', `
const bytes = require('./schnorrkel_js_wasm');

module.exports = async function createExportPromise (wasmImports) {
  const imports = {
    './schnorrkel_js': wasmImports
  };

  if (!WebAssembly) {
    return null;
  }

  try {
    const { instance } = await WebAssembly.instantiate(bytes, imports);

    return instance.exports;
  } catch (error) {
    return null;
  }
}
`);
