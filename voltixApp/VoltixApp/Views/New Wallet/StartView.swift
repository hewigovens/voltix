//
//  StartView.swift
//  VoltixApp
//

import SwiftUI

struct StartView: View {
    @Binding var presentationStack: Array<CurrentScreen>
    
    var body: some View {
        ScrollView{
            VStack{
                Spacer()
                Button("Import Wallet >") {
                    presentationStack.append(.importWallet)
                }
                Button("New Wallet >") {
                    presentationStack.append(.newWalletInstructions)
                }
                Button("Join Keygen >") {
                    presentationStack = [.joinKeygen]
                }
                Spacer()
            }
        }.navigationBarBackButtonHidden()
    }
}

#Preview {
    StartView(presentationStack: .constant([]))
}