//
//  HomeView.swift
//  RoastMachine
//
//  The Stage. Camera-first: your face fills the screen inside a themed
//  positioning guide, and a tactile mechanical panel drives the machine.
//  "Choose a photo" is a small subset of the live experience.
//

import SwiftUI
import PhotosUI

struct HomeView: View {
    @EnvironmentObject private var engine: RoastEngine
    @EnvironmentObject private var store: StoreManager
    @StateObject private var camera = CameraController()

    @State private var selectedID = RoastMode.free[0].id
    @State private var libraryImage: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var showPaywall = false
    /// A locked mode the user tapped while a free premium roast is on offer.
    @State private var giftMode: RoastMode?

    private var selectedMode: RoastMode {
        RoastMode.all.first { $0.id == selectedID } ?? RoastMode.free[0]
    }
    private var theme: ModeTheme { selectedMode.theme }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            cameraLayer
            vignette
            SceneScrim(theme: theme)

            // The free headliner act gets the full show: drifting stage embers.
            if selectedMode.id == "classic" {
                EmberField(tint: theme.primary).ignoresSafeArea()
            }

            if libraryImage == nil {
                FaceGuideOverlay(theme: theme)
            }

            // Costume graphics matching the voice: chef hat for the chef, etc.
            CostumeOverlayView(modeID: selectedMode.id)

            VStack(spacing: 0) {
                topBar
                Spacer()
                if store.freeRoastAvailable {
                    giftBanner
                }
                controlPanel
            }
        }
        .animation(.easeInOut(duration: 0.4), value: selectedID)
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .sheet(isPresented: $showPaywall) { PaywallView().environmentObject(store) }
        .alert(
            "🎁 One on the house!",
            isPresented: Binding(get: { giftMode != nil }, set: { if !$0 { giftMode = nil } }),
            presenting: giftMode
        ) { mode in
            Button("Roast me, \(mode.title)!") {
                store.acceptFreeRoast(for: mode)
                selectedID = mode.id
            }
            Button("Unlock everything instead") { showPaywall = true }
            Button("Maybe later", role: .cancel) {}
        } message: { mode in
            Text("Try \(mode.title) free — one roast, no charge. If it stings good, the whole machine is $1.99.")
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    libraryImage = image
                }
            }
        }
    }

    // MARK: - Camera / image layer

    @ViewBuilder
    private var cameraLayer: some View {
        if let image = libraryImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        } else {
            switch camera.status {
            case .ready:
                CameraPreview(session: camera.session).ignoresSafeArea()
            case .denied, .unavailable:
                ZStack {
                    ThematicBackdrop(theme: theme)
                    VStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.7))
                        Text(camera.status == .denied ? "Camera access is off" : "No camera here")
                            .font(.headline).foregroundStyle(.white)
                        Text("Enable it in Settings, or tap the photo button below.")
                            .font(.caption).foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                    .offset(y: -60)
                }
            case .unconfigured:
                ZStack {
                    ThematicBackdrop(theme: theme)
                    ProgressView().tint(.white)
                }
            }
        }
    }

    private var vignette: some View {
        RadialGradient(
            colors: [.clear, .clear, .black.opacity(0.55)],
            center: .init(x: 0.5, y: 0.4), startRadius: 120, endRadius: 520
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill").foregroundStyle(theme.primary)
                Text("ROAST MACHINE")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white)
            }
            Spacer()
            Button { showPaywall = true } label: {
                Image(systemName: "crown.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.yellow)
                    .padding(10)
                    .background(.black.opacity(0.35), in: Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Mechanical control panel

    private var controlPanel: some View {
        ZStack(alignment: .top) {
            MetalPanel()
                .frame(height: 270)

            VStack(spacing: 12) {
                sceneLabel
                ModeDial(
                    modes: RoastMode.all,
                    selectedID: $selectedID,
                    isLocked: { !store.isUnlocked($0) },
                    onSelect: { mode in
                        if store.isUnlocked(mode) {
                            selectedID = mode.id
                        } else if store.freeRoastAvailable {
                            giftMode = mode
                        } else {
                            showPaywall = true
                        }
                    },
                    // Audition any voice — locked ones too; it sells the unlock.
                    onPreview: { mode in
                        Task { await engine.voice.preview(mode) }
                    },
                    previewingID: engine.voice.previewingModeID
                )
                actionRow
            }
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }

    /// Dangles the occasional free premium roast over the control panel.
    private var giftBanner: some View {
        HStack(spacing: 8) {
            Text("🎁")
            Text("FREE PREMIUM ROAST — TAP A LOCKED KNOB")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1)
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(
            LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing),
            in: Capsule()
        )
        .shadow(color: .orange.opacity(0.7), radius: 10)
        .padding(.bottom, 8)
    }

    private var sceneLabel: some View {
        VStack(spacing: 2) {
            Text(theme.scene)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(3)
                .foregroundStyle(theme.primary)
            Text(selectedMode.title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var actionRow: some View {
        HStack {
            libraryButton
                .frame(width: 64)
            Spacer()
            ShutterButton(tint: theme.primary) { capture() }
            Spacer()
            flipButton
                .frame(width: 64)
        }
        .padding(.horizontal, 30)
    }

    @ViewBuilder
    private var libraryButton: some View {
        if libraryImage != nil {
            Button {
                Haptics.tap()
                libraryImage = nil
                photoItem = nil
            } label: {
                controlChip(system: "camera.viewfinder", caption: "Live")
            }
            .buttonStyle(.plain)
        } else {
            PhotosPicker(selection: $photoItem, matching: .images) {
                controlChip(system: "photo.on.rectangle", caption: "Photo")
            }
        }
    }

    @ViewBuilder
    private var flipButton: some View {
        if libraryImage == nil && camera.status == .ready {
            Button {
                Haptics.tap()
                camera.flip()
            } label: {
                controlChip(system: "arrow.triangle.2.circlepath.camera", caption: "Flip")
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(width: 52, height: 52)
        }
    }

    private func controlChip(system: String, caption: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: system)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(white: 0.85))
                .frame(width: 50, height: 50)
                .background(Metal.knob(.gray), in: Circle())
                .overlay(Circle().stroke(.black.opacity(0.6), lineWidth: 1))
            Text(caption)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Actions

    private func capture() {
        if let image = libraryImage {
            run(image)
            return
        }
        camera.capture { image in
            guard let image else { return }
            run(image)
        }
    }

    private func run(_ image: UIImage) {
        let mode = selectedMode
        // A gifted premium roast is single-use: burn it the moment it fires.
        if mode.isPremium && !store.hasAllModes && store.trialUnlockedModeID == mode.id {
            store.consumeFreeRoast()
        }
        Task { await engine.run(image: image, mode: mode) }
    }
}
