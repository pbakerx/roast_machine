//
//  VideoExporter.swift
//  RoastMachine
//
//  Bakes a roast into a shareable vertical MP4: the photo full-frame, the
//  ElevenLabs audio underneath, and the mode badge.
//

import AVFoundation
import UIKit

enum VideoExporter {

    enum ExportError: LocalizedError {
        case writerSetup, audioTrackMissing, cancelled
        var errorDescription: String? {
            switch self {
            case .writerSetup: return "Couldn't set up the video writer."
            case .audioTrackMissing: return "The roast audio couldn't be read."
            case .cancelled: return "Export was cancelled."
            }
        }
    }

    static let renderSize = CGSize(width: 1080, height: 1920)

    /// Renders photo + audio + badge into an .mp4 and returns its URL.
    static func export(image: UIImage, audio: Data, mode: RoastMode) async throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
        let audioURL = tmp.appendingPathComponent("roast_export_audio.mp3")
        let videoURL = tmp.appendingPathComponent("roast_\(mode.id).mp4")
        try? FileManager.default.removeItem(at: videoURL)
        try audio.write(to: audioURL)

        let audioAsset = AVURLAsset(url: audioURL)
        let duration = try await audioAsset.load(.duration)
        let seconds = max(CMTimeGetSeconds(duration), 1)

        guard let writer = try? AVAssetWriter(outputURL: videoURL, fileType: .mp4) else {
            throw ExportError.writerSetup
        }

        // -- video input: one still frame held for the length of the audio
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: renderSize.width,
            AVVideoHeightKey: renderSize.height
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: renderSize.width,
                kCVPixelBufferHeightKey as String: renderSize.height
            ])

        // -- audio input: mp3 decoded to PCM, re-encoded as AAC
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44100,
            AVEncoderBitRateKey: 128_000
        ])
        audioInput.expectsMediaDataInRealTime = false

        guard writer.canAdd(videoInput), writer.canAdd(audioInput) else {
            throw ExportError.writerSetup
        }
        writer.add(videoInput)
        writer.add(audioInput)

        guard let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first,
              let reader = try? AVAssetReader(asset: audioAsset) else {
            throw ExportError.audioTrackMissing
        }
        let readerOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM
        ])
        reader.add(readerOutput)

        writer.startWriting()
        reader.startReading()
        writer.startSession(atSourceTime: .zero)

        // the same frame at the start and the end so the video spans the audio
        guard let buffer = pixelBuffer(from: renderFrame(image: image, mode: mode)) else {
            throw ExportError.writerSetup
        }
        for time in [0, seconds] {
            while !videoInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 20_000_000)
            }
            adaptor.append(buffer, withPresentationTime: CMTime(seconds: time, preferredTimescale: 600))
        }
        videoInput.markAsFinished()

        // pump the audio samples through
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let queue = DispatchQueue(label: "roast.video.audio")
            audioInput.requestMediaDataWhenReady(on: queue) {
                while audioInput.isReadyForMoreMediaData {
                    if let sample = readerOutput.copyNextSampleBuffer() {
                        audioInput.append(sample)
                    } else {
                        audioInput.markAsFinished()
                        continuation.resume()
                        return
                    }
                }
            }
        }

        await writer.finishWriting()
        guard writer.status == .completed else {
            throw writer.error ?? ExportError.writerSetup
        }
        return videoURL
    }

    // MARK: - Frame rendering

    private static func renderFrame(image: UIImage, mode: RoastMode) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: renderSize)
        return renderer.image { ctx in
            // photo, aspect-filled
            let scale = max(renderSize.width / image.size.width,
                            renderSize.height / image.size.height)
            let w = image.size.width * scale
            let h = image.size.height * scale
            image.draw(in: CGRect(x: (renderSize.width - w) / 2,
                                  y: (renderSize.height - h) / 2,
                                  width: w, height: h))

            // bottom scrim
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.75).cgColor] as CFArray,
                locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: renderSize.height - 460),
                end: CGPoint(x: 0, y: renderSize.height),
                options: [])


            // badge: mode + branding
            let badge = "\(mode.theme.scene)  •  \(mode.title)"
            badge.draw(at: CGPoint(x: 56, y: renderSize.height - 210), withAttributes: [
                .font: UIFont.systemFont(ofSize: 38, weight: .heavy),
                .foregroundColor: UIColor.white
            ])
            "🔥 ROAST MACHINE".draw(at: CGPoint(x: 56, y: renderSize.height - 140), withAttributes: [
                .font: UIFont.systemFont(ofSize: 46, weight: .black),
                .foregroundColor: UIColor.orange
            ])
        }
    }

    private static func pixelBuffer(from image: UIImage) -> CVPixelBuffer? {
        guard let cg = image.cgImage else { return nil }
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault,
                            Int(renderSize.width), Int(renderSize.height),
                            kCVPixelFormatType_32BGRA,
                            [kCVPixelBufferCGImageCompatibilityKey: true,
                             kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary,
                            &buffer)
        guard let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                      width: Int(renderSize.width), height: Int(renderSize.height),
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                                        | CGBitmapInfo.byteOrder32Little.rawValue) else { return nil }
        context.draw(cg, in: CGRect(origin: .zero, size: renderSize))
        return buffer
    }
}
