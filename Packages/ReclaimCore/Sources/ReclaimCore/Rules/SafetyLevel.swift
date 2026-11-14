import Foundation

/// How risky it is to delete an item. Drives what is pre-ticked in the app.
public enum SafetyLevel: String, Codable, Sendable, CaseIterable, Comparable {
    /// Rebuilds itself; nothing for the user to do.
    case safe
    /// Comes back only after a reinstall or re-download.
    case rebuild
    /// The user's own data; only reported.
    case personal

    public var isPreselected: Bool { self == .safe }

    public var title: String {
        switch self {
        case .safe: "Safe"
        case .rebuild: "Rebuild"
        case .personal: "Personal"
        }
    }

    private var order: Int {
        switch self {
        case .safe: 0
        case .rebuild: 1
        case .personal: 2
        }
    }

    public static func < (lhs: SafetyLevel, rhs: SafetyLevel) -> Bool { lhs.order < rhs.order }
}

/// The groups suggestions are listed under in the sidebar.
public enum SuggestionCategory: String, Codable, Sendable, CaseIterable {
    case buildCache
    case dependencies
    case packageManagerCache
    case appCache
    case logs
    case mobileTooling
    case appLeftovers
    case trash
    case oldDownloads
    case largeFiles
    case duplicates
    case containers
    case custom

    public var title: String {
        switch self {
        case .buildCache: "Build Caches"
        case .dependencies: "Dependencies"
        case .packageManagerCache: "Package Caches"
        case .appCache: "App Caches"
        case .logs: "Logs"
        case .mobileTooling: "Mobile Tooling"
        case .appLeftovers: "App Leftovers"
        case .trash: "Trash"
        case .oldDownloads: "Old Downloads"
        case .largeFiles: "Large Files"
        case .duplicates: "Duplicates"
        case .containers: "Docker"
        case .custom: "Your Rules"
        }
    }

    /// SF Symbol name.
    public var systemImage: String {
        switch self {
        case .buildCache: "hammer"
        case .dependencies: "shippingbox"
        case .packageManagerCache: "archivebox"
        case .appCache: "square.stack.3d.up"
        case .logs: "doc.text"
        case .mobileTooling: "iphone"
        case .appLeftovers: "app.dashed"
        case .trash: "trash"
        case .oldDownloads: "arrow.down.circle"
        case .largeFiles: "doc.richtext"
        case .duplicates: "doc.on.doc"
        case .containers: "shippingbox.circle"
        case .custom: "slider.horizontal.3"
        }
    }
}
