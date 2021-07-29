import path from "path";
import { 
  emulator, 
  init, 
  shallPass, 
  shallResolve, 
  shallRevert,
  mintFlow,
  getFlowBalance,
} from "flow-js-testing";

import {
  deployColdStorage,
  setupColdStorageVault,
  transferTokens,
  getBalance,
} from "../src/cold-storage";

import { signWithPrivateKey, sigAlgos, hashAlgos } from "../src/crypto"

import { toUFix64, getAccountA, getAccountB } from "../src/common";

// We need to set timeout for a higher number, because some transactions might take up some time
jest.setTimeout(50000);

const privateKeyA = "a883b6291a57260fbedd3e8d97e80fae51b6b4d6a06beb5b4e65abc771d089b9"
const privateKeyB = "6762ad19ddbaa32b9d4eab8cda47a75cfc1add35b9cb195eeff68720d21aeda9"

const publicKeyA = "c22486263226f11536ff10f4b2ad30f52dfb4b37e457adc6e95531d4c7c1d3ba9b5871c69ac4108129fc4e6856cb7c3458e57bfdb577b32cfa7dc49598de4289"
const publicKeyB = "395a7e3a2a0eda183b95dd2cee48baa4c584b44a9ef06db7e1103e609b923a142c181a402fed59d3ea2fc90431c366311c5cc1f76cc72927d27cfdafd4b2acdd"

// The UserDomainTag is the prefix of all signed user space payloads.
//
// Before hashing and signing the message, the wallet must add a specified DOMAIN TAG.
//
// UserDomainTag is currently "FLOW-V0.0-user"
//
// A domain tag is encoded as UTF-8 bytes, right padded to a total length of 32 bytes, prepended to the message.
const userDomainTag = Buffer.from("464c4f572d56302e302d75736572000000000000000000000000000000000000", "hex")

function toBigEndianBytes(number, bits) {
  return Buffer.from(
    BigInt(number).toString(16).padStart(bits / 4, "0"),
    "hex",
  )
}

describe("ColdStorage", () => {
  // Instantiate emulator and path to Cadence files
  beforeEach(async () => {
    const basePath = path.resolve(__dirname, "../../../");
    const port = 8083;
    init(basePath, port);
    return emulator.start(port, false);
  });

  // Stop emulator, so it could be restarted
  afterEach(async () => {
    return emulator.stop();
  });

  it("should be able to create an empty ColdStorage.Vault", async () => {
    await deployColdStorage();

    const accountB = await getAccountB();

    await shallPass(setupColdStorageVault(accountB, publicKeyA, publicKeyB));

    const balance = await getBalance(accountB);
    expect(balance).toBe(toUFix64(0));
  });

  it("should be able to create a ColdStorage.Vault and fund with FLOW", async () => {
    await deployColdStorage();

    const accountB = await getAccountB();

    await shallPass(setupColdStorageVault(accountB, publicKeyA, publicKeyB));

    await mintFlow(accountB, "10.0");

    const balance = await getBalance(accountB);
    expect(balance).toBe(toUFix64(10.0));
  });

  it("should be able to transfer FLOW from a ColdStorage.Vault", async () => {
    await deployColdStorage();

    const accountA = await getAccountA();
    const accountB = await getAccountB();

    await shallPass(setupColdStorageVault(accountB, publicKeyA, publicKeyB));

    await mintFlow(accountB, "10.0");

    const sender = accountB
    const recipient = accountA
    const amount = "5.0"
    const seqNo = 0

    const message = Buffer.concat(
      [
        userDomainTag,
        Buffer.from(sender.slice(2), "hex"),
        Buffer.from(recipient.slice(2), "hex"),
        toBigEndianBytes("500000000", 64), // amount
        toBigEndianBytes("0", 64),         // seqNo
      ]
    ).toString("hex");

    const signatureA = signWithPrivateKey(
      privateKeyA,
      sigAlgos.ECDSA_P256,
      hashAlgos.SHA3_256,
      message
    );

    const signatureB = signWithPrivateKey(
      privateKeyB, 
      sigAlgos.ECDSA_P256, 
      hashAlgos.SHA3_256, 
      message,
    );

    await shallPass(transferTokens(
      sender, recipient, amount, seqNo, signatureA, signatureB
    ));

    const balanceA = await getFlowBalance(accountA);
    expect(balanceA).toBe(toUFix64(15.00100000));

    const balanceB = await getBalance(accountB);
    expect(balanceB).toBe(toUFix64(5.0));
  });
});
