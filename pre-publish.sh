#!/usr/bin/env bash

# install wasm-pack as required
if ! [ -x "$(command -v wasm-pack)" ]; then
  echo "*** Installing wasm-pack"
  curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh
fi

# install binaryen as required
if [ ! -d "binaryen" ]; then
  echo "*** Installing binaryen"
  git clone --recursive https://github.com/WebAssembly/binaryen.git
  rm -rf binaryen/test
fi

# build wasm2js as required
if [ ! -f "binaryen/bin/wasm2js" ]; then
  cd binaryen
  cmake . && make wasm2js
  cd ..
fi

# cleanup old
rm -rf ./pkg

# build new via nightly & wasm-pack
rustup default nightly
wasm-pack build --target nodejs
rustup default stable

# build asmjs version from
binaryen/bin/wasm2js --pedantic --output pkg/schnorrkel_js_asm.js pkg/schnorrkel_js_bg.wasm

# convert wasm to base64 structure
./pack-node.sh

# copy our package interfaces
cp src/js/* pkg/

# shortcuts for files
INT=pkg/schnorrkel_js_bg.js
SRC=pkg/schnorrkel_js.js
DEF=pkg/schnorrkel_js.d.ts
ASM=pkg/schnorrkel_js_asm.js
PKG=pkg/package.json

# Fix the name in package.json
sed -i -e 's/schnorrkel-js/@polkadot\/schnorrkel-js/g' $PKG

# update the files (new addition)
sed -i -e 's/schnorrkel_js_bg\.wasm/schnorrkel_js_wasm\.js", "schnorrkel_js_asm\.js", "index\.js", "index\.d\.ts/g' $PKG
sed -i -e 's/"main": "schnorrkel_js\.js"/"main": "index\.js"/g' $PKG
sed -i -e 's/"types": "schnorrkel_js\.d\.ts"/"types": "index\.d\.ts"/g' $PKG

# cleanup asm imports
sed -i -e 's/import {/const {/g' $ASM
sed -i -e 's/} from /} = require(/g' $ASM
sed -i -e 's/\.\/schnorrkel_js'\''/\.\/schnorrkel_js'\'')/g' $ASM
sed -i -e 's/export const /module\.exports\./g' $ASM

# we do not want the __ imports (used by WASM) to clutter up the exports, these are internal
# sed -i -e 's/var wasm;/let wasm; const wasmImports = {};/g' $SRC
# sed -i -e 's/module\.exports\.__/wasmImports\.__/g' $SRC

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
const wasmPromise = createPromise().catch(() => null);

module.exports.isReady = function () { return !!wasm; }
module.exports.waitReady = function () { return wasmPromise.then(() => !!wasm); }

wasmPromise.then((_wasm) => { wasm = _wasm });
" >> $SRC

# add extra methods to type definitions
echo "
export function isReady(): boolean;
export function waitReady(): Promise<boolean>;
" >> $DEF

# create the init promise handler
echo "
const asm = require('./schnnorrkel_js_asm');
const wasm = require('./schnorrkel_js_wasm');
const schnorrkel = require('./schnorrkel_js');

module.exports = async function createExportPromise () {
  const imports = {
    './schnorrkel_js': schnorrkel
  };

  if (!WebAssembly) {
    return asm; // null
  }

  try {
    const { instance } = await WebAssembly.instantiate(wasm, imports);

    return instance.exports;
  } catch (error) {
    return asm; // null
  }
}
" > $INT
