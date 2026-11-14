import Darwin
import Foundation

/// What macOS privacy protection lets this app read.
///
/// Without Full Disk Access, opening some folders makes macOS show a consent dialog, and the call that opened
/// the folder waits until someone answers it. A scan must not stall on those, so it skips them instead.
public enum PrivacyAccess {
    /// System Settings › Privacy & Security › Full Disk Access.
    public static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!

    /// True when the app has Full Disk Access. Checked by opening folders only Full Disk Access can read,
    /// which fail quietly, without a dialog, when access is missing. The first one that exists decides.
    public static func hasFullDiskAccess(home: String = NSHomeDirectory()) -> Bool {
        hasFullDiskAccess(probes: [
            "/Library/Application Support/com.apple.TCC",
            home + "/Library/Safari", home + "/Library/Mail", home + "/Library/Messages",
        ])
    }

    static func hasFullDiskAccess(probes: [String]) -> Bool {
        for probe in probes {
            if let dir = opendir(probe) {
                closedir(dir)
                return true
            }
            if errno == EPERM || errno == EACCES { return false }
        }
        // None of them exist, so there is no way to tell; assume access rather than hide folders for nothing.
        return true
    }

    /// Folders that make macOS ask for consent when an app without Full Disk Access opens them.
    public static func promptingLocations(home: String = NSHomeDirectory()) -> [String] {
        [
            "Desktop", "Documents", "Downloads",
            "Library/Mobile Documents", "Library/CloudStorage",
            "Library/Containers", "Library/Group Containers",
            "Library/Calendars", "Library/Reminders", "Library/Application Support/AddressBook",
            "Library/Application Support/CallHistoryDB",
        ].map { home + "/" + $0 } + alwaysPromptingLocations(home: home)
    }

    /// Media libraries that make macOS ask for consent even with Full Disk Access, because Music, TV and
    /// Photos have permissions of their own. Scans always skip these; they hold nothing Reclaim would suggest.
    public static func alwaysPromptingLocations(home: String = NSHomeDirectory()) -> [String] {
        ["Music/Music", "Music/iTunes", "Movies/TV", "Pictures/Photos Library.photoslibrary",
         "Pictures/Photo Booth Library", "Library/Photos"].map { home + "/" + $0 }
    }

    /// Short names for the skipped folders, for telling the user.
    public static let promptingSummary = "Desktop, Documents, Downloads, iCloud Drive and other apps' data"
}
