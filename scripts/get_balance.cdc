import ColdStorage from "../contracts/ColdStorage.cdc"

pub fun main(address: Address): UFix64 {
  let publicVault = getAccount(address)
    .getCapability(/public/flowTokenColdStorage)!
    .borrow<&ColdStorage.Vault{ColdStorage.PublicVault}>()!

  return publicVault.getBalance()
}
