import { Buffer } from "node:buffer";
import { scryptSync, createCipheriv } from "node:crypto";

export interface HashConfig {
  algorithm: 'SCRYPT';
  base64_signer_key: string;
  base64_salt_separator: string;
  rounds: number;
  mem_cost: number;
}

export function verifyFirebasePassword(
  password: string,
  passwordHash: string,
  salt: string,
  config: HashConfig
): boolean {
  try {
    const signerKeyBuffer = Buffer.from(config.base64_signer_key, 'base64');
    const saltSeparatorBuffer = Buffer.from(config.base64_salt_separator, 'base64');
    const saltBuffer = Buffer.from(salt, 'base64');
    
    const n = Math.pow(2, config.mem_cost);
    const r = config.rounds;
    const p = 1;
    
    const combinedSalt = Buffer.concat([saltBuffer, saltSeparatorBuffer]);
    
    // 1. Scrypt the password with the combined salt
    const derivedKey = scryptSync(password, combinedSalt, 32, { N: n, r, p });
    
    // 2. Encrypt the scrypt output using AES-256-CTR with IV=0 and signer_key
    const cipher = createCipheriv('aes-256-ctr', signerKeyBuffer.slice(0, 32), Buffer.alloc(16, 0));
    let encrypted = cipher.update(derivedKey);
    encrypted = Buffer.concat([encrypted, cipher.final()]);
    
    return Buffer.from(passwordHash, 'base64').equals(encrypted);
  } catch (error) {
    console.error('Error verifying Firebase password:', error);
    return false;
  }
}
