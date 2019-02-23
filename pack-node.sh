#!/usr/bin/env node

console.log('+++ Fixing nodejs imports.\n');

const fs = require('fs');
const buffer = fs.readFileSync('./pkg/schnorrkel_js_bg.wasm');

fs.writeFileSync('./pkg/schnorrkel_js_wasm.js', `
module.exports = Buffer.from('${buffer.toString('base64')}', 'base64');
`);
