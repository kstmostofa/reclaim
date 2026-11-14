# FAQ (/docs/faq)

## Safety [#safety]

### Why is there no "Are you sure?" [#why-is-there-no-are-you-sure]

Because cleaning a developer Mac means deleting hundreds of items, and a confirmation for each one gets clicked through without reading. Instead, Reclaim explains every item before you tick it, ticks only Safe items for you, and refuses to delete protected folders at all. If you want a safety net, turn on [Move to Trash](/docs/settings#general).

### Will Reclaim ever delete things on its own? [#will-reclaim-ever-delete-things-on-its-own]

Only if you turn on auto-clean for scheduled scans, which is off by default. Even then it deletes only Safe items that nothing changed for 24 hours. See [how auto-clean works](/docs/automation#auto-clean).

### Can I undo a deletion? [#can-i-undo-a-deletion]

Not when deleting permanently, which is the default. With Move to Trash on, items go to the Trash and you can put them back from there until you empty it.

### Is it safe to delete Safe items while I am working? [#is-it-safe-to-delete-safe-items-while-i-am-working]

Usually. Quit an app before deleting its cache, and stop a dev server before deleting its project's build cache. Otherwise the app may recreate files mid-way or show errors until restarted.

### Why was something not deleted? [#why-was-something-not-deleted]

The summary after deleting gives the reason for each item. Most often the files belong to root, for example ones created with `sudo npm install`. Install the [helper](/docs/system) to delete those. Files macOS itself protects cannot be deleted by any app.

### Is a helper that runs as root safe? [#is-a-helper-that-runs-as-root-safe]

It deletes only inside system cache and log folders and your own home folder, never a protected folder, and refuses tricks with `..` and symlinks. It only answers the exact copy of Reclaim that installed it. The source is public, and you can remove it any time from System.

## Protected folders [#protected-folders]

These are never deleted as a whole, however the path is written: with different capital letters, through a symlink, or as `/System/Volumes/Data/…`. Everything inside them, apart from the system folders, can still be deleted.

- The disk root, and every folder directly in it, such as `/Applications`, `/Library`, `/Users` and `/opt`.
- Everything in `/System`, `/usr` (except `/usr/local`), `/bin` and `/sbin`.
- The folders directly in `/private`, and system folders such as `/Library/Caches` and `/opt/homebrew`.
- Every user's home folder, and every mounted volume in `/Volumes`.
- In your home: Desktop, Documents, Downloads, Movies, Music, Pictures, Public, Applications, the Trash, Library, and Library's main folders such as Application Support, Caches, Containers and Preferences.

Separately, macOS itself stops any app from changing its system files.

## Sizes [#sizes]

### Why do Reclaim's sizes differ from Finder's? [#why-do-reclaims-sizes-differ-from-finders]

Reclaim shows the space files actually take on disk; Finder often shows how long files are. They differ for sparse files such as virtual-machine disks, which can claim 64 GB while using a few, and for small files, which still occupy at least one disk block. Hard-linked files are counted once.

### Why doesn't free space go up by exactly what I deleted? [#why-doesnt-free-space-go-up-by-exactly-what-i-deleted]

Files that were APFS copies of each other shared their storage; local Time Machine snapshots still hold the deleted data until macOS removes them; and macOS counts "purgeable" space as free. The figure settles within a few minutes.

### Why doesn't the scan total match the used space? [#why-doesnt-the-scan-total-match-the-used-space]

Folders Reclaim cannot read are missing from the total (give it [Full Disk Access](/docs/install#give-it-full-disk-access)), and the disk also holds snapshots and file-system data that are not files.

## Permissions [#permissions]

### Why are my Desktop, Documents and Downloads missing from the scan? [#why-are-my-desktop-documents-and-downloads-missing-from-the-scan]

Reclaim does not have Full Disk Access yet. Without it, macOS shows a permission dialog for each of those folders and holds the scan until you answer, so Reclaim skips them instead. [Turn on Full Disk Access](/docs/install#give-it-full-disk-access) and scan again.

### Why does it need Full Disk Access? [#why-does-it-need-full-disk-access]

macOS hides other apps' data, Mail, Messages and parts of your Library from apps by default. Without access, those folders are not measured or suggested. Reclaim works without it, but sees less.

### Why isn't it in the Mac App Store? [#why-isnt-it-in-the-mac-app-store]

App Store apps run in a sandbox that cannot read or delete files across the disk, which is the whole point of Reclaim.

### Why does macOS block it the first time? [#why-does-macos-block-it-the-first-time]

The app is not notarized, which requires a paid Apple developer membership. Follow [Open it the first time](/docs/install#open-it-the-first-time), or build it from source.

## Privacy [#privacy]

### Does Reclaim send anything over the network? [#does-reclaim-send-anything-over-the-network]

No. It has no account, no analytics and no update check. The scan and your file list stay on your Mac. Its only files are its settings and the [deletion history](/docs/guide#history).