import Darwin

/// Tells whether two files are APFS clones that share their storage, so deleting one frees nothing.
///
/// Compares the physical disk address of each file's first and last block. Clones made by Finder's
/// Duplicate or `cp -c` start out sharing every block; a clone edited later may share only some, and is then
/// treated as separate when either end differs.
public enum CloneDetector {
    /// Physical addresses of the first and last block, or nil when they cannot be read.
    public struct Fingerprint: Hashable, Sendable {
        let first: Int64
        let last: Int64
    }

    public static func fingerprint(path: String, size: Int64) -> Fingerprint? {
        let fd = open(path, O_RDONLY)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        guard let first = physicalOffset(fd: fd, at: 0) else { return nil }
        let lastOffset = max(0, (size - 1) / 4096 * 4096)
        guard let last = physicalOffset(fd: fd, at: lastOffset) else { return nil }
        return Fingerprint(first: first, last: last)
    }

    private static func physicalOffset(fd: Int32, at offset: Int64) -> Int64? {
        guard lseek(fd, off_t(offset), SEEK_SET) == offset else { return nil }
        var request = log2phys()
        request.l2p_contigbytes = 4096
        request.l2p_devoffset = 0
        guard fcntl(fd, F_LOG2PHYS_EXT, &request) == 0 else { return nil }
        return request.l2p_devoffset
    }
}
