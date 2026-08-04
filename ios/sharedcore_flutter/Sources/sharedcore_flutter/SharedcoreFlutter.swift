import CoreTelephony
import Darwin
import Flutter
import Security
import UIKit
import sharedcore_flutter_linker

private let sharedcoreFlutterLinkAnchor = sharedcore_flutter_retain_symbols()

/// Collects iOS-owned device information for the Rust SharedCore client.
public final class SharedcoreFlutterPlugin: NSObject, FlutterPlugin {
    private static let channelName = "sharedcore_flutter/device_info"

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(SharedcoreFlutterPlugin(), channel: channel)
    }

    public func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        let arguments = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "collectDeviceInfo":
            let appId = arguments["appId"] as? String ?? ""
            result(collectDeviceInfo(appId: appId))
        case "loadSession":
            do {
                result(try loadSession(prefix: sessionPrefix(arguments)))
            } catch {
                result(sessionStoreFailure(error))
            }
        case "saveSession":
            do {
                try saveSession(arguments, prefix: sessionPrefix(arguments))
                result(nil)
            } catch {
                result(sessionStoreFailure(error))
            }
        case "clearSession":
            do {
                try clearSession(prefix: sessionPrefix(arguments))
                result(nil)
            } catch {
                result(sessionStoreFailure(error))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func collectDeviceInfo(appId: String) -> [String: Any] {
        let device = UIDevice.current
        let language = Locale.preferredLanguages.first ?? Locale.current.identifier
        let templateLanguage = (Locale.current as NSLocale).object(
            forKey: .languageCode
        ) as? String ?? ""
        let carriers = currentCarriers()

        return [
            "appId": appId,
            "bundleId": Bundle.main.bundleIdentifier ?? "",
            "udid": persistentDeviceIdentifier(),
            "appVersion": Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "1.0",
            "platform": "ios",
            "deviceName": device.name,
            "systemName": device.systemName,
            "osVersion": device.systemVersion,
            "language": language,
            "templateLanguage": templateLanguage,
            "timezone": TimeZone.current.identifier,
            "inputLanguage": templateLanguage,
            "vpn": isVpnActive(),
            "hasWxOrQq": hasWxOrQq(),
            "networkOperator": carriers.network,
            "simOperator": carriers.sim,
            "installReferrer": "",
        ]
    }

    private func persistentDeviceIdentifier() -> String {
        let service = (Bundle.main.bundleIdentifier ?? "SharedCore") +
            ".sharedcore.udid"
        let account = "udid"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var existing: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &existing) == errSecSuccess,
           let data = existing as? Data,
           let identifier = String(data: data, encoding: .utf8),
           !identifier.isEmpty {
            return identifier
        }

        let identifier = UIDevice.current.identifierForVendor?.uuidString ??
            UUID().uuidString
        var insertion = query
        insertion.removeValue(forKey: kSecReturnData as String)
        insertion.removeValue(forKey: kSecMatchLimit as String)
        insertion[kSecValueData as String] = Data(identifier.utf8)
        insertion[kSecAttrAccessible as String] =
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(insertion as CFDictionary, nil)
        return identifier
    }

    private func sessionPrefix(_ arguments: [String: Any]) -> String {
        arguments["prefix"] as? String ?? "SharedCore"
    }

    private func loadSession(prefix: String) throws -> [String: String]? {
        try prepareSecureSessionStore(prefix: prefix)
        let defaults = UserDefaults.standard
        guard let accessToken = try readAccessToken(prefix: prefix),
              !accessToken.isEmpty else { return nil }
        return [
            "accessToken": accessToken,
            "userId": defaults.string(forKey: prefix + "UserId") ?? "",
            "email": defaults.string(forKey: prefix + "Email") ?? "",
        ]
    }

    private func saveSession(_ arguments: [String: Any], prefix: String) throws {
        let accessToken = arguments["accessToken"] as? String ?? ""
        guard !accessToken.isEmpty else {
            try clearSession(prefix: prefix)
            return
        }
        try prepareSecureSessionStore(prefix: prefix)
        try writeAccessToken(accessToken, prefix: prefix)
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: prefix + "AccessToken")
        defaults.set(arguments["userId"] as? String ?? "", forKey: prefix + "UserId")
        defaults.set(arguments["email"] as? String ?? "", forKey: prefix + "Email")
    }

    private func clearSession(prefix: String) throws {
        try deleteAccessToken(prefix: prefix)
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: prefix + "AccessToken")
        defaults.removeObject(forKey: prefix + "UserId")
        defaults.removeObject(forKey: prefix + "Email")
    }

    private func prepareSecureSessionStore(prefix: String) throws {
        let defaults = UserDefaults.standard
        let markerKey = prefix + "SecureSessionInstallationMarker"
        let legacyKey = prefix + "AccessToken"
        if defaults.bool(forKey: markerKey) {
            // Finish cleanup if a previous migration stopped after committing
            // its installation marker.
            defaults.removeObject(forKey: legacyKey)
            return
        }

        let legacyToken = defaults.string(forKey: legacyKey) ?? ""
        if legacyToken.isEmpty {
            // Keychain data can survive uninstall. A missing sandbox marker means
            // this is a fresh installation, so an old credential must not return.
            try deleteAccessToken(prefix: prefix)
        } else {
            try writeAccessToken(legacyToken, prefix: prefix)
        }
        defaults.set(true, forKey: markerKey)
        defaults.removeObject(forKey: legacyKey)
    }

    private func readAccessToken(prefix: String) throws -> String? {
        var query = keychainQuery(prefix: prefix)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw SessionStoreError.keychain(status) }
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func writeAccessToken(_ accessToken: String, prefix: String) throws {
        let query = keychainQuery(prefix: prefix)
        let value = Data(accessToken.utf8)
        let status = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: value] as CFDictionary
        )
        if status == errSecItemNotFound {
            var insertion = query
            insertion[kSecValueData as String] = value
            insertion[kSecAttrAccessible as String] =
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(insertion as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw SessionStoreError.keychain(addStatus)
            }
            return
        }
        guard status == errSecSuccess else { throw SessionStoreError.keychain(status) }
    }

    private func deleteAccessToken(prefix: String) throws {
        let status = SecItemDelete(keychainQuery(prefix: prefix) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SessionStoreError.keychain(status)
        }
    }

    private func keychainQuery(prefix: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String:
                (Bundle.main.bundleIdentifier ?? "SharedCore") + ".sharedcore.session",
            kSecAttrAccount as String: prefix + ".accessToken",
            kSecAttrSynchronizable as String: false,
        ]
    }

    private func sessionStoreFailure(_ error: Error) -> FlutterError {
        FlutterError(
            code: "session_storage_unavailable",
            message: "Unable to access the secure SharedCore session store: \(error)",
            details: nil
        )
    }

    private enum SessionStoreError: Error {
        case keychain(OSStatus)
    }

    private func currentCarriers() -> (network: String, sim: String) {
        let info = CTTelephonyNetworkInfo()
        let carrier = info.serviceSubscriberCellularProviders?
            .values
            .first(where: { $0.carrierName?.isEmpty == false })
        return (carrier?.carrierName ?? "", carrier?.mobileNetworkCode ?? "")
    }

    private func hasWxOrQq() -> Bool {
        let schemes = ["weixin://", "mqq://"]
        return schemes.contains { value in
            guard let url = URL(string: value) else { return false }
            return UIApplication.shared.canOpenURL(url)
        }
    }

    private func isVpnActive() -> Bool {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0 else { return false }
        defer { freeifaddrs(interfaces) }

        var pointer = interfaces
        while let current = pointer {
            let name = String(cString: current.pointee.ifa_name)
            if name.hasPrefix("utun") ||
                name.hasPrefix("tun") ||
                name.hasPrefix("ppp") ||
                name.hasPrefix("ipsec") {
                return true
            }
            pointer = current.pointee.ifa_next
        }
        return false
    }
}
