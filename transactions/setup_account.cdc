import Crypto

import FungibleToken from "./FungibleToken.cdc"
import FlowToken from "./FlowToken.cdc"
import ColdStorage from "../contracts/ColdStorage.cdc"

transaction(publicKeyA: String, publicKeyB: String) {
  prepare(account: AuthAccount) {

    // let transferVault <- account.load<@FungibleToken.Vault>(from: /storage/flowTokenVault) ?? panic("no FlowToken vault")
    
    let vault <- FlowToken.createEmptyVault()

    let keyList = Crypto.KeyList()

    keyList.add(
      PublicKey(
        publicKey: publicKeyA.decodeHex(),
        signatureAlgorithm: SignatureAlgorithm.ECDSA_P256
      ),
      hashAlgorithm: HashAlgorithm.SHA3_256,
      weight: 0.5
    )

    keyList.add(
      PublicKey(
        publicKey: publicKeyB.decodeHex(),
        signatureAlgorithm: SignatureAlgorithm.ECDSA_P256
      ),
      hashAlgorithm: HashAlgorithm.SHA3_256,
      weight: 0.5
    )
    
    let coldVault <- ColdStorage.createVault(
      address: account.address, 
      keyList: keyList, 
      contents: <-vault,
    )
    
    // save the new cold vault to storage
    account.save(<-coldVault, to: /storage/flowTokenColdStorage)
  
    // re-link flowTokenReceiver to point to cold vault
    account.unlink(/public/flowTokenReceiver)
    
    let reciever = account.link<&{FungibleToken.Receiver}>(
      /public/flowTokenReceiver,
      target: /storage/flowTokenColdStorage
    )!
    
    // account.unlink(/public/flowTokenBalance)
    // // re-link flowTokenBalance to point to cold vault
    // account.link<&{FungibleToken.Balance}>(
    // 	/public/flowTokenBalance,
    // 	target: /storage/flowTokenVaultReference
    // )

    // ability to get the sequence number of the vault
    let publicVault = account.link<&{ColdStorage.PublicVault}>(
      /public/flowTokenColdStorage,
      target: /storage/flowTokenColdStorage
    )!
  }
}
