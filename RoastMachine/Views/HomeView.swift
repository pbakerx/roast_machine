//
//  HomeView.swift
//  RoastMachine
//
//  Pick/snap a photo, choose a mode, hit the button.
//

import SwiftUI
import PhotosUI

struct HomeView: View {
    @EnvironmentObject private var engine: RoastEngine
    @EnvironmentObject private var store: StoreManager

    @State private var pickedImage: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var showLivePortrait = false
    @State private var selectedMode: RoastMode = RoastMode.free[0]
    @State private var showPaywall = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                photoArea
                modeSection
                goButton
                Color.clear.frame(height: 20)
            }
            .padding(.horizontal)
        }
        .background(backgroundGradient.ignoresSafeArea())
        .navigationTitle("Roast Machine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showPaywall = true
                } label: {
                    Image(systemName: "crown.fill").foregroundStyle(.yellow)
                }
            }
        }
        .fullScreenCover(isPresented: $showLivePortrait) {
            LivePortraitView { image in pickedImage = image }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView().environmentObject(store)
        }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    pickedImage = image
                }
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 6) {
            Text("Feed it a face.")
                .font(.largeTitle.bold())
            Text("Get roasted out loud in seconds.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var photoArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .frame(height: 300)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                )

            if let image = pickedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)

                    Button {
                        showLivePortrait = true
                    } label: {
                        Label("Live Portrait", systemImage: "camera.viewfinder")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 22).padding(.vertical, 12)
                            .background(selectedMode.tint, in: Capsule())
                            .foregroundStyle(.white)
                    }

                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Choose from Library", systemImage: "photo")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(.white.opacity(0.12), in: Capsule())
                    }
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if pickedImage != nil {
                HStack(spacing: 10) {
                    Button {
                        showLivePortrait = true
                    } label: {
                        Image(systemName: "camera.viewfinder")
                            .padding(10)
                            .background(.black.opacity(0.5), in: Circle())
                            .foregroundStyle(.white)
                    }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Image(systemName: "photo.on.rectangle")
                            .padding(10)
                            .background(.black.opacity(0.5), in: Circle())
                            .foregroundStyle(.white)
                    }
                }
                .padding(12)
            }
        }
    }

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick a mode")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(RoastMode.all) { mode in
                    ModeCard(
                        mode: mode,
                        isSelected: selectedMode == mode,
                        isLocked: mode.isPremium && !store.hasAllModes
                    ) {
                        if mode.isPremium && !store.hasAllModes {
                            showPaywall = true
                        } else {
                            selectedMode = mode
                        }
                    }
                }
            }
        }
    }

    private var goButton: some View {
        Button {
            guard let image = pickedImage else { return }
            let mode = selectedMode
            Task { await engine.run(image: image, mode: mode) }
        } label: {
            Label("Roast me", systemImage: "flame.fill")
                .font(.title3.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(selectedMode.tint)
        .disabled(pickedImage == nil)
        .opacity(pickedImage == nil ? 0.5 : 1)
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [.black, selectedMode.tint.opacity(0.25), .black],
            startPoint: .top, endPoint: .bottom
        )
    }
}

// MARK: - Mode card

struct ModeCard: View {
    let mode: RoastMode
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: mode.systemImage)
                        .font(.title2)
                        .foregroundStyle(mode.tint)
                    Spacer()
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }
                Text(mode.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text(mode.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(isSelected ? mode.tint : .white.opacity(0.08),
                                  lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
