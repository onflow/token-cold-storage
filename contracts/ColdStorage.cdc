import Crypto

import FungibleToken from "./FungibleToken.cdc"
import FlowToken from "./FlowToken.cdc"

pub contract ColdStorage {

  pub struct interface ColdStorageRequest {
    pub var sigSet: [Crypto.KeyListSignature]
    pub var seqNo: UInt64
    pub var senderAddress: Address

    pub fun signableBytes(): [UInt8]
  }

  pub struct WithdrawRequest: ColdStorageRequest {
    pub var sigSet: [Crypto.KeyListSignature]
    pub var seqNo: UInt64

    pub var senderAddress: Address
    pub var recipientAddress: Address
    pub var amount: UFix64

    init(
      senderAddress: Address,
      recipientAddress: Address,  
      amount: UFix64, 
      seqNo: UInt64, 
      sigSet: [Crypto.KeyListSignature],
    ) {
      self.senderAddress = senderAddress
      self.recipientAddress = recipientAddress
      self.amount = amount

      self.seqNo = seqNo
      self.sigSet = sigSet
    }

    pub fun signableBytes(): [UInt8] {
      let senderAddress = self.senderAddress.toBytes()
      let recipientAddressBytes = self.recipientAddress.toBytes()
      let amountBytes = self.amount.toBigEndianBytes()
      let seqNoBytes = self.seqNo.toBigEndianBytes()

      return senderAddress.concat(recipientAddressBytes).concat(amountBytes).concat(seqNoBytes)
    }
  }

  pub struct KeyListChangeRequest: ColdStorageRequest {
    pub var sigSet: [Crypto.KeyListSignature]
    pub var seqNo: UInt64
    pub var senderAddress: Address

    pub var newKeys: Crypto.KeyList

    init(
      newKeys: Crypto.KeyList,
      seqNo: UInt64,
      senderAddress: Address,
      sigSet: [Crypto.KeyListSignature],
    ) {
      self.newKeys = newKeys
      self.seqNo = seqNo
      self.senderAddress = senderAddress
      self.sigSet = sigSet
    }

    pub fun signableBytes(): [UInt8] {
      // TODO: construct byte array from newKeys, senderAddress, seqNo
      return [0x01]
    }
  }

  pub resource PendingWithdrawal {

    access(self) var pendingVault: @FungibleToken.Vault
    access(self) var request: WithdrawRequest

    init(pendingVault: @FungibleToken.Vault, request: WithdrawRequest) {
      self.pendingVault <- pendingVault
      self.request = request
    }

    pub fun execute(fungibleTokenReceiverPath: PublicPath) {
      var pendingVault <- FlowToken.createEmptyVault()
      self.pendingVault <-> pendingVault

      let recipient = getAccount(self.request.recipientAddress)
      let receiver = recipient
        .getCapability(fungibleTokenReceiverPath)!
        .borrow<&{FungibleToken.Receiver}>()
        ?? panic("Unable to borrow receiver reference for recipient")

      receiver.deposit(from: <- pendingVault)
    }

    destroy (){
      pre {
        self.pendingVault.balance == 0.0 as UFix64
      }
      destroy self.pendingVault
    }
  }

  pub resource interface PublicVault {
    pub fun getSequenceNumber(): UInt64

    pub fun getBalance(): UFix64

    pub fun getKeys(): Crypto.KeyList

    pub fun prepareWithdrawal(request: WithdrawRequest): @PendingWithdrawal

    pub fun updateSignatures(request: KeyListChangeRequest)
  }

  pub resource Vault : FungibleToken.Receiver, PublicVault {    
    access(self) var address: Address
    access(self) var keys: Crypto.KeyList
    access(self) var contents: @FungibleToken.Vault
    access(self) var seqNo: UInt64

    pub fun deposit(from: @FungibleToken.Vault) {
      self.contents.deposit(from: <-from)
    }

    pub fun getSequenceNumber(): UInt64 {
        return self.seqNo
    }

    pub fun getBalance(): UFix64 {
      return self.contents.balance
    }

    pub fun getKeys(): Crypto.KeyList {
      return self.keys
    }

    pub fun prepareWithdrawal(request: WithdrawRequest): @PendingWithdrawal {
      pre {
        self.isValidSignature(request: request)
      } 
      post {
        self.seqNo == request.seqNo + UInt64(1)
      }

      self.incrementSequenceNumber()

      return <- create PendingWithdrawal(pendingVault: <- self.contents.withdraw(amount: request.amount), request: request)
    }

    pub fun updateSignatures(request: KeyListChangeRequest) {
      pre {
        self.isValidSignature(request: request)
      }
      post {
        self.seqNo == request.seqNo + UInt64(1)
      }

      self.incrementSequenceNumber()

      self.keys = request.newKeys
    } 

    access(self) fun incrementSequenceNumber(){
      self.seqNo = self.seqNo + UInt64(1)
    }

    access(self) fun isValidSignature(request: {ColdStorage.ColdStorageRequest}): Bool {
      pre {
        self.seqNo == request.seqNo 
        self.address == request.senderAddress
      }

      return ColdStorage.validateSignature(
        keys: self.keys,
        signatureSet: request.sigSet,
        message: request.signableBytes()
      )
    }

    init(address: Address, keys: Crypto.KeyList, contents: @FungibleToken.Vault) {
      self.keys = keys
      self.seqNo = UInt64(0)
      self.contents <- contents
      self.address = address
    }

    destroy() {
      destroy self.contents
    }
  }

  pub fun createVault(
    address: Address, 
    keys: Crypto.KeyList, 
    contents: @FungibleToken.Vault,
  ): @Vault {
    return <- create Vault(address: address, keys: keys, contents: <- contents)
  }

  pub fun validateSignature(
    keys: Crypto.KeyList,
    signatureSet: [Crypto.KeyListSignature],
    message: [UInt8],
  ): Bool {
    return keys.verify(
      signatureSet: signatureSet,
      signedData: message
    )
  }
}
