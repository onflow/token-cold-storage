import Crypto

import ColdStorage from "../contracts/ColdStorage.cdc"

transaction(
  amount: UFix64, 
  to: Address, 
  seqNo: UInt64, 
  senderAddress: Address, 
  signatureA: String,
  signatureB: String,
) {
  let pendingWithdrawal: @ColdStorage.PendingWithdrawal

  prepare() {
    let sender = getAccount(senderAddress)

    let storedVaultCapability = sender.getCapability(/public/flowTokenColdStorage) ?? panic("Unable to borrow a reference to the sender's Vault")
    let storedVault =  storedVaultCapability.borrow<&{ColdStorage.PublicVault}>() ?? panic("Vault is not a ColdStorage PublicVault")

    let signatureSet = [
      Crypto.KeyListSignature(
        keyIndex: 0,
        signature: signatureA.decodeHex()
      ),
      Crypto.KeyListSignature(
        keyIndex: 1,
        signature: signatureA.decodeHex()
      )
    ]

    let request = ColdStorage.WithdrawRequest(
      amount: amount, 
      toAddress: toAddress, 
      seqNo: seqNo, 
      address: senderAddress, 
      sigSet: signatureSet,
    )
    
    self.pendingWithdrawal <- storedVault.prepareWithdrawal(request: request)
  }

  execute {
    self.pendingWithdrawal.execute(fungibleTokenRecieverPath: /public/flowTokenReceiver)
    destroy self.pendingWithdrawal
  }
}
