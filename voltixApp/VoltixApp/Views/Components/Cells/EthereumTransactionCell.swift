//
//  EthereumTransactionCell.swift
//  VoltixApp
//
//  Created by Amol Kumar on 2024-03-27.
//

import SwiftUI

struct EthereumTransactionCell: View {
    let transaction: EtherscanAPITransactionDetail
    let myAddress: String
    @ObservedObject var etherScanService: EtherScanService
    
    @State var isSent = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            transactionIDField
            Separator()
            fromField
            Separator()
            toField
            Separator()
            summary
        }
        .padding(16)
        .background(Color.blue600)
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .onAppear {
            setData()
        }
    }
    
    var transactionIDField: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            txHash
        }
    }
    
    var header: some View {
        HStack(spacing: 12) {
            Image(systemName: isSent ? "arrow.up.circle" : "arrow.down.circle")
            Text(NSLocalizedString("transactionID", comment: "Transaction ID"))
        }
        .font(.body20MontserratSemiBold)
        .foregroundColor(.neutral0)
    }
    
    var txHash: some View {
        let hash = transaction.hash ?? ""
        let url = Endpoint.ethereumLabelTxHash(hash)
        
        return Link(destination: URL(string: url)!) {
            Text(hash)
                .font(.body13Menlo)
                .foregroundColor(.turquoise600)
                .underline()
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    var fromField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fromTitle
            fromAddress
        }
    }
    
    var fromTitle: some View {
        Text(NSLocalizedString("from", comment: ""))
            .font(.body20MontserratSemiBold)
            .foregroundColor(.neutral0)
    }
    
    var fromAddress: some View {
        Text(transaction.from)
            .font(.body13Menlo)
            .foregroundColor(.turquoise600)
    }
    
    var toField: some View {
        VStack(alignment: .leading, spacing: 8) {
            toTitle
            toAddress
        }
    }
    
    var toTitle: some View {
        Text(NSLocalizedString("to", comment: ""))
            .font(.body20MontserratSemiBold)
            .foregroundColor(.neutral0)
    }
    
    var toAddress: some View {
        Text(transaction.to)
            .font(.body13Menlo)
            .foregroundColor(.turquoise600)
    }
    
    var summary: some View {
        VStack(spacing: 12) {
            amountCell
            Separator()
            feesCell
        }
    }
    
    var amountCell: some View {
        let decimals: Int = Int(transaction.tokenDecimal ?? "\(EVMHelper.ethDecimals)") ?? EVMHelper.ethDecimals
        let etherValue = etherScanService.convertToEther(fromWei: transaction.value, decimals)
        let tokenSymbol = transaction.tokenSymbol ?? "ETH"
        
        return getSummaryCell(title: "amount", value: "\(etherValue) \(tokenSymbol)")
    }
    
    var feesCell: some View {
        let feeDisplay = etherScanService.calculateTransactionFee(
            gasUsed: transaction.gasUsed ?? "",
            gasPrice: transaction.gasPrice
        )
        
        return getSummaryCell(title: "gas", value: feeDisplay)
    }
    
    private func setData() {
        isSent = myAddress.lowercased() != transaction.to.lowercased()
    }
    
    private func getSummaryCell(title: String, value: String) -> some View {
        HStack {
            Text(NSLocalizedString(title, comment: ""))
            Spacer()
            Text(value)
        }
        .frame(height: 32)
        .font(.body16MenloBold)
        .foregroundColor(.neutral0)
    }
}