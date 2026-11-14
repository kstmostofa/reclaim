# Scan and clean (/docs/guide)

## Scanning [#scanning]

Click **Scan** on the Overview, or press <kbd>⌘</kbd> <kbd>R</kbd>. Reclaim reads every folder it is allowed to and shows a live count of files and bytes. A full Mac takes about a minute; click **Stop** at any time.

- **Whole disk by default.** To scan only your home folder, change [Scanning › Scan](/docs/settings#scanning).
- **Real sizes.** Reclaim counts the space files actually use. A 32 GB disk image holding 1 GB counts as 1 GB, and a file with several hard links counts once.
- **One disk only.** External drives and other volumes are never scanned.
- **Without Full Disk Access**, Desktop, Documents, Downloads, iCloud Drive and other apps' data are skipped, so macOS doesn't pause the scan to ask about each one. [Turn it on](/docs/install#give-it-full-disk-access).

## The Overview [#the-overview]

<Screenshot src="overview.png" alt="Overview with a storage bar, the last scan's summary and the top categories." />

- **Storage bar:** used space, the part Reclaim suggests deleting in your accent colour, and free space.
- **Last scan:** how much you could reclaim, how much of it is Safe, and how long the scan took.
- **Top categories:** each kind of suggestion with its size. Click one to open it.

## Reviewing suggestions [#reviewing-suggestions]

The sidebar has one entry per kind of suggestion, with its total size. [What it finds](/docs/what-it-finds) lists every rule. Each list shows a checkbox, the item's name and folder, its size, its safety level and when anything inside it last changed.

- **Sort** by clicking a column header, and **filter** with the search field (<kbd>⌘</kbd> <kbd>F</kbd>).
- **Select All Safe** ticks every Safe item in the list; **Deselect All** unticks the list.
- **Right-click** rows to tick or untick several at once, or to reveal one in Finder.
- **The inspector** on the right explains the selected item: what it is, why it is suggested, what happens after deleting it, and where it is.

<Callout type="warn">
An orange warning next to an app's cache means that app is running; quit it before deleting its files. A lock means the item belongs to root, and deleting it needs the [helper](/docs/system).
</Callout>

## Safety levels [#safety-levels]

| Level | Meaning | Ticked for you |
| --- | --- | --- |
| <Level of="safe" /> | Rebuilds itself; nothing for you to do. Build caches, app caches, logs, emulator snapshots, the Trash. | Yes |
| <Level of="rebuild" /> | Comes back after a reinstall or download, such as `npm install` or `composer install`. | No |
| <Level of="personal" /> | Your data, reported so you can decide: old downloads, large files, duplicates, emulator user data. | No |

To stop Reclaim ticking Safe items after each scan, turn off [Tick Safe items after each scan](/docs/settings#general).

## Deleting [#deleting]

Whenever something is ticked, a bar at the bottom shows how many items and how much space, such as **Delete 23 items · 31.4 GB**. Ticks carry across every list, the Disk Map, Duplicates and Containers, and an item inside a ticked folder is never counted twice.

<Callout type="warn" title="There is no confirmation">
The button, or <kbd>⌘</kbd> <kbd>⌫</kbd>, deletes ticked items immediately and permanently. For a safety net, turn on [Move to Trash instead of deleting permanently](/docs/settings#general); space is then freed only when you empty the Trash.
</Callout>

A sheet shows progress, then a summary of what was freed and anything that could not be removed, with the reason:

- **Belongs to another user**, such as root: files created with `sudo` or by the system. The [helper](/docs/system) can delete these.
- **It no longer exists:** something else removed it after the scan.
- **Protected:** one of the folders Reclaim never deletes as a whole. See the [FAQ](/docs/faq#protected-folders).

Lists and the Disk Map update straight away; no rescan is needed.

## History [#history]

Every run is recorded: when, what was deleted or moved to the Trash, its size and anything that failed. The log is kept at `~/Library/Application Support/Reclaim/history.jsonl`.

## Keyboard shortcuts [#keyboard-shortcuts]

| Shortcut | Action |
| --- | --- |
| <kbd>⌘</kbd> <kbd>R</kbd> | Scan |
| <kbd>⌘</kbd> <kbd>⌫</kbd> | Delete ticked items, with no confirmation |
| <kbd>⌘</kbd> <kbd>F</kbd> | Filter the current list |
| <kbd>⌘</kbd> <kbd>↑</kbd> | Enclosing folder in the Disk Map |
| <kbd>⌘</kbd> <kbd>,</kbd> | Settings |