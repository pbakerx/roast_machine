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

    @State private var selectedID = RoastMode.classic.id
    @State private var flavor: RoastFlavor = .roast
    @State private var libraryImage: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var showPaywall = false
    @State private var showConsent = false
    @AppStorage("rm.aiConsentGiven") private var aiConsentGiven = false

    private var selectedMode: RoastMode {
        RoastMode.all.first { $0.id == selectedID } ?? RoastMode.classic
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

            VStack(spacing: 0) {
                topBar
                Spacer()
                if !store.hasEverything {
                    ticketBanner
                }
                controlPanel
            }
        }
        .animation(.easeInOut(duration: 0.4), value: selectedID)
        .onAppear {
            camera.start()
            loadDemoPhotoIfRequested()
        }
        .onDisappear { camera.stop() }
        .sheet(isPresented: $showPaywall) { PaywallView().environmentObject(store) }
        .sheet(isPresented: $showConsent) {
            AIConsentView {
                aiConsentGiven = true
                // Fire the shot they were trying to take once the sheet is gone.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { capture() }
            }
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
            // Overlay on a clear frame so the filled image can't widen the
            // Stage past the screen and push the chrome offscreen.
            Color.clear
                .overlay(Image(uiImage: image).resizable().scaledToFill())
                .clipped()
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
                .frame(height: 316)

            VStack(spacing: 12) {
                sceneLabel
                FlavorSwitch(flavor: $flavor)
                ModeDial(
                    modes: RoastMode.all,
                    selectedID: $selectedID,
                    // Every comedian is pickable; the shutter is what's gated.
                    // Padlocks light up once this flavor's free run is spent.
                    isLocked: { _ in !store.canRun(flavor) },
                    onSelect: { mode in selectedID = mode.id },
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

    /// Shows what's still on the house; once both tastes are spent it turns
    /// into the unlock pitch.
    private var ticketBanner: some View {
        let roast = store.freeRunRemaining(for: .roast)
        let hype = store.freeRunRemaining(for: .compliment)
        let label: String
        switch (roast, hype) {
        case (true, true):   label = "ON THE HOUSE: 1 ROAST · 1 HYPE"
        case (true, false):  label = "ON THE HOUSE: 1 ROAST LEFT"
        case (false, true):  label = "ON THE HOUSE: 1 HYPE LEFT"
        case (false, false): label = "UNLOCK EVERYTHING — \(store.everythingProduct?.displayPrice ?? "$2.99")"
        }
        return Button {
            Haptics.tap()
            showPaywall = true
        } label: {
            HStack(spacing: 8) {
                Text(roast || hype ? "🎟️" : "🔓")
                Text(label)
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
        }
        .buttonStyle(.plain)
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
            ShutterButton(tint: flavor == .compliment ? .pink : theme.primary,
                          symbol: flavor == .compliment ? "heart.fill" : "flame.fill") {
                capture()
            }
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

#if DEBUG && targetEnvironment(simulator)
    /// Screenshot rig, driven by `SIMCTL_CHILD_*` env vars on `xcrun simctl launch`:
    /// `RM_DEMO_PHOTO=/path` drops a photo onto the Stage (the simulator has no
    /// camera and its photo picker is unreliable); `RM_DEMO_MODE=<mode id>` and
    /// `RM_DEMO_FLAVOR=roast|compliment` preset the panel; `RM_DEMO_AUTORUN=1`
    /// accepts the consent sheet and fires the shutter.
    private func loadDemoPhotoIfRequested() {
        let env = ProcessInfo.processInfo.environment
        guard libraryImage == nil,
              let path = env["RM_DEMO_PHOTO"],
              let image = UIImage(contentsOfFile: path) else { return }
        libraryImage = image
        if let id = env["RM_DEMO_MODE"], RoastMode.all.contains(where: { $0.id == id }) {
            selectedID = id
        }
        if let raw = env["RM_DEMO_FLAVOR"], let demoFlavor = RoastFlavor(rawValue: raw) {
            flavor = demoFlavor
        }
        if env["RM_DEMO_AUTORUN"] == "1" {
            aiConsentGiven = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { capture() }
        }
    }
#else
    private func loadDemoPhotoIfRequested() {}
#endif

    private func capture() {
        // Gate before the photo is taken so a spent free run goes straight
        // to the pitch instead of firing the flash for nothing.
        guard store.canRun(flavor) else {
            showPaywall = true
            return
        }
        guard aiConsentGiven else {
            showConsent = true
            return
        }
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
        let flavor = flavor
        // The free taste is single-use: burn it the moment it fires.
        store.consumeFreeRun(flavor)
        Task { await engine.run(image: image, mode: mode, flavor: flavor) }
    }
}
