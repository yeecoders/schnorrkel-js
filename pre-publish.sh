#!/usr/bin/env bash

# install wasm-pack as required
if ! [ -x "$(command -v wasm-pack)" ]; then
  curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh
fi

# cleanup old
rm -rf ./pkg

# build new via nightly & wasm-pack
rustup default nightly
wasm-pack build --target nodejs
rustup default stable

# shortcuts for files
SRC=pkg/schnorrkel_js.js
DEF=pkg/schnorrkel_js.d.ts
PKG=pkg/package.json

# Fix the name in package.json
sed -i -e 's/schnorrkel-js/@polkadot\/schnorrkel-js/g' $PKG

# update the files (new addition)
sed -i -e 's/schnorrkel_js_bg\.wasm/schnorrkel_js_wasm\.js/g' $PKG

# we do not want the __ imports (used by WASM) to clutter up the exports, these are internal
sed -i -e 's/var wasm;/let wasm; const wasmImports = {};/g' $SRC
sed -i -e 's/module\.exports\.__/wasmImports\.__/g' $SRC

# this creates issues in both the browser and RN (@polkadot/util has a polyfill)
sed -i -e 's/const TextDecoder = require('\''util'\'')\.TextDecoder;/const { u8aToString } = require('\''@polkadot\/util'\'');/g' $SRC

# TextDecoder is not available on RN, so use the @polkadot/util replacement (with polyfill)
sed -i -e 's/let cachedTextDecoder = new /\/\/ let cachedTextDecoder = new /g' $SRC
sed -i -e 's/cachedTextDecoder\.decode/u8aToString/g' $SRC

# we are swapping to a async interface, don't do this
sed -i -e 's/wasm = require/const createPromise = require/g' $SRC

# this we don't allow, we don't have an actual call into this and creates webpack warnings
sed -i -e 's/return addHeapObject(require(varg0));/throw new Error(`Invalid require from WASM for ${varg0}`);/g' $SRC

# construct our promise and add ready helpers
echo "
const wasmPromise = createPromise(wasmImports);

module.exports.isReady = function () { return !!wasm; }
module.exports.waitReady = function () { return wasmPromise.then(() => true); }

wasmPromise.then((_wasm) => { wasm = _wasm });
" >> $SRC

# add extra methods to type definitions
echo "
export function isReady(): boolean;
export function waitReady(): Promise<boolean>;
" >> $DEF

# Run the script to fix node/browser import support
./pack-node.sh
