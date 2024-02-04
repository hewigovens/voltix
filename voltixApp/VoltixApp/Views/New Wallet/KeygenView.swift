//
//  Keygen.swift
//  VoltixApp
//

import SwiftUI
import Tss
import OSLog
import Mediator
import Foundation
import SwiftData

private let logger = Logger(subsystem: "keygen", category: "tss")
struct KeygenView: View {
    @Environment(\.modelContext) private var context
    enum KeygenStatus{
        case CreatingInstance
        case KeygenECDSA
        case KeygenEdDSA
        case KeygenFinished
        case KeygenFailed
    }
    
    @State private var currentStatus = KeygenStatus.CreatingInstance
    @Binding var presentationStack: Array<CurrentScreen>
    let keygenCommittee: [String]
    let mediatorURL: String
    let sessionID: String
    private let localPartyKey = UIDevice.current.name
    @State private var keygenInProgressECDSA = false
    @State private var pubKeyECDSA: String? = nil
    @State private var keygenInProgressEDDSA = false
    @State private var pubKeyEdDSA: String? = nil
    @State private var keygenDone = false
    @State private var tssService: TssServiceImpl? = nil
    @State private var failToCreateTssInstance = false
    @State private var tssMessenger: TssMessengerImpl? = nil
    @State private var stateAccess: LocalStateAccessorImpl? = nil
    @State private var keygenError: String? = nil
    @State private var vault = Vault(name: "new vault")
    
    var body: some View {
        VStack{
            switch currentStatus {
            case .CreatingInstance:
                HStack{
                    Text("creating tss instance")
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.blue)
                        .padding(2)
                }
            case .KeygenECDSA:
                HStack{
                    if keygenInProgressECDSA {
                        Text("Generating ECDSA key")
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.blue)
                            .padding(2)
                    }
                    if pubKeyECDSA != nil  {
                        Text("ECDSA pubkey:\(pubKeyECDSA ?? "")")
                        Image(systemName: "checkmark").foregroundColor(/*@START_MENU_TOKEN@*/.blue/*@END_MENU_TOKEN@*/)
                    }
                }
            case .KeygenEdDSA:
                HStack{
                    if keygenInProgressEDDSA {
                        Text("Generating EdDSA key")
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.blue)
                            .padding(2)
                    }
                    if pubKeyEdDSA != nil  {
                        Text("EdDSA pubkey:\(pubKeyEdDSA ?? "")")
                        Image(systemName: "checkmark").foregroundColor(/*@START_MENU_TOKEN@*/.blue/*@END_MENU_TOKEN@*/)
                    }
                }
            case .KeygenFinished:
                FinishedTSSKeygenView(presentationStack: $presentationStack, vault: self.vault)                .onAppear(){
                    // add the vault to modelcontext
                    self.context.insert(self.vault)
                }
            case .KeygenFailed:
                Text("Sorry keygen failed, you can retry it,error:\(keygenError ?? "")")
                    .navigationBarBackButtonHidden(false)
            }
        }.task {
            Task.detached(priority: .high) {
                // Create keygen instance, it takes time to generate the preparams
                tssMessenger = TssMessengerImpl(mediatorUrl: self.mediatorURL, sessionID: self.sessionID)
                stateAccess = LocalStateAccessorImpl(vault: self.vault)
                var err: NSError?
                self.tssService = TssNewService(tssMessenger, stateAccess, &err)
                if let err {
                    logger.error("Failed to create TSS instance, error: \(err.localizedDescription)")
                    failToCreateTssInstance = true
                    return
                }
                
                // Keep polling for messages
                Task {
                    repeat {
                        pollInboundMessages()
                        try await Task.sleep(nanoseconds: 1_000_000_000) // Back off 1s
                    } while self.tssService != nil
                }
                
                self.currentStatus = .KeygenECDSA
                keygenInProgressECDSA = true
                let keygenReq = TssKeygenRequest()
                keygenReq.localPartyID = localPartyKey
                keygenReq.allParties = keygenCommittee.joined(separator: ",")
                
                do {
                    if let tssService = self.tssService {
                        let ecdsaResp = try tssService.keygenECDSA(keygenReq)
                        pubKeyECDSA = ecdsaResp.pubKey
                        self.vault.pubKeyECDSA = ecdsaResp.pubKey
                    }
                } catch {
                    logger.error("Failed to create ECDSA key, error: \(error.localizedDescription)")
                    self.currentStatus = .KeygenFailed
                    self.keygenError = error.localizedDescription
                    return
                }
                
                self.currentStatus = .KeygenEdDSA
                keygenInProgressEDDSA = true
                try await Task.sleep(nanoseconds: 1_000_000_000) // Sleep one sec to allow other parties to get in the same step
                
                do {
                    if let tssService = self.tssService {
                        let eddsaResp = try tssService.keygenEDDSA(keygenReq)
                        pubKeyEdDSA = eddsaResp.pubKey
                        self.vault.pubKeyEdDSA = eddsaResp.pubKey
                    }
                } catch {
                    logger.error("Failed to create EdDSA key, error: \(error.localizedDescription)")
                    self.currentStatus = .KeygenFailed
                    self.keygenError = error.localizedDescription
                    return
                }
                
                self.currentStatus = .KeygenFinished
            }
        }
    }
    
    private func pollInboundMessages() {
        let urlString = "\(self.mediatorURL)/message/\(self.sessionID)/\(self.localPartyKey)"
        guard let url = URL(string: urlString) else {
            logger.error("URL can't be constructed from: \(urlString)")
            return
        }
        
        let req = URLRequest(url: url)
        URLSession.shared.dataTask(with: req) { data, response, error in
            if let error = error {
                logger.error("Failed to start session, error: \(error)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response")
                return
            }
            
            if httpResponse.statusCode == 404 {
                // No messages yet
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                logger.error("Invalid response code")
                return
            }
            
            guard let data = data else {
                logger.error("No participants available yet")
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let msgs = try decoder.decode([Message].self, from: data)
                
                for msg in msgs {
                    logger.debug("Got message from: \(msg.from), to: \(msg.to)")
                    try self.tssService?.applyData(msg.body)
                }
            } catch {
                logger.error("Failed to decode response to JSON, data: \(data), error: \(error)")
            }
        }.resume()
    }
    
    final class TssMessengerImpl : NSObject,TssMessengerProtocol {
        let mediatorUrl: String
        let sessionID: String
        
        init(mediatorUrl: String, sessionID: String) {
            self.mediatorUrl = mediatorUrl
            self.sessionID = sessionID
        }
        
        func send(_ fromParty: String?, to: String?, body: String?) throws {
            guard let fromParty else {
                logger.error("from is nil")
                return
            }
            guard let to else {
                logger.error("to is nil")
                return
            }
            guard let body else {
                logger.error("body is nil")
                return
            }
            logger.info("from:\(fromParty),to:\(to)")
            let urlString = "\(self.mediatorUrl)/message/\(self.sessionID)"
            let url = URL(string: urlString)
            guard let url else{
                logger.error("URL can't be construct from: \(urlString)")
                return
            }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")
            let msg = Message(session_id: sessionID,from: fromParty, to: [to],body: body)
            do{
                let jsonEncode = JSONEncoder()
                let encodedBody = try jsonEncode.encode(msg)
                req.httpBody = encodedBody
            } catch {
                logger.error("fail to encode body into json string,\(error)")
                return
            }
            URLSession.shared.dataTask(with: req){data,resp,err in
                if let err {
                    logger.error("fail to send message,error:\(err)")
                    return
                }
                guard let resp = resp as? HTTPURLResponse, (200...299).contains(resp.statusCode) else {
                    logger.error("invalid response code")
                    return
                }
                logger.debug("send message to mediator server successfully")
            }.resume()
        }
    }
    
    final class LocalStateAccessorImpl : NSObject, TssLocalStateAccessorProtocol {
        struct RuntimeError : LocalizedError{
            let description: String
            init(_ description: String) {
                self.description = description
            }
            var errorDescription: String? {
                description
            }
        }
        let vault :Vault
        init(vault: Vault) {
            self.vault = vault
        }
        
        func getLocalState(_ pubKey: String?, error: NSErrorPointer) -> String {
            guard let pubKey else {
                return ""
            }
            for share in self.vault.keyshares {
                if share.pubkey == pubKey {
                    return share.keyshare
                }
            }
            return ""
        }
        
        func saveLocalState(_ pubkey: String?, localState: String?) throws {
            guard let pubkey else{
                throw RuntimeError("pubkey is nil")
            }
            guard let localState else {
                throw RuntimeError("localstate is nil")
            }
            vault.keyshares.append(KeyShare(pubkey: pubkey, keyshare: localState))
        }
    }
}
#Preview ("keygen") {
    KeygenView(presentationStack: .constant([]), keygenCommittee: [], mediatorURL:"", sessionID: "")
}