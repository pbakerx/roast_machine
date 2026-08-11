//
//  RoastMachineApp.swift
//  RoastMachine
//
//  Entry point. Snap a photo, pick a mode, get roasted (or adored) out loud.
//

import SwiftUI

@main
struct RoastMachineApp: App {
    @StateObject private var store = StoreManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .task {
                    await store.loadProducts()
                    await store.refreshEntitlements()
                    store.recordLaunch()
                }
        }
    }
}
