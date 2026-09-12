import Foundation

struct RuntimeUserAgent: Equatable, Sendable {
    let value: String
    let displayName: String
    let family: String
    let device: String
    let osVersion: String
}

/// Builds a launch-only user agent from a curated set of mobile WebKit
/// components. The generator never invents arbitrary tokens: every result is
/// produced by one of the explicitly supported browser/device templates.
struct RuntimeUserAgentGenerator {
    static let maximumAttempts = 32

    typealias IndexSource = (Int) -> Int

    private struct DeviceProfile {
        let name: String
        let osVersions: [String]
    }

    private static let devices = [
        DeviceProfile(name: "iPhone", osVersions: ["18_7", "18_6", "17_7"]),
        DeviceProfile(name: "iPad", osVersions: ["18_7", "18_6", "17_7"])
    ]

    // These versions are the same frozen, mobile-only families used by the
    // hand-selected catalog. Keeping the version pool curated prevents a
    // random combination from claiming an impossible browser/OS shape.
    private static let browserVersions = [
        (family: "Safari", versions: ["27.3", "27.4", "27.5", "27.6", "27.7",
                                       "27.8", "27.9", "27.10", "27.11", "27.12"]),
        (family: "Chrome", versions: ["151.0.7800.50", "150.0.7743.80", "149.0.7667.90",
                                       "148.0.7600.90", "147.0.7540.120", "146.0.7480.120",
                                       "145.0.7400.100", "144.0.7330.120", "143.0.7260.140",
                                       "142.0.7190.160"]),
        (family: "Firefox", versions: ["154.0", "153.0", "152.0", "151.0", "150.0",
                                        "149.0", "148.0", "147.0", "146.0", "145.0"]),
        (family: "Edge", versions: ["151.0", "150.0", "149.0", "148.0", "147.0",
                                     "146.0", "145.0", "144.0", "143.0", "142.0"]),
        (family: "Opera", versions: ["7.1.0.1000", "7.1.0.1001", "7.1.0.1002",
                                      "7.1.0.1003", "7.1.0.1004"]),
        (family: "DuckDuckGo", versions: ["8.1", "8.2", "8.3", "8.4", "8.5"])
    ]

    private let indexSource: IndexSource

    init(indexSource: @escaping IndexSource = { count in
        guard count > 0 else { return 0 }
        return Int.random(in: 0..<count)
    }) {
        self.indexSource = indexSource
    }

    func generate(isRestricted: (String) -> Bool) -> RuntimeUserAgent? {
        let candidates = Self.candidates
        guard !candidates.isEmpty else { return nil }

        for _ in 0..<Self.maximumAttempts {
            let index = normalizedIndex(indexSource(candidates.count), count: candidates.count)
            let candidate = candidates[index]
            guard Self.isValid(candidate), !isRestricted(candidate.value) else { continue }
            return candidate
        }
        return nil
    }

    static func isValid(_ userAgent: RuntimeUserAgent) -> Bool {
        guard userAgent.value.hasPrefix("Mozilla/5.0 "),
              userAgent.value.contains("AppleWebKit/605.1.15"),
              userAgent.value.contains("Mobile/15E148"),
              supportedDeviceVersions.contains(where: { profile in
                  profile.name == userAgent.device &&
                  profile.osVersions.contains(userAgent.osVersion) &&
                  userAgent.value.contains(Self.deviceToken(
                      device: profile.name,
                      osVersion: userAgent.osVersion
                  ))
              }),
              browserVersions.contains(where: { group in
                  group.family == userAgent.family &&
                  group.versions.contains(where: { userAgent.value.contains($0) })
              }) else {
            return false
        }

        switch userAgent.family {
        case "Safari":
            return userAgent.value.contains("Version/") &&
                userAgent.value.contains("Safari/604.1")
        case "Chrome":
            return userAgent.value.contains("CriOS/") &&
                userAgent.value.contains("Safari/604.1")
        case "Firefox":
            return userAgent.value.contains("FxiOS/") &&
                userAgent.value.contains("Safari/605.1.15")
        case "Edge":
            return userAgent.value.contains("EdgiOS/") &&
                userAgent.value.contains("Safari/605.1.15")
        case "Opera":
            return userAgent.value.contains("OPiOS/") &&
                userAgent.value.contains("Safari/9537.53")
        case "DuckDuckGo":
            return userAgent.value.contains("Version/") &&
                userAgent.value.contains("DuckDuckGo/") &&
                userAgent.value.contains("Safari/605.1.15")
        default:
            return false
        }
    }

    private static var candidates: [RuntimeUserAgent] {
        devices.flatMap { device in
            device.osVersions.flatMap { osVersion in
                browserVersions.flatMap { group in
                    group.versions.map { version in
                        let value = makeValue(device: device,
                                              osVersion: osVersion,
                                              family: group.family,
                                              version: version)
                        return RuntimeUserAgent(value: value,
                                                 displayName: group.family + " " + device.name +
                                                    " iOS " + osVersion + " " + version,
                                                 family: group.family,
                                                 device: device.name,
                                                 osVersion: osVersion)
                    }
                }
            }
        }
    }

    private static var supportedDeviceVersions: [DeviceProfile] {
        devices
    }

    private static func deviceToken(device: String, osVersion: String) -> String {
        if device == "iPhone" {
            return "(iPhone; CPU iPhone OS \(osVersion) like Mac OS X)"
        }
        return "(iPad; CPU OS \(osVersion) like Mac OS X)"
    }

    private static func makeValue(device: DeviceProfile,
                                  osVersion: String,
                                  family: String,
                                  version: String) -> String {
        let prefix = "Mozilla/5.0 \(deviceToken(device: device.name, osVersion: osVersion)) " +
            "AppleWebKit/605.1.15 (KHTML, like Gecko) "
        switch family {
        case "Safari":
            return prefix + "Version/\(version) Mobile/15E148 Safari/604.1"
        case "Chrome":
            return prefix + "CriOS/\(version) Mobile/15E148 Safari/604.1"
        case "Firefox":
            return prefix + "FxiOS/\(version) Mobile/15E148 Safari/605.1.15"
        case "Edge":
            return prefix + "EdgiOS/\(version) Mobile/15E148 Safari/605.1.15"
        case "Opera":
            return prefix + "OPiOS/\(version) Mobile/15E148 Safari/9537.53"
        case "DuckDuckGo":
            return prefix + "Version/27.11 Mobile/15E148 Safari/605.1.15 DuckDuckGo/\(version)"
        default:
            return prefix + "Version/27.11 Mobile/15E148 Safari/605.1.15"
        }
    }

    private func normalizedIndex(_ index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let remainder = index % count
        return remainder >= 0 ? remainder : remainder + count
    }
}
