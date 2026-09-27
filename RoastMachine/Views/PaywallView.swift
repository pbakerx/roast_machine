//
//  PaywallView.swift
//  RoastMachine
//
//  The Box Office: three ticket packs, one ticket per show. No subscriptions.
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

                    if store.products.isEmpty {
                        if store.isLoadingProducts || !store.didAttemptLoad {
                            ProgressView("Opening the Box Office…").padding(.top, 30)
                        } else {
                            emptyState
                        }
                    } else {
                        VStack(spacing: 12) {
                            ForEach(StoreManager.packs) { pack in
                                if let product = store.product(for: pack) {
                                    packRow(pack, product)
                                }
                            }
                        }
                    }

                    VStack(spacing: 6) {
                        Text("1 ticket = 1 roast or 1 hype, with any comedian.")
                        Text("Replays and shares are free. Tickets never expire.")
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)

                    lineup

                    Text("Your first roast and your first hype are on the house. Packs are one-time purchases, not a subscription.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Link("Privacy & AI Policy", destination: AppConfig.privacyPolicyURL)
                        .font(.caption)
                        .tint(.white.opacity(0.6))
                }
                .padding()
            }
            .background(
                LinearGradient(colors: [.black, Color(red: 0.35, green: 0.08, blue: 0.02), .black],
                               startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            )
            .navigationTitle("Box Office")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                if store.products.isEmpty { await store.loadProducts() }
            }
            .alert("Box Office", isPresented: purchaseErrorBinding) {
                Button("OK") { store.lastError = nil }
            } message: {
                Text(store.lastError ?? "")
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("🎟️")
                .font(.system(size: 56))
                .shadow(color: .orange.opacity(0.8), radius: 18)
            Text("GET MORE SHOWS")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .tracking(1)
            Text(balanceLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var balanceLine: String {
        let n = store.tickets
        return n == 0 ? "You're out of tickets." : "You have \(n) ticket\(n == 1 ? "" : "s")."
    }

    private func packRow(_ pack: StoreManager.Pack, _ product: Product) -> some View {
        let featured = pack.badge != nil
        return Button {
            Task { await store.purchase(product) }
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(pack.name.uppercased())
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .tracking(1)
                        if let badge = pack.badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .tracking(1)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(.yellow, in: Capsule())
                                .foregroundStyle(.black)
                        }
                    }
                    Text("\(pack.tickets) shows · \(perShow(product, pack)) each")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18).padding(.vertical, 16)
            .background(
                featured
                    ? AnyShapeStyle(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                    : AnyShapeStyle(Color.white.opacity(0.09)),
                in: RoundedRectangle(cornerRadius: 20)
            )
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(featured ? 0.4 : 0.15), lineWidth: 1))
            .shadow(color: featured ? .orange.opacity(0.5) : .clear, radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(store.purchaseInFlight)
    }

    private func perShow(_ product: Product, _ pack: StoreManager.Pack) -> String {
        let each = product.price / Decimal(pack.tickets)
        return each.formatted(product.priceFormatStyle)
    }

    /// The comedians, shown off like a poster.
    private var lineup: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 8)], spacing: 8) {
            ForEach(RoastMode.all) { mode in
                Image(systemName: mode.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(mode.theme.primary)
                    .shadow(color: mode.theme.primary.opacity(0.7), radius: 6)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel(mode.title)
            }
        }
    }

    /// Purchase errors show as an alert; the empty-store state is inline.
    private var purchaseErrorBinding: Binding<Bool> {
        Binding(
            get: { store.lastError != nil && !store.products.isEmpty },
            set: { if !$0 { store.lastError = nil } }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "ticket")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("The Box Office is closed")
                .font(.headline)
            Text("We couldn't reach the App Store. Check your connection and try again.")
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
        .padding(.top, 20)
    }
}
