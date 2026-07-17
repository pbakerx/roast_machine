//
//  LivePortraitView.swift
//  RoastMachine
//
//  A live in-app camera so the app roasts you exactly as you are right now.
//  Front camera by default; tap the shutter to capture the moment and roast it.
//

import SwiftUI
import AVFoundation
import UIKit

// MARK: - Camera controller

final class CameraController: NSObject, ObservableObject {

    enum Status { case unconfigured, ready, denied, unavailable }

    let session = AVCaptureSession()

    @Published var status: Status = .unconfigured
    @Published var isCapturing = false

    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.aechtech.roastmachine.camera")
    private var position: AVCaptureDevice.Position = .front
    private var captureHandler: ((UIImage?) -> Void)?

    // MARK: Lifecycle

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted { self.configureIfNeeded() }
                else { self.setStatus(.denied) }
            }
        default:
            setStatus(.denied)
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func flip() {
        position = (position == .front) ? .back : .front
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.inputs.forEach { self.session.removeInput($0) }
            self.addInput()
            self.session.commitConfiguration()
        }
    }

    // MARK: Capture

    func capture(_ completion: @escaping (UIImage?) -> Void) {
        guard status == .ready else { completion(nil); return }
        captureHandler = completion
        setCapturing(true)
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    // MARK: Private

    private func configureIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            self.addInput()
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }
            self.session.commitConfiguration()

            let hasInput = !self.session.inputs.isEmpty
            self.session.startRunning()
            self.setStatus(hasInput ? .ready : .unavailable)
        }
    }

    private func addInput() {
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
                ?? AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else { return }
        session.addInput(input)
    }

    private func setStatus(_ new: Status) {
        DispatchQueue.main.async { self.status = new }
    }

    private func setCapturing(_ value: Bool) {
        DispatchQueue.main.async { self.isCapturing = value }
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        setCapturing(false)
        guard let data = photo.fileDataRepresentation(), var image = UIImage(data: data) else {
            DispatchQueue.main.async { self.captureHandler?(nil); self.captureHandler = nil }
            return
        }
        // Mirror front-camera shots so they match what the user saw in the preview.
        if position == .front, let cg = image.cgImage {
            image = UIImage(cgImage: cg, scale: image.scale, orientation: .leftMirrored)
        }
        let final = image
        DispatchQueue.main.async { self.captureHandler?(final); self.captureHandler = nil }
    }
}

// MARK: - Preview layer

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - Full-screen live portrait

struct LivePortraitView: View {
    @StateObject private var camera = CameraController()
    @Environment(\.dismiss) private var dismiss

    var onCapture: (UIImage) -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch camera.status {
            case .ready:
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
                controls
            case .denied:
                message("Camera access is off",
                        "Enable camera access in Settings to use Live Portrait.")
            case .unavailable:
                message("No camera found",
                        "Live Portrait needs a device with a camera. Try Library instead.")
            case .unconfigured:
                ProgressView().tint(.white)
            }
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }

    private var controls: some View {
        VStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.black.opacity(0.45), in: Circle())
                }
                Spacer()
                Text("Live Portrait")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    camera.flip()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.black.opacity(0.45), in: Circle())
                }
            }
            .padding()

            Spacer()

            Button {
                camera.capture { image in
                    guard let image else { return }
                    onCapture(image)
                    dismiss()
                }
            } label: {
                ZStack {
                    Circle().stroke(.white, lineWidth: 5).frame(width: 82, height: 82)
                    Circle().fill(.white).frame(width: 68, height: 68)
                    if camera.isCapturing {
                        ProgressView().tint(.black)
                    }
                }
            }
            .disabled(camera.isCapturing)
            .padding(.bottom, 40)
        }
    }

    private func message(_ title: String, _ body: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.system(size: 42))
                .foregroundStyle(.white.opacity(0.7))
            Text(title).font(.title3.bold()).foregroundStyle(.white)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Button("Close") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .padding(.top, 8)
        }
        .padding(40)
    }
}
