//
//  Backend.swift
//  RoastMachine
//
//  Talks to the `roastmachine` Supabase Edge Function, which holds the OpenAI
//  and ElevenLabs keys and the ticket wallets. The app carries no secrets:
//  every request is signed with an Apple App Attest assertion proving it came
//  from this app on a genuine iPhone.
//

import CryptoKit
import DeviceCheck
import Foundation
import UIKit

struct Wallet: Codable, Equatable {
    var tickets: Int
    var freeRoast: Bool
    var freeHype: Bool

    enum CodingKeys: String, CodingKey {
        case tickets
        case freeRoast = "free_roast"
        case freeHype = "free_hype"
    }

    func freeRunRemaining(for flavor: RoastFlavor) -> Bool {
        flavor == .roast ? freeRoast : freeHype
    }

    func canRun(_ flavor: RoastFlavor) -> Bool {
        freeRunRemaining(for: flavor) || tickets > 0
    }
}

enum BackendError: LocalizedError {
    case noTickets(Wallet?)
    case dailyCap
    case rateLimited
    case busy
    case deviceNotSupported
    case attestationFailed
    case failed(Wallet?)
    case server(Int)

    var errorDescription: String? {
        switch self {
        case .noTickets:          return "You're out of tickets. Swing by the Box Office."
        case .dailyCap:           return "That's a lot of comedy for one day. The machine needs a nap — come back tomorrow."
        case .rateLimited:        return "Whoa, slow down! Try again in a few minutes."
        case .busy:               return "The club is packed right now. Try again in a bit."
        case .deviceNotSupported: return "This device can't be verified with Apple, so the machine can't run here."
        case .attestationFailed:  return "Couldn't verify this device with Apple. Check your connection and try again."
        case .failed:             return "The comedian choked. Your ticket's been refunded — try again."
        case .server(let code):   return "The machine hiccuped (\(code)). Try again."
        }
    }

    /// The server hands back the refunded wallet on failures; surface it.
    var wallet: Wallet? {
        switch self {
        case .noTickets(let w), .failed(let w): return w
        default: return nil
        }
    }
}

actor Backend {
    static let shared = Backend()

    /// This player's wallet id, also the StoreKit appAccountToken. Kept in the
    /// iCloud Keychain so tickets survive reinstalls and follow the user.
    nonisolated let walletID: UUID = Keychain.walletID()

    private var keyID: String? = Keychain.read("rm.attestKey")
    private var registering: Task<String, Error>?
    private var lastRequest: Task<Void, Never>?

    // MARK: - API

    func wallet() async throws -> Wallet {
        let data = try await send("wallet", [:])
        return try decode(WalletEnvelope.self, data).wallet
    }

    struct ShowResult: Decodable {
        let showId: String
        let script: String
        let wallet: Wallet
    }

    func show(image: UIImage, modeID: String, flavor: RoastFlavor) async throws -> ShowResult {
        guard let jpeg = Self.jpegBase64(image) else { throw BackendError.server(400) }
        let data = try await send("show", ["modeId": modeID, "flavor": flavor.rawValue, "image": jpeg])
        return try decode(ShowResult.self, data)
    }

    func voice(showID: String) async throws -> Data {
        try await send("voice", ["showId": showID])
    }

    struct CreditResult: Decodable {
        let credited: Bool
        let wallet: Wallet
    }

    func credit(jws: String) async throws -> CreditResult {
        let data = try await send("credit", ["jws": jws])
        return try decode(CreditResult.self, data)
    }

    // MARK: - Transport

    private struct WalletEnvelope: Decodable { let wallet: Wallet }
    private struct ErrorEnvelope: Decodable { let error: String; let wallet: Wallet? }

    /// Signed requests go out one at a time: App Attest counters must arrive in order.
    private func send(_ route: String, _ body: [String: Any]) async throws -> Data {
        let previous = lastRequest
        let task = Task { () async throws -> Data in
            _ = await previous?.value
            return try await self.sendNow(route, body, retryOnUnknownKey: true)
        }
        lastRequest = Task { _ = try? await task.value }
        return try await task.value
    }

    private func sendNow(_ route: String, _ body: [String: Any], retryOnUnknownKey: Bool) async throws -> Data {
        let payload = try JSONSerialization.data(withJSONObject: body)
        var request = Self.request(route, payload)
        try await sign(&request, body: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if (200...299).contains(status) { return data }

        let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
        switch envelope?.error {
        case "unknown_key" where retryOnUnknownKey:
            // The server no longer knows this key; attest a fresh one once.
            forgetKey()
            return try await sendNow(route, body, retryOnUnknownKey: false)
        case "no_tickets":   throw BackendError.noTickets(envelope?.wallet)
        case "daily_cap":    throw BackendError.dailyCap
        case "rate_limited": throw BackendError.rateLimited
        case "busy":         throw BackendError.busy
        case "writer_failed", "voice_failed": throw BackendError.failed(envelope?.wallet)
        default:             throw BackendError.server(status)
        }
    }

    private func sign(_ request: inout URLRequest, body: Data) async throws {
#if DEBUG && targetEnvironment(simulator)
        // The simulator can't do App Attest. For local testing only, a dev token
        // (SIMCTL_CHILD_RM_DEV_TOKEN) is accepted while the server secret exists.
        if let dev = ProcessInfo.processInfo.environment["RM_DEV_TOKEN"], !dev.isEmpty {
            request.setValue(dev, forHTTPHeaderField: "x-rm-dev")
            request.setValue(walletID.uuidString.lowercased(), forHTTPHeaderField: "x-rm-wallet")
            return
        }
#endif
        let service = DCAppAttestService.shared
        guard service.isSupported else { throw BackendError.deviceNotSupported }
        let key = try await attestedKey()
        let assertion = try await service.generateAssertion(key, clientDataHash: Data(SHA256.hash(data: body)))
        request.setValue(key, forHTTPHeaderField: "x-rm-key")
        request.setValue(assertion.base64EncodedString(), forHTTPHeaderField: "x-rm-assertion")
    }

    // MARK: - App Attest

    private struct Challenge: Decodable { let challengeId: String; let challenge: String }

    /// Returns a key the server has verified, generating and attesting one on
    /// first use. Concurrent callers share the same registration.
    private func attestedKey() async throws -> String {
        if let keyID { return keyID }
        if let registering { return try await registering.value }
        let task = Task { try await self.register() }
        registering = task
        defer { registering = nil }
        let key = try await task.value
        keyID = key
        Keychain.write("rm.attestKey", key, synchronizable: false)
        return key
    }

    private func register() async throws -> String {
        let service = DCAppAttestService.shared
        do {
            let key = try await service.generateKey()
            let (challengeData, _) = try await URLSession.shared.data(for: Self.request("challenge", Data("{}".utf8)))
            let challenge = try JSONDecoder().decode(Challenge.self, from: challengeData)
            guard let challengeBytes = Data(base64Encoded: challenge.challenge) else { throw BackendError.attestationFailed }

            let attestation = try await service.attestKey(key, clientDataHash: Data(SHA256.hash(data: challengeBytes)))
            let body = try JSONSerialization.data(withJSONObject: [
                "challengeId": challenge.challengeId,
                "keyId": key,
                "attestation": attestation.base64EncodedString(),
                "walletId": walletID.uuidString.lowercased(),
            ])
            let (_, response) = try await URLSession.shared.data(for: Self.request("register", body))
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw BackendError.attestationFailed }
            return key
        } catch let error as BackendError {
            throw error
        } catch {
            throw BackendError.attestationFailed
        }
    }

    private func forgetKey() {
        keyID = nil
        Keychain.delete("rm.attestKey")
    }

    // MARK: - Helpers

    private static func request(_ route: String, _ body: Data) -> URLRequest {
        var request = URLRequest(url: AppConfig.backendURL.appendingPathComponent(route))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 60
        return request
    }

    private func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw BackendError.server(0) }
    }

    /// Downscaled JPEG keeps the upload small and fast; the photo is never stored.
    private static func jpegBase64(_ image: UIImage) -> String? {
        let maxDimension: CGFloat = 768
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
        return resized.jpegData(compressionQuality: 0.7)?.base64EncodedString()
    }
}

// MARK: - Keychain

enum Keychain {
    private static let service = "AechTech.RoastMachine"

    static func walletID() -> UUID {
        if let s = read("rm.walletId", synchronizable: true), let id = UUID(uuidString: s) { return id }
        let id = UUID()
        write("rm.walletId", id.uuidString, synchronizable: true)
        return id
    }

    static func read(_ account: String, synchronizable: Bool = false) -> String? {
        var query = base(account, synchronizable)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ account: String, _ value: String, synchronizable: Bool) {
        delete(account, synchronizable: synchronizable)
        var item = base(account, synchronizable)
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] = synchronizable
            ? kSecAttrAccessibleAfterFirstUnlock
            : kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    static func delete(_ account: String, synchronizable: Bool = false) {
        SecItemDelete(base(account, synchronizable) as CFDictionary)
    }

    private static func base(_ account: String, _ synchronizable: Bool) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: synchronizable,
        ]
    }
}
