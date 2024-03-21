//
//  SendCryptoKeysignView.swift
//  VoltixApp
//
//  Created by Amol Kumar on 2024-03-17.
//

import SwiftUI

struct SendCryptoKeysignView: View {
    @ObservedObject var viewModel: SendCryptoViewModel
    
    @State var isSigning = true
    @State var didSwitch = false
    
    var body: some View {
        if isSigning {
            signingView
        } else {
            errorView
        }
    }
    
    var signingView: some View {
        VStack {
            Spacer()
            signingAnimation
            Spacer()
            wifiInstructions
        }
        .onTapGesture {
            viewModel.moveToNextView()
        }
    }
    
    var errorView: some View {
        VStack(spacing: 22) {
            Spacer()
            errorMessage
            Spacer()
            bottomBar
        }
    }
    
    var signingAnimation: some View {
        VStack(spacing: 32) {
            Text(NSLocalizedString("signing", comment: "Signing"))
                .font(.body16MenloBold)
                .foregroundColor(.neutral0)
            animation
        }
    }
    
    var animation: some View {
        HStack {
            Circle()
                .frame(width: 20, height: 20)
                .foregroundColor(.loadingBlue)
                .offset(x: didSwitch ? 0 : 28)
            
            Circle()
                .frame(width: 20, height: 20)
                .foregroundColor(.loadingGreen)
                .offset(x: didSwitch ? 0 : -28)
        }
        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: didSwitch)
        .onAppear {
            didSwitch.toggle()
        }
    }
    
    var wifiInstructions: some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi")
                .font(.title30MenloBold)
                .foregroundColor(.turquoise600)
            
            Text(NSLocalizedString("devicesOnSameWifi", comment: "Keep devices on the same WiFi Network with VOLTIX open"))
                .font(.body12Menlo)
                .foregroundColor(.neutral0)
                .frame(maxWidth: 250)
        }
        .padding(.bottom, 100)
    }
    
    var errorMessage: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title80Menlo)
                .symbolRenderingMode(.multicolor)
            
            Text(NSLocalizedString("signInErrorTryAgain", comment: "Signing Error. Please try again."))
                .font(.body16MenloBold)
                .foregroundColor(.neutral0)
                .frame(maxWidth: 200)
                .multilineTextAlignment(.center)
        }
    }
    
    var bottomBar: some View {
        VStack {
            sameWifiInstruction
            tryAgainButton
        }
    }
    
    var sameWifiInstruction: some View {
        Text(NSLocalizedString("sameWifiEntendedInstruction", comment: "Keep devices on the same WiFi Network, correct vault and pair devices. Make sure no other devices are running Voltix."))
            .font(.body12Menlo)
            .foregroundColor(.neutral0)
            .padding(.horizontal, 50)
            .multilineTextAlignment(.center)
    }
    
    var tryAgainButton: some View {
        FilledButton(title: "tryAgain")
            .padding(40)
    }
}

#Preview {
    ZStack {
        Color.blue800
            .ignoresSafeArea()
        
        SendCryptoKeysignView(viewModel: SendCryptoViewModel())
    }
}
