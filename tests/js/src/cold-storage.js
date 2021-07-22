import { deployContractByName, mintFlow, sendTransaction } from "flow-js-testing";
import { getAccountA } from "./common";

export const deployColdStorage = async () => {
  const accountA = await getAccountA();
  await mintFlow(accountA, "10.0");

  return deployContractByName({ to: accountA, name: "ColdStorage" });
};

export const setupColdStorageVault = async (account, publicKeyA, publicKeyB) => {
  const name = "setup_account";
  const args = [publicKeyA, publicKeyB];
  const signers = [account];

  return sendTransaction({ name, args, signers });
};

export const transferTokens = async (sender, recipient, amount, seqNo, signatures) => {
  const name = "transfer_tokens";
  const args = [amount, recipient, seqNo, sender, signatures];
  const signers = [sender];

  return sendTransaction({ name, args, signers });
};
