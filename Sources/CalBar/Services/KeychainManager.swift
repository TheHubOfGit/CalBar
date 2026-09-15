import Foundation
import Security

public final class KeychainManager: @unchecked Sendable {
    public static let shared = KeychainManager()
    private let fileURL: URL
    private let lock = NSLock()

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("com.michaelbrancazio.CalBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [
            .posixPermissions: 0o700
        ])
        self.fileURL = dir.appendingPathComponent("auth_tokens.json")

        // Clean up legacy keychain items so macOS never prompts
        cleanupLegacyKeychain()
    }

    private func readStore() -> [String: String] {
        guard let data = try? Data(contentsOf: fileURL),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return [:]
        }
        return dict
    }

    private func writeStore(_ dict: [String: String]) -> Bool {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]) else {
            return false
        }
        do {
            try data.write(to: fileURL, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            return true
        } catch {
            return false
        }
    }

    public func save(key: String, value: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        var store = readStore()
        store[key] = value
        return writeStore(store)
    }

    public func get(key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return readStore()[key]
    }

    @discardableResult
    public func delete(key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        var store = readStore()
        store.removeValue(forKey: key)
        return writeStore(store)
    }

    private func cleanupLegacyKeychain() {
        DispatchQueue.global(qos: .utility).async {
            let legacyKeys = [
                "google_client_id", "google_client_secret",
                "google_access_token", "google_refresh_token", "google_token_expiry"
            ]
            for k in legacyKeys {
                let q: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: "com.calbar.googleauth",
                    kSecAttrAccount as String: k
                ]
                SecItemDelete(q as CFDictionary)
            }
        }
    }
}
