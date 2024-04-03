//
//  SendCryptoVerifyViewModel.swift
//  VoltixApp
//
//  Created by Amol Kumar on 2024-03-19.
//

import SwiftUI
import BigInt
import WalletCore

@MainActor
class SendCryptoVerifyViewModel: ObservableObject {
    
    @Published var isAddressCorrect = false
    @Published var isAmountCorrect = false
    @Published var isHackedOrPhished = false
    @Published var showAlert = false
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    @Published var thor = ThorchainService.shared
    @Published var sol: SolanaService = SolanaService.shared
    @Published var utxo = BlockchairService.shared
    @Published var eth = EtherScanService.shared
    var gaia = GaiaService.shared
    
    var THORChainAccount: THORChainAccountValue? = nil
    var CosmosChainAccount: CosmosAccountValue? = nil
    private var isValidForm: Bool {
        return isAddressCorrect && isAmountCorrect && isHackedOrPhished
    }
    
    //TODO: Remove that, we need to use the loadData only
    func reloadTransactions(tx: SendTransaction) {
        Task {
            do{
                if  tx.coin.chain.chainType == ChainType.UTXO {
                    await utxo.fetchBlockchairData(for: tx)
                } else if tx.coin.chain == .thorChain {
                    self.THORChainAccount = try await thor.fetchAccountNumber(tx.fromAddress)
                } else if tx.coin.chain == .solana {
                    await sol.getSolanaBalance(tx: tx)
                    await sol.fetchRecentBlockhash()
                    await MainActor.run {
                        if let feeInLamports = sol.feeInLamports {
                            tx.gas = String(feeInLamports)
                        }
                    }
                } else if tx.coin.chain == .gaiaChain {
                    self.CosmosChainAccount = try await gaia.fetchAccountNumber(tx.fromAddress)
                }
            }
            
            catch{
                print(error.localizedDescription)
            }
        }
    }
    
    func validateForm(tx: SendTransaction) async -> KeysignPayload? {
        
        if !isValidForm {
            self.errorMessage = "mustAgreeTermsError"
            showAlert = true
            isLoading = false
            return nil
        }
        
        if tx.coin.chain.chainType == ChainType.UTXO {
            
            let coinName = tx.coin.chain.name.lowercased()
            let key: String = "\(tx.fromAddress)-\(coinName)"
            
            let totalAmountNeeded = tx.amountInSats + tx.feeInSats
            
            guard let utxoInfo = utxo.blockchairData[key]?.selectUTXOsForPayment(amountNeeded: Int64(totalAmountNeeded)).map({
                UtxoInfo(
                    hash: $0.transactionHash ?? "",
                    amount: Int64($0.value ?? 0),
                    index: UInt32($0.index ?? -1)
                )
            }), !utxoInfo.isEmpty else {
                self.errorMessage = "notEnoughBalanceError"
                showAlert = true
                isLoading = false
                return nil
            }
            
            let totalSelectedAmount = utxoInfo.reduce(0) { $0 + $1.amount }
            
            if totalSelectedAmount < Int64(totalAmountNeeded) {
                self.errorMessage = "notEnoughBalanceError"
                showAlert = true
                isLoading = false
                return nil
            }
            
            let keysignPayload = KeysignPayload(
                coin: tx.coin,
                toAddress: tx.toAddress,
                toAmount: tx.amountInSats,
                chainSpecific: BlockChainSpecific.UTXO(byteFee: tx.feeInSats),
                utxos: utxoInfo,
                memo: tx.memo,
                swapPayload: nil
            )
            
            self.errorMessage = ""
            return keysignPayload
            
            
            
        } else if tx.coin.chain.chainType == ChainType.EVM {
            if tx.coin.isNativeToken {
                let keysignPayload = KeysignPayload(
                    coin: tx.coin,
                    toAddress: tx.toAddress,
                    toAmount: tx.amountInGwei, // in Gwei
                    chainSpecific: BlockChainSpecific.Ethereum(maxFeePerGasGwei: Int64(tx.gas) ?? 24, priorityFeeGwei: tx.priorityFeeGwei, nonce: tx.nonce, gasLimit: EVMHelper.defaultETHTransferGasUnit),
                    utxos: [],
                    memo: nil,
                    swapPayload: nil
                )
                
                return keysignPayload
            } else {
                
                let keysignPayload = KeysignPayload(
                    coin: tx.coin,
                    toAddress: tx.toAddress,
                    toAmount: tx.amountInTokenWeiInt64, // The amount must be in the token decimals
                    chainSpecific: BlockChainSpecific.ERC20(maxFeePerGasGwei: Int64(tx.gas) ?? 42, priorityFeeGwei: tx.priorityFeeGwei, nonce: tx.nonce, gasLimit: EVMHelper.defaultERC20TransferGasUnit, contractAddr: tx.coin.contractAddress),
                    utxos: [],
                    memo: nil,
                    swapPayload: nil
                )
                
                return keysignPayload
            }
        } else if tx.coin.chain == .thorChain {

            guard let accountNumberString = THORChainAccount?.accountNumber, let intAccountNumber = UInt64(accountNumberString) else {
                print("We need the ACCOUNT NUMBER to broadcast a transaction")
                self.errorMessage = "failToGetAccountNumber"
                showAlert = true
                isLoading = false
                return nil
            }
            
            var sequenceString = "0"
            if THORChainAccount?.sequence != nil {
                sequenceString = THORChainAccount!.sequence!
            }
            guard  let intSequence = UInt64(sequenceString) else {
                print("We need the SEQUENCE to broadcast a transaction")
                self.errorMessage = "failToGetSequenceNo"
                showAlert = true
                isLoading = false
                return nil
            }
            
            let keysignPayload = KeysignPayload(
                coin: tx.coin,
                toAddress: tx.toAddress,
                toAmount: tx.amountInSats,
                chainSpecific: BlockChainSpecific.THORChain(accountNumber: intAccountNumber, sequence: intSequence),
                utxos: [],
                memo: tx.memo, swapPayload: nil
            )
            
            return keysignPayload
            
        } else if tx.coin.chain == .gaiaChain {

            guard let accountNumberString = CosmosChainAccount?.accountNumber, let intAccountNumber = UInt64(accountNumberString) else {
                self.errorMessage = "failToGetAccountNumber"
                showAlert = true
                isLoading = false
                return nil
            }
            
            var sequenceString = "0"
            if CosmosChainAccount?.sequence != nil {
                sequenceString = CosmosChainAccount!.sequence!
            }
            guard  let intSequence = UInt64(sequenceString) else {
                print("We need the SEQUENCE to broadcast a transaction")
                self.errorMessage = "failToGetSequenceNo"
                showAlert = true
                isLoading = false
                return nil
            }
            
            let keysignPayload = KeysignPayload(
                coin: tx.coin,
                toAddress: tx.toAddress,
                toAmount: tx.amountInCoinDecimal,
                chainSpecific: BlockChainSpecific.Cosmos(accountNumber: intAccountNumber, sequence: intSequence, gas: 7500),
                utxos: [],
                memo: tx.memo, swapPayload: nil
            )
            
            return keysignPayload
            
        } else if tx.coin.chain == .solana {
            guard let recentBlockHash = sol.recentBlockHash else {
                print("We need the recentBlockHash to broadcast a transaction")
                self.errorMessage = "failToGetRecentBlockHash"
                showAlert = true
                isLoading = false
                return nil
            }
            
            let keysignPayload = KeysignPayload(
                coin: tx.coin,
                toAddress: tx.toAddress,
                toAmount: tx.amountInLamports,
                chainSpecific: BlockChainSpecific.Solana(recentBlockHash: recentBlockHash, priorityFee: 0),
                utxos: [],
                memo: tx.memo, swapPayload: nil
            )
            
            return keysignPayload
            
        }
        return nil
    }
}
