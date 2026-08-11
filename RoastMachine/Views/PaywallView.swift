//
//  PaywallView.swift
//  RoastMachine
//
//  One flashy $1.99 unlock for the whole machine. No subscriptions.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var flamePulse = false

    private var allModesProduct: Product? {
        store.product(for: StoreManager.ProductID.allModes)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    modeGrid

                    if let product = allModesProduct {
                        buyButton(product)
                    } else if store.isLoadingProducts || !store.didAttemptLoad {
                        ProgressView("Loading store…")
                            .padding(.top, 30)
                    } else {
                        emptyState
                    }

                    Button("Restore Purchases") {
                        Task { await store.restore() }
                    }
                    .font(.subheadline)
                    .tint(.white.opacity(0.8))

                    Text("Classic Roast is free forever. This is a one-time unlock — not a subscription, no nonsense.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .background(
                LinearGradient(colors: [.black, Color(red: 0.35, green: 0.08, blue: 0.02), .black],
                               startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            )
            .navigationTitle("Unlock the Machine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                if store.products.isEmpty {
                    await store.loadProducts()
                }
            }
            .alert("Store", isPresented: purchaseErrorBinding) {
                Button("OK") { store.lastError = nil }
            } message: {
                Text(store.lastError ?? "")
            }
            .onAppear { flamePulse = true }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "flame.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(colors: [.yellow, .orange, .red],
                                   startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: .orange.opacity(0.8), radius: flamePulse ? 26 : 10)
                .scaleEffect(flamePulse ? 1.06 : 0.96)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: flamePulse)

            Text("THE WHOLE MACHINE")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .tracking(1)
            Text("Every persona. Every voice. Every scene.\nTwo bucks. Forever.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    /// Every locked persona, shown off like a lineup poster.
    private var modeGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
            ForEach(RoastMode.premium) { mode in
                VStack(spacing: 6) {
                    Image(systemName: mode.systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(mode.theme.primary)
                        .shadow(color: mode.theme.primary.opacity(0.7), radius: 6)
                    Text(mode.title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, minHeight: 74)
                .padding(6)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(mode.theme.primary.opacity(0.35), lineWidth: 1)
                )
            }
        }
    }

    private func buyButton(_ product: Product) -> some View {
        let owned = store.ownedProductIDs.contains(product.id)
        return Group {
            if owned {
                Label("Unlocked — go be terrible", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .padding()
            } else {
                Button {
                    Task { await store.purchase(product) }
                } label: {
                    HStack {
                        Image(systemName: "bolt.fill")
                        Text("Unlock Everything — \(product.displayPrice)")
                    }
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [.orange, .red],
                                       startPoint: .leading, endPoint: .trailing),
                        in: Capsule()
                    )
                    .foregroundStyle(.white)
                    .shadow(color: .orange.opacity(0.6), radius: 12, y: 4)
                }
                .disabled(store.purchaseInFlight)
            }
        }
    }

    /// Only surface purchase/restore errors as an alert; the empty-store hint is
    /// shown inline so we don't double up on the "no products" message.
    private var purchaseErrorBinding: Binding<Bool> {
        Binding(
            get: { store.lastError != nil && !store.products.isEmpty },
            set: { if !$0 { store.lastError = nil } }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cart.badge.questionmark")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Store unavailable")
                .font(.headline)
            Text("In development, enable the local test store: Edit Scheme ▸ Run ▸ Options ▸ StoreKit Configuration ▸ Subscriptions.storekit.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await store.loadProducts() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.top, 4)
        }
        .padding(.top, 30)
    }
}
