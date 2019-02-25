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
wasm-pack build --release --scope polkadot --target nodejs
rustup default stable

# build asmjs version from
binaryen/bin/wasm2js --enable-mutable-globals --no-validation --output pkg/schnorrkel_js_asm.js pkg/schnorrkel_js_bg.wasm

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

# update the files (new addition)
sed -i -e 's/schnorrkel_js_bg\.wasm/schnorrkel_js_wasm\.js", "schnorrkel_js_asm\.js", "index\.js", "index\.d\.ts/g' $PKG
sed -i -e 's/"main": "schnorrkel_js\.js"/"main": "index\.js"/g' $PKG
sed -i -e 's/"types": "schnorrkel_js\.d\.ts"/"types": "index\.d\.ts"/g' $PKG

# cleanup asm imports
sed -i -e 's/import {/const {/g' $ASM
sed -i -e 's/} from /} = require(/g' $ASM
sed -i -e 's/\.\/schnorrkel_js'\''/\.\/schnorrkel_js'\'')/g' $ASM
sed -i -e 's/export const /module\.exports\./g' $ASM

# we do not want the __ imports (used by WASM) to clutter up
sed -i -e 's/var wasm;/const crypto = require('\''crypto'\''); let wasm; const requires = { crypto };/g' $SRC

# this creates issues in both the browser and RN (@polkadot/util has a polyfill)
sed -i -e 's/const TextDecoder = require('\''util'\'')\.TextDecoder;/const { u8aToString } = require('\''@polkadot\/util'\'');/g' $SRC

# TextDecoder is not available on RN, so use the @polkadot/util replacement (with polyfill)
sed -i -e 's/let cachedTextDecoder = new /\/\/ let cachedTextDecoder = new /g' $SRC
sed -i -e 's/cachedTextDecoder\.decode/u8aToString/g' $SRC

# we are swapping to a async interface for webpack support (wasm limits)
sed -i -e 's/wasm = require/const createPromise = require/g' $SRC

# pull the requires from the imports and the `requires` object
sed -i -e 's/return addHeapObject(require(varg0));/return addHeapObject(requires[varg0]);/g' $SRC
# sed -i -e 's/return addHeapObject(require(varg0));/throw new Error(`Invalid require from WASM for ${varg0}`);/g' $SRC

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
// const asm = require('./schnorrkel_js_asm');
const wasm = require('./schnorrkel_js_wasm');
const schnorrkel = require('./schnorrkel_js');

const FALLBACK = null; // asm

module.exports = async function createExportPromise () {
  const imports = {
    './schnorrkel_js': schnorrkel
  };

  if (!WebAssembly) {
    return FALLBACK;
  }

  try {
    const { instance } = await WebAssembly.instantiate(wasm, imports);

    return instance.exports;
  } catch (error) {
    return FALLBACK;
  }
}
" > $INT
