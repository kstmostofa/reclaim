import Foundation

/// Installed dependencies that a package manager can install again.
public enum DependencyRules {
    /// Where tools, editors and package managers keep packages they installed for themselves, such as
    /// ~/.vscode/extensions/*/node_modules or ~/.composer/vendor. Those have no project to reinstall into.
    static func toolLocations(home: String) -> [String] {
        [home + "/.", home + "/Library/", "/Library/", "/Applications/", "/opt/", "/usr/", "/System/"]
    }

    public static func all(home: String) -> [any Rule] {
        let excluded = toolLocations(home: home)
        return [
            NamedEntryRule(
                id: "deps.nodeModules", title: "Node packages", names: ["node_modules"], siblingMarkers: ["package.json"],
                excludedPrefixes: excluded, category: .dependencies, level: .rebuild,
                reason: "Packages installed from package.json.",
                consequence: "Run npm, pnpm or yarn install in the project before using it again."
            ),
            NamedEntryRule(
                id: "deps.composerVendor", title: "Composer packages", names: ["vendor"], siblingMarkers: ["composer.json"],
                excludedPrefixes: excluded, category: .dependencies, level: .rebuild,
                reason: "PHP packages installed from composer.json.",
                consequence: "Run composer install in the project before using it again."
            ),
            NamedEntryRule(
                id: "deps.pods", title: "CocoaPods", names: ["Pods"], siblingMarkers: ["Podfile"],
                excludedPrefixes: excluded, category: .dependencies, level: .rebuild,
                reason: "Pods installed from the Podfile.",
                consequence: "Run pod install in the project before building it again."
            ),
            NamedEntryRule(
                id: "deps.pythonVenv", title: "Python virtual environment", names: ["venv", ".venv", "env"], childMarker: "pyvenv.cfg",
                excludedPrefixes: excluded, category: .dependencies, level: .rebuild,
                reason: "A Python virtual environment with its installed packages.",
                consequence: "Recreate it with python -m venv and reinstall the project's requirements."
            ),
        ]
    }
}
