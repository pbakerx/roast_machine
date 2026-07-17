//
//  RootView.swift
//  RoastMachine
//

import SwiftUI

struct RootView: View {
    @StateObject private var engine = RoastEngine()

    var body: some View {
        NavigationStack {
            HomeView()
                .environmentObject(engine)
                .navigationDestination(isPresented: readyBinding) {
                    ResultView()
                        .environmentObject(engine)
                }
        }
    }

    /// Push the result screen once we've started producing a roast.
    private var readyBinding: Binding<Bool> {
        Binding(
            get: {
                switch engine.phase {
                case .idle: return false
                default: return true
                }
            },
            set: { showing in
                if !showing { engine.reset() }
            }
        )
    }
}

#Preview {
    RootView()
        .environmentObject(StoreManager())
}
