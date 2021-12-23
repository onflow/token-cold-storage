import Crypto

import FungibleToken from "./FungibleToken.cdc"
import FlowToken from "./FlowToken.cdc"
import ColdStorage from "../contracts/ColdStorage.cdc"

transaction(publicKeyA: String, publicKeyB: String) {
  prepare(account: AuthAccount) {

    let flowVault <- FlowToken.createEmptyVault()

    let keys = Crypto.KeyList()

    keys.add(
      PublicKey(
        publicKey: publicKeyA.decodeHex(),
        signatureAlgorithm: SignatureAlgorithm.ECDSA_P256,
      ),
      hashAlgorithm: HashAlgorithm.SHA3_256,
      weight: 0.5,
    )

    keys.add(
      PublicKey(
        publicKey: publicKeyB.decodeHex(),
        signatureAlgorithm: SignatureAlgorithm.ECDSA_P256,
      ),
      hashAlgorithm: HashAlgorithm.SHA3_256,
      weight: 0.5,
    )
    
    let coldVault <- ColdStorage.createVault(
      address: account.address, 
      keys: keys, 
      contents: <-flowVault,
    )
    
    // save the new cold vault to storage
    account.save(<-coldVault, to: /storage/flowTokenColdStorage)
  
    // ability to get the sequence number of the vault
    account.link<&ColdStorage.Vault{ColdStorage.PublicVault}>(
      /public/flowTokenColdStorage,
      target: /storage/flowTokenColdStorage
    )

    account.unlink(/public/flowTokenReceiver)
    
    account.link<&{FungibleToken.Receiver}>(
      /public/flowTokenReceiver,
      target: /storage/flowTokenColdStorage
    )
  }
}
