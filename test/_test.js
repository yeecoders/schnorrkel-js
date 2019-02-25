// @ts-check
const crypto = require('crypto');
const { assert, hexToU8a, stringToU8a, u8aToHex } = require('@polkadot/util');
const schnorrkel = require('../pkg/index');

async function beforeAll () {
  return schnorrkel.waitReady();
}

async function pairFromSeed () {
  const SEED = stringToU8a('12345678901234567890123456789012');
  const PAIR = hexToU8a(
    '0x' +
    // private
    'f0106660c3dda23f16daa9ac5b811b963077f5bc0af89f85804f0de8e424f050' +
    'f98d66f39442506ff947fd911f18c7a7a5da639a63e8d3b4e233f74143d951c1' +
    // public
    '741c08a06f41c596608f6774259bd9043304adfa5d3eea62760bd9be97634d63'
  );

  const pair = schnorrkel.keypair_from_seed(SEED);

  console.error('keypair_from_seed (known)');
  console.log('\t', u8aToHex(pair.slice(0, 64)));
  console.log('\t', u8aToHex(pair.slice(64)));

  assert(u8aToHex(pair) === u8aToHex(PAIR), 'ERROR: pairFromSeed() does not match')
}

async function verifyExisting () {
  const PK = hexToU8a('0x741c08a06f41c596608f6774259bd9043304adfa5d3eea62760bd9be97634d63');
  const MESSAGE = stringToU8a('this is a message');
  const SIGNATURE = hexToU8a(
    '0x' +
    '162657aac408f204381e7c491cc67c61c454c169f22841f7d949c4b63c79c83e' +
    '35c8d79dfca6c9f1778d5a91391bad7753edfb714518b2be58f33322712fe20a'
  );

  const isValid = schnorrkel.verify(SIGNATURE, MESSAGE, PK);

  console.error('verify (exiting, known)');
  console.log('\t', isValid);

  assert(isValid, 'ERROR: Unble to verify existing signature');
}

async function signAndVerify () {
  const SEED = new Uint8Array(32);
  const MESSAGE = stringToU8a('this is a message');

  crypto.randomFillSync(SEED);

  const pair = schnorrkel.keypair_from_seed(SEED);
  const pk = pair.slice(64);
  const sk = pair.slice(0, 64);
  const signature = schnorrkel.sign(pk, sk, MESSAGE);
  const isValid = schnorrkel.verify(signature, MESSAGE, pk);

  console.error('sign & verify (random)');
  console.log('\t', u8aToHex(signature));
  console.log('\t', isValid);

  assert(isValid, 'ERROR: Unable to verify new random signature');
}

(async () => {
  await beforeAll();
  await pairFromSeed();
  await verifyExisting();
  await signAndVerify();
})().catch(console.log).finally(() => process.exit());
