import Foundation
import ReclaimCore

// The root helper. launchd starts it on demand when the app connects to its Mach service.
//
// Usage: ReclaimHelper --client-requirement <code requirement> [--mach-service <name>]
//
// Only a process satisfying the requirement may connect. The installer pins the exact app build, by its
// code hash, in the root-owned launchd plist, so no other program can use the helper.

let arguments = CommandLine.arguments

func argument(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else { return nil }
    return arguments[index + 1]
}

guard let requirement = argument("--client-requirement"), !requirement.isEmpty else {
    FileHandle.standardError.write(Data("ReclaimHelper: refusing to start without --client-requirement\n".utf8))
    exit(64)
}
let machService = argument("--mach-service") ?? HelperConstants.machService

final class HelperService: NSObject, HelperProtocol, @unchecked Sendable {
    /// The home folder of the user on the other end of the connection, from launchd's view of it.
    let policy: PathPolicy

    init(clientUID: uid_t) {
        let home = getpwuid(clientUID).flatMap { String(cString: $0.pointee.pw_dir) } ?? "/var/empty"
        policy = PathPolicy(home: home)
    }

    func version(reply: @escaping @Sendable (Int) -> Void) {
        reply(HelperConstants.protocolVersion)
    }

    func remove(paths: [String], reply: @escaping @Sendable ([String: String]) -> Void) {
        var results: [String: String] = [:]
        for path in paths {
            do {
                results[path] = SafeRemover.remove(try policy.check(path)) ?? ""
            } catch {
                results[path] = error.localizedDescription
            }
        }
        reply(results)
    }

    func measure(paths: [String], reply: @escaping @Sendable ([String: NSNumber]) -> Void) {
        var results: [String: NSNumber] = [:]
        for path in paths {
            guard let target = try? policy.check(path) else { continue }
            results[path] = NSNumber(value: SizeMeasurer.allocatedSize(of: target.path))
        }
        reply(results)
    }

    func deleteLocalSnapshots(dates: [String], reply: @escaping @Sendable ([String: String]) -> Void) {
        var results: [String: String] = [:]
        for date in dates {
            guard SnapshotDate.isValid(date) else {
                results[date] = "Not a snapshot date."
                continue
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
            process.arguments = ["deletelocalsnapshots", date]
            let errors = Pipe()
            process.standardError = errors
            process.standardOutput = FileHandle.nullDevice
            do {
                try process.run()
                process.waitUntilExit()
                let message = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                results[date] = process.terminationStatus == 0 ? "" : (message.isEmpty ? "tmutil failed." : message)
            } catch {
                results[date] = error.localizedDescription
            }
        }
        reply(results)
    }
}

final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        // The listener's code-signing requirement has already rejected any other client by now.
        connection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.exportedObject = HelperService(clientUID: connection.effectiveUserIdentifier)
        connection.resume()
        return true
    }
}

let delegate = ListenerDelegate()
let listener = NSXPCListener(machServiceName: machService)
listener.setConnectionCodeSigningRequirement(requirement)
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
