//
//  VoltixApp.swift
//  VoltixApp
//

import Mediator
import SwiftData
import SwiftUI
import WalletCore

@main
struct VoltixApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    @StateObject var coinViewModel = CoinViewModel()
    @StateObject var applicationState = ApplicationState.shared
    @StateObject var vaultDetailViewModel = VaultDetailViewModel()
    @StateObject var tokenSelectionViewModel = TokenSelectionViewModel()
    @StateObject var accountViewModel = AccountViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coinViewModel)
                .environmentObject(applicationState) // Shared monolithic mutable state
                .environmentObject(vaultDetailViewModel)
                .environmentObject(tokenSelectionViewModel)
                .environmentObject(accountViewModel)
        }
        .modelContainer(sharedModelContainer)
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Vault.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
