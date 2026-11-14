import AppKit
import Observation
import ReclaimCore
import SwiftUI

/// Every user preference, stored in UserDefaults.
@MainActor @Observable
final class AppSettings {
    enum Accent: String, CaseIterable, Identifiable {
        case indigo, blue, purple, pink, red, orange, yellow, green, mint, teal, cyan, graphite, custom

        var id: String { rawValue }
        var title: String { rawValue.capitalized }

        var color: Color? {
            switch self {
            case .indigo: .indigo
            case .blue: .blue
            case .purple: .purple
            case .pink: .pink
            case .red: .red
            case .orange: .orange
            case .yellow: .yellow
            case .green: .green
            case .mint: .mint
            case .teal: .teal
            case .cyan: .cyan
            case .graphite: .gray
            case .custom: nil
            }
        }
    }

    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark

        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    enum ScanScope: String, CaseIterable, Identifiable {
        case wholeDisk, homeFolder

        var id: String { rawValue }
        var title: String { self == .wholeDisk ? "The whole disk" : "My home folder" }
        var root: String { self == .wholeDisk ? DiskScanner.dataVolumePath : NSHomeDirectory() }
    }

    private let defaults = UserDefaults.standard

    var accent: Accent { didSet { defaults.set(accent.rawValue, forKey: "accent") } }
    var customAccentHex: String { didSet { defaults.set(customAccentHex, forKey: "customAccentHex") } }
    var appearance: Appearance {
        didSet {
            defaults.set(appearance.rawValue, forKey: "appearance")
            applyAppearance()
        }
    }
    var moveToTrash: Bool { didSet { defaults.set(moveToTrash, forKey: "moveToTrash") } }
    var preselectSafe: Bool { didSet { defaults.set(preselectSafe, forKey: "preselectSafe") } }
    var scanScope: ScanScope { didSet { defaults.set(scanScope.rawValue, forKey: "scanScope") } }
    var excludedFolders: [String] { didSet { defaults.set(excludedFolders, forKey: "excludedFolders") } }
    /// Large Files lists files of at least this many megabytes.
    var largeFileThresholdMB: Int { didSet { defaults.set(largeFileThresholdMB, forKey: "largeFileThresholdMB") } }
    var downloadsAgeDays: Int { didSet { defaults.set(downloadsAgeDays, forKey: "downloadsAgeDays") } }
    /// Duplicates compares files of at least this many megabytes.
    var duplicateMinimumMB: Int { didSet { defaults.set(duplicateMinimumMB, forKey: "duplicateMinimumMB") } }

    init() {
        accent = Accent(rawValue: defaults.string(forKey: "accent") ?? "") ?? .indigo
        customAccentHex = defaults.string(forKey: "customAccentHex") ?? "#5856D6"
        appearance = Appearance(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .system
        moveToTrash = defaults.bool(forKey: "moveToTrash")
        preselectSafe = defaults.object(forKey: "preselectSafe") as? Bool ?? true
        scanScope = ScanScope(rawValue: defaults.string(forKey: "scanScope") ?? "") ?? .wholeDisk
        excludedFolders = defaults.stringArray(forKey: "excludedFolders") ?? []
        largeFileThresholdMB = defaults.object(forKey: "largeFileThresholdMB") as? Int ?? 500
        downloadsAgeDays = defaults.object(forKey: "downloadsAgeDays") as? Int ?? OldDownloadsRule.defaultDays
        duplicateMinimumMB = defaults.object(forKey: "duplicateMinimumMB") as? Int ?? 1
    }

    var accentColor: Color {
        accent.color ?? Color(hex: customAccentHex) ?? .indigo
    }

    var customAccent: Color {
        get { Color(hex: customAccentHex) ?? .indigo }
        set { customAccentHex = newValue.hexString }
    }

    var largeFileThreshold: Int64 { Int64(largeFileThresholdMB) * 1_000_000 }

    func applyAppearance() {
        NSApp?.appearance = switch appearance {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    func resetToDefaults() {
        for key in ["accent", "customAccentHex", "appearance", "moveToTrash", "preselectSafe", "scanScope",
                    "excludedFolders", "largeFileThresholdMB", "downloadsAgeDays", "duplicateMinimumMB"] {
            defaults.removeObject(forKey: key)
        }
        let fresh = AppSettings()
        accent = fresh.accent
        customAccentHex = fresh.customAccentHex
        appearance = fresh.appearance
        moveToTrash = fresh.moveToTrash
        preselectSafe = fresh.preselectSafe
        scanScope = fresh.scanScope
        excludedFolders = fresh.excludedFolders
        largeFileThresholdMB = fresh.largeFileThresholdMB
        downloadsAgeDays = fresh.downloadsAgeDays
        duplicateMinimumMB = fresh.duplicateMinimumMB
    }
}

extension Color {
    init?(hex: String) {
        let digits = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(.sRGB,
                  red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }

    var hexString: String {
        guard let rgb = NSColor(self).usingColorSpace(.sRGB) else { return "#5856D6" }
        let r = Int((rgb.redComponent * 255).rounded())
        let g = Int((rgb.greenComponent * 255).rounded())
        let b = Int((rgb.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
