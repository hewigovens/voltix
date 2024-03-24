//
//  CreateVaultView.swift
//  VoltixApp
//
//  Created by Amol Kumar on 2024-03-06.
//

import SwiftUI

struct CreateVaultView: View {
    
    var body: some View {
        ZStack {
            Background()
            view
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationBackButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationHelpButton()
            }
        }
    }
    
    var view: some View {
        VStack {
            Spacer()
            VoltixLogo(isAnimated: false)
            Spacer()
            buttons
        }
    }
    
    var buttons: some View {
        VStack(spacing: 20) {
            newVaultButton
            importVaultButton
        }
        .padding(40)
    }
    
    var newVaultButton: some View {
        NavigationLink {
            SetupVaultView(tssType: .Keygen)
        } label: {
            FilledButton(title: "createNewVault")
        }
    }
    
    var importVaultButton: some View {
        NavigationLink {
            ImportWalletView2()
        } label: {
            OutlineButton(title: "importExistingVault")
        }
    }
}

#Preview {
    CreateVaultView()
}
