//
//  KeygenPeerDiscoveryViewModel.swift
//  VoltixApp
//

import Foundation
import Mediator
import OSLog
import SwiftUI

enum PeerDiscoveryStatus {
    case WaitingForDevices
    case Summary
    case Keygen
    case Failure
}

class KeygenPeerDiscoveryViewModel: ObservableObject {
    private let logger = Logger(subsystem: "peers-discory-viewmodel", category: "communication")
    var tssType: TssType
    var vault: Vault
    var participantDiscovery: ParticipantDiscovery?
    var encryptionKeyHex: String?
    
    @Published var status = PeerDiscoveryStatus.WaitingForDevices
    @Published var serviceName = ""
    @Published var errorMessage = ""
    @Published var sessionID = ""
    @Published var localPartyID = ""
    @Published var selections = Set<String>()
    @Published var serverAddr = "http://127.0.0.1:18080"
    @Published var vaultDetail = String.empty
    
    private let mediator = Mediator.shared
    
    init() {
        self.tssType = .Keygen
        self.vault = Vault(name: "New Vault")
        self.status = .WaitingForDevices
        self.participantDiscovery = nil
        self.encryptionKeyHex = Encryption.getEncryptionKey()
        if VoltixRouter.IsRouterEnabled {
            serverAddr = Endpoint.voltixRouter
        }
    }
    
    func setData(vault: Vault, tssType: TssType, participantDiscovery: ParticipantDiscovery) {
        self.vault = vault
        self.tssType = tssType
        self.participantDiscovery = participantDiscovery
        
        if self.sessionID.isEmpty {
            self.sessionID = UUID().uuidString
        }
        
        if self.serviceName.isEmpty {
            self.serviceName = "VoltixApp-" + Int.random(in: 1 ... 1000).description
        }
        
        if self.vault.hexChainCode.isEmpty {
            guard let chainCode = Utils.getChainCode() else {
                self.logger.error("fail to get chain code")
                self.status = .Failure
                return
            }
            self.vault.hexChainCode = chainCode
        }
        
        if !self.vault.localPartyID.isEmpty {
            self.localPartyID = vault.localPartyID
        } else {
            self.localPartyID = Utils.getLocalDeviceIdentity()
            self.vault.localPartyID = self.localPartyID
        }
        self.selections.insert(self.localPartyID)
        
    }
    
    
    func startDiscovery() {
        self.mediator.start(name: self.serviceName)
        self.logger.info("mediator server started")
        self.startSession()
        self.participantDiscovery?.getParticipants(serverAddr: self.serverAddr, 
                                                   sessionID: self.sessionID,
                                                   localParty: self.localPartyID,
                                                   pubKeyECDSA: vault.pubKeyECDSA)
    }
    
    func showSummary() {
        self.status = .Summary
    }
    
    func startKeygen() {
        self.startKeygen(allParticipants: self.selections.map { $0 })
        self.status = .Keygen
        self.participantDiscovery?.stop()
    }
    
    func stopMediator() {
        self.logger.info("mediator server stopped")
        self.participantDiscovery?.stop()
        self.mediator.stop()
    }
    
   
    private func startSession() {
        let urlString = "\(self.serverAddr)/\(self.sessionID)"
        let body = [self.localPartyID]
        
        Utils.sendRequest(urlString: urlString, method: "POST",headers:TssHelper.getKeygenRequestHeader(), body: body) { success in
            if success {
                self.logger.info("Started session successfully.")
            } else {
                self.logger.info("Failed to start session.")
            }
        }
    }
    
    private func startKeygen(allParticipants: [String]) {
        let urlString = "\(self.serverAddr)/start/\(self.sessionID)"
        
        Utils.sendRequest(urlString: urlString, method: "POST",headers:TssHelper.getKeygenRequestHeader(), body: allParticipants) { _ in
            self.logger.info("kicked off keygen successfully")
        }
    }
    
    func getQrImage(size: CGFloat) -> Image {
        guard let encryptionKeyHex else {return Image(systemName: "xmark")}
        do {
            let jsonEncoder = JSONEncoder()
            var data: Data
            switch tssType {
            case .Keygen:
                let km = keygenMessage(sessionID: sessionID,
                                       hexChainCode: vault.hexChainCode,
                                       serviceName: serviceName,
                                       encryptionKeyHex: encryptionKeyHex,
                                       useVoltixRouter: VoltixRouter.IsRouterEnabled)
                data = try jsonEncoder.encode(PeerDiscoveryPayload.Keygen(km))
            case .Reshare:
                let reshareMsg = ReshareMessage(sessionID: sessionID,
                                                hexChainCode: vault.hexChainCode,
                                                serviceName: serviceName,
                                                pubKeyECDSA: vault.pubKeyECDSA,
                                                oldParties: vault.signers,
                                                encryptionKeyHex: encryptionKeyHex,
                                                useVoltixRouter: VoltixRouter.IsRouterEnabled)
                data = try jsonEncoder.encode(PeerDiscoveryPayload.Reshare(reshareMsg))
            }
            return Utils.getQrImage(data: data, size: size)
        } catch {
            logger.error("fail to encode keygen message to json,error:\(error.localizedDescription)")
            return Image(systemName: "xmark")
        }
    }
    
    
}
