import Foundation

/// Emulator and simulator data.
public enum MobileToolingRules {
    public static func all(home: String) -> [any Rule] {
        [
            NamedEntryRule(
                id: "mobile.avdSnapshots", title: "Android emulator snapshots", names: ["snapshots"], siblingMarkers: ["config.ini"],
                category: .mobileTooling, level: .safe,
                reason: "Quick-boot snapshots of an Android emulator.",
                consequence: "The emulator cold-boots once and saves a new snapshot."
            ),
            NamedEntryRule(
                id: "mobile.avdUserData", title: "Android emulator user data",
                names: ["userdata-qemu.img", "userdata-qemu.img.qcow2"], directoriesOnly: false, siblingMarkers: ["config.ini"],
                category: .mobileTooling, level: .personal,
                reason: "Apps and data installed inside an Android emulator.",
                consequence: "The emulator starts as if factory reset; installed apps and their data are lost."
            ),
            LocationRule(
                id: "mobile.iosDeviceSupport", title: "iOS device support", path: home + "/Library/Developer/Xcode/iOS DeviceSupport",
                matchChildren: true,
                category: .mobileTooling, level: .rebuild,
                reason: "Debug symbols copied from a device running this iOS version.",
                consequence: "Xcode copies them again, which takes several minutes, next time that device is connected."
            ),
            LocationRule(
                id: "mobile.coreSimulatorCaches", title: "Simulator caches", path: home + "/Library/Developer/CoreSimulator/Caches",
                category: .mobileTooling, level: .safe,
                reason: "Caches kept by the iOS Simulator.",
                consequence: "Recreated by the Simulator when needed."
            ),
        ]
    }
}
