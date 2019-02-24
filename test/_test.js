// @ts-check
const crypto = require('crypto');
const { assert, stringToU8a, u8aToHex } = require('@polkadot/util');
const schnorrkel = require('../pkg/index');

async function beforeAll () {
  return schnorrkel.waitReady();
}

async function pairFromSeed () {
  const SEED = stringToU8a('12345678901234567890123456789012');
  const PAIR = Uint8Array.from([
    // sk
    240, 16, 102, 96, 195, 221, 162, 63, 22, 218, 169, 172, 91, 129, 27, 150, 48, 119, 245, 188, 10, 248, 159, 133, 128, 79, 13, 232, 228, 36, 240, 80, 249, 141, 102, 243, 148, 66, 80, 111, 249, 71, 253, 145, 31, 24, 199, 167, 165, 218, 99, 154, 99, 232, 211, 180, 226, 51, 247, 65, 67, 217, 81, 193,
    // pk
    116, 28, 8, 160, 111, 65, 197, 150, 96, 143, 103, 116, 37, 155, 217, 4, 51, 4, 173, 250, 93, 62, 234, 98, 118, 11, 217, 190, 151, 99, 77, 99
  ]);

  const pair = schnorrkel.keypair_from_seed(SEED);

  console.error('pair', u8aToHex(pair.slice(0, 64)), u8aToHex(pair.slice(64)));

  assert(u8aToHex(pair) === u8aToHex(PAIR), 'pairFromSeed() does not match')
}

async function signAndVerify () {
  const SEED = new Uint8Array(32);
  const MESSAGE = stringToU8a('this is a message');

  crypto.randomFillSync(SEED);

  const pair = schnorrkel.keypair_from_seed(SEED);
  const pk = pair.slice(64);
  const sk = pair.slice(0, 64);
  const signature = schnorrkel.sign(pk, sk, MESSAGE);

  console.error('signature', u8aToHex(signature));

  assert(schnorrkel.verify(signature, MESSAGE, pk) === true, 'Unable to verify signature');
}

(async () => {
  await beforeAll();
  await pairFromSeed();
  await signAndVerify();
})().catch(console.log).finally(() => process.exit());
