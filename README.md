# Flow Cold Storage Contract

## `ColdStorage.cdc`

The `ColdStorage` contract only needs to be deployed once to a single account. This contract defines the `ColdStorage.Vault` resource, which can be used by any account to implement a cold storage multi-sig fungible token vault.

This contract currently has stubs for signature verification and sequence numbers. To test this integration, you can use the following values for the `sigSet` and `seqNo` parameters:

 - `sigSet: []`
 - `seqNo: 0`

## `setup_account.cdc`

This transaction creates a new account and replaces the default `FlowToken.Vault` with the custom `ColdStorage.Vault` resource.

A `ColdStorage.Vault` wraps the existing `FlowToken.Vault` and conforms to the same `FungibleToken.Receiver` interface, meaning the account can still receive token deposits as normal.

## `transfer_tokens.cdc`

This transaction demonstrates how to transfer tokens out of a `ColdStorage.Vault` into another account. The receiving account does not need to hold a `ColdStorage.Vault` -- it only needs to expose the the `FungibleToken.Receiver` interface.
