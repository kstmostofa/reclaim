# Changelog

## 1.0.0

The first release of Reclaim, a free, open-source Mac storage cleaner for developers. Download `Reclaim.dmg` and drag Reclaim to Applications; `Reclaim.zip` holds the same app.

### Scan and clean
- Scans the whole disk in parallel, measuring the space files really use: hard links count once, sparse disk images count what they occupy, and other drives are left alone.
- Suggestions grouped by kind, each labelled **Safe**, **Rebuild** or **Personal** and explained: what it is, why it is listed, and what happens after deleting it. Only Safe items are ticked for you.
- Rules for build caches (`.next`, `.nuxt`, `.turbo`, `.svelte-kit`, `.parcel-cache`, `.dart_tool`, `__pycache__`, Rust `target`, Gradle, Android build intermediates, Xcode DerivedData), dependencies (`node_modules`, `vendor`, `Pods`, Python virtual environments), package-manager caches (npm, pnpm, Yarn, pip, Composer, Gradle, Homebrew, CocoaPods, Cargo, Go, pub, Playwright), app caches and logs, mobile tooling, leftovers of uninstalled apps, the Trash and old downloads.
- One-click delete with no confirmation per file, a progress toast, and the reason for anything that could not be removed. Optional Move to Trash mode. Every run is kept in a history.
- Protected folders (the disk root, system folders, every home folder and its main folders) are never deleted as a whole, however the path is written.

### Explore
- Disk Map: the whole disk as a size-sorted tree; drill in and tick anything that is not protected.
- Large Files, and Duplicates: byte-for-byte matches only, with hard links and APFS copies that share storage handled correctly.
- Docker and OrbStack: build cache, dangling and unused images, stopped containers and unused volumes, removed with Docker's own commands.
- System: an optional root helper, locked to this app, for system caches and logs, root-owned leftovers and local Time Machine snapshots.

### Around the Mac
- Menu-bar monitor with free space, Scan Now and Clean Safe Items.
- Daily or weekly scheduled scans, optional auto-clean of Safe items untouched for a day, low-space alerts, open at login.
- Light and dark, Indigo or any accent colour.

### Known limitations
- Not notarized: open it the first time through System Settings › Privacy & Security › Open Anyway.
- Full Disk Access must be granted once in System Settings, and again after updating.
- After updating, the helper asks to be paired again.
- Tested on Apple silicon with macOS 27; built for Apple silicon and Intel, macOS 14 and later.
