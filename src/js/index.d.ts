export function isReady (): boolean;
export function keypair_from_seed (seed: Uint8Array): Uint8Array;
export function secret_from_seed (seed: Uint8Array): Uint8Array;
export function sign (publicKey: Uint8Array, secretKey: Uint8Array, message: Uint8Array): Uint8Array;
export function verify (signature: Uint8Array, message: Uint8Array, publicKey: Uint8Array): boolean;
export function waitReady (): Promise<boolean>;
