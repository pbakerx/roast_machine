//
//  PaywallView.swift
//  RoastMachine
//
//  Small à-la-carte unlocks (freemium). No subscriptions.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header

                    ForEach(store.products, id: \.id) { product in
                        productRow(product)
                    }

                    if store.products.isEmpty {
                        if store.isLoadingProducts || !store.didAttemptLoad {
                            ProgressView("Loading store…")
                                .padding(.top, 40)
                        } else {
                            emptyState
                        }
                    }

                    Button("Restore Purchases") {
                        Task { await store.restore() }
                    }
                    .font(.subheadline)
                    .padding(.top, 8)

                    Text("Classic Roast and Nature Documentary are always free. Unlocks are one-time purchases, not subscriptions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding()
            }
            .background(
                LinearGradient(colors: [.black, .orange.opacity(0.2), .black],
                               startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            )
            .navigationTitle("Unlock More")
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

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 44))
                .foregroundStyle(.yellow)
            Text("Go Full Savage")
                .font(.title.bold())
            Text("Unlock every persona and the premium voices.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    private func productRow(_ product: Product) -> some View {
        let owned = store.ownedProductIDs.contains(product.id)
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.displayName).font(.headline)
                Text(product.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if owned {
                Label("Owned", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
            } else {
                Button {
                    Task { await store.purchase(product) }
                } label: {
                    Text(product.displayPrice)
                        .font(.subheadline.bold())
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(.orange, in: Capsule())
                        .foregroundStyle(.white)
                }
                .disabled(store.purchaseInFlight)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}
