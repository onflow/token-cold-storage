import Crypto

import FungibleToken from "./FungibleToken.cdc"
import FlowToken from "./FlowToken.cdc"

pub contract ColdStorage {

  pub struct interface ColdStorageRequest {
    pub var sigSet: [Crypto.KeyListSignature]
    pub var seqNo: UInt64
    pub var address: Address

    pub fun signableBytes(): [UInt8]
  }

  pub struct WithdrawRequest: ColdStorageRequest {
    pub var sigSet: [Crypto.KeyListSignature]
    pub var seqNo: UInt64
    pub var address: Address

    pub var toAddress: Address
    pub var amount: UFix64

    init(
      amount: UFix64, 
      toAddress: Address, 
      seqNo: UInt64, 
      fromAddress: Address, 
      sigSet: [Crypto.KeyListSignature],
    ) {
      self.amount = amount
      self.toAddress = toAddress

      self.seqNo = seqNo
      self.address = fromAddress
      self.sigSet = sigSet
    }

    pub fun signableBytes(): [UInt8] {
      let toAddressBytes = self.toAddress.toBytes()
      let amountBytes = self.amount.toBigEndianBytes()
      let addressBytes = self.address.toBytes()
      let seqNoBytes = self.seqNo.toBigEndianBytes()

      return toAddressBytes.concat(amountBytes).concat(addressBytes).concat(seqNoBytes)
    }
  }

  pub struct KeyListChangeRequest: ColdStorageRequest {
    pub var sigSet: [Crypto.KeyListSignature]
    pub var seqNo: UInt64
    pub var address: Address

    pub var newKeyList: Crypto.KeyList

    init(
      newKeyList: Crypto.KeyList,
      seqNo: UInt64,
      address: Address,
      sigSet: [Crypto.KeyListSignature],
    ) {
      self.newKeyList = newKeyList
      self.seqNo = seqNo
      self.address = address
      self.sigSet = sigSet
    }

    pub fun signableBytes(): [UInt8] {
      // TODO: construct byte array from newKeyList, address, seqNo
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

      let recipient = getAccount(self.request.toAddress)
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
    access(self) var keyList: Crypto.KeyList
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
      return self.keyList
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

      self.keyList = request.newKeyList
    } 

    access(self) fun incrementSequenceNumber(){
      self.seqNo = self.seqNo + UInt64(1)
    }

    access(self) fun isValidSignature(request: {ColdStorage.ColdStorageRequest}): Bool {
      pre {
        self.seqNo == request.seqNo 
        self.address == request.address
      }

      return ColdStorage.validateSignature(
        keyList: self.keyList,
        signatureSet: request.sigSet,
        message: request.signableBytes()
      )
    }

    init(address: Address, keyList: Crypto.KeyList, contents: @FungibleToken.Vault) {
      self.keyList = keyList
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
    keyList: Crypto.KeyList, 
    contents: @FungibleToken.Vault,
  ): @Vault {
    return <- create Vault(address: address, keyList: keyList, contents: <- contents)
  }

  pub fun validateSignature(
    keyList: Crypto.KeyList,
    signatureSet: [Crypto.KeyListSignature],
    message: [UInt8],
  ): Bool {
    return keyList.verify(
        signatureSet: signatureSet,
        signedData: message
    )
  }
}
