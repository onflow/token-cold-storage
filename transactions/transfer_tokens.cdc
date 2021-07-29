import Crypto

import ColdStorage from "../contracts/ColdStorage.cdc"

transaction(senderAddress: Address, recipientAddress: Address, amount: UFix64, seqNo: UInt64, signatureA: String, signatureB: String) {

  let pendingWithdrawal: @ColdStorage.PendingWithdrawal

  prepare(signer: AuthAccount) {
    let sender = getAccount(senderAddress)

    let publicVault = sender
      .getCapability(/public/flowTokenColdStorage)!
      .borrow<&ColdStorage.Vault{ColdStorage.PublicVault}>()!

    let signatureSet = [
      Crypto.KeyListSignature(
        keyIndex: 0,
        signature: signatureA.decodeHex()
      ),
      Crypto.KeyListSignature(
        keyIndex: 1,
        signature: signatureB.decodeHex()
      )
    ]

    let request = ColdStorage.WithdrawRequest(
      senderAddress: senderAddress, 
      recipientAddress: recipientAddress, 
      amount: amount, 
      seqNo: seqNo, 
      sigSet: signatureSet,
    )
    
    self.pendingWithdrawal <- publicVault.prepareWithdrawal(request: request)
  }

  execute {
    self.pendingWithdrawal.execute(fungibleTokenReceiverPath: /public/flowTokenReceiver)
    destroy self.pendingWithdrawal
  }
}
