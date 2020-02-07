// @ts-check
const stubbed = require('./schnorrkel_js');

module.exports.deriveKeypairHard = stubbed.derive_keypair_hard;
module.exports.deriveKeypairSoft = stubbed.derive_keypair_soft;
module.exports.derivePublicSoft = stubbed.derive_public_soft;
module.exports.isReady = stubbed.isReady;
module.exports.keypairFromSeed = stubbed.keypair_from_seed;
module.exports.sign = stubbed.sign;
module.exports.verify = stubbed.verify;
module.exports.toPublic = stubbed.to_public;
module.exports.waitReady = stubbed.waitReady;
