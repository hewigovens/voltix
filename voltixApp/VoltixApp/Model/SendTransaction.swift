//
//  TransactionDetailsViewModel.swift
//  VoltixApp
//
//  Created by Enrique Souza Soares on 13/02/2024.
//

import Foundation

class SendTransaction: ObservableObject, Hashable {
    
    init() {
        self.fromAddress = ""
        self.toAddress = ""
        self.amount = ""
        self.memo = ""
        self.gas = ""
    }
    
    init(fromAddress: String, toAddress: String, amount: String, memo: String, gas: String) {
        self.fromAddress = fromAddress
        self.toAddress = toAddress
        self.amount = amount
        self.memo = memo
        self.gas = gas
    }
    
    static func == (lhs: SendTransaction, rhs: SendTransaction) -> Bool {
        return lhs.fromAddress == rhs.fromAddress &&
        lhs.toAddress == rhs.toAddress &&
        lhs.amount == rhs.amount &&
        lhs.memo == rhs.memo &&
        lhs.gas == rhs.gas
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(fromAddress)
        hasher.combine(toAddress)
        hasher.combine(amount)
        hasher.combine(memo)
        hasher.combine(gas)
    }
    
    //18cBEMRxXHqzWWCxZNtU91F5sbUNKhL5PX
    @Published var fromAddress: String = ""
    @Published var toAddress: String = ""
    @Published var amount: String = ""
    @Published var memo: String = ""
    @Published var gas: String = ""
    
    var amountDecimal: Double {
        let amountString = amount.replacingOccurrences(of: ",", with: ".")
        return Double(amountString) ?? 0
    }
    
    var gasDecimal: Double {
        let gasString = gas.replacingOccurrences(of: ",", with: ".")
        return Double(gasString) ?? 0
    }
    
    func parseCryptoURI(_ uri: String) {
        guard let url = URLComponents(string: uri) else {
            print("Invalid URI")
            return
        }
        
        // Use the path for the address if the host is nil, which can be the case for some URIs.
        toAddress = url.host ?? url.path
        
        url.queryItems?.forEach { item in
            switch item.name {
            case "amount":
                amount = item.value ?? ""
            case "label", "message":
                // For simplicity, appending label and message to memo, separated by spaces
                if let value = item.value, !value.isEmpty {
                    memo += (memo.isEmpty ? "" : " ") + value
                }
            default:
                print("Unknown query item: \(item.name)")
            }
        }
    }
}
