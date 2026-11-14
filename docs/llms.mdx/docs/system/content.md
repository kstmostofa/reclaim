# System and the helper (/docs/system)

Some caches, logs and leftovers belong to root, the system's administrator account. Reclaim can't delete them on its own; its optional helper can.

## What the helper handles [#what-the-helper-handles]

- **System caches** in `/Library/Caches`.
- **System logs** in `/Library/Logs` and `/private/var/log`.
- **Root-owned files in your home folder**, such as those left by `sudo npm install`.
- **Local Time Machine snapshots**.

Items that need the helper show a lock until it is installed, and Safe ones are only ticked for you once it is.

## Installing [#installing]

<Steps>
<Step>
### Open System [#open-system]

Click **System** in the sidebar, then **Install Helper…**.
</Step>

<Step>
### Enter your password [#enter-your-password]

macOS asks in its own dialog. Reclaim never sees it.
</Step>
</Steps>

The helper is copied to `/Library/PrivilegedHelperTools` and started by macOS whenever Reclaim needs it. After that, deleting works as usual: anything Reclaim may not delete is passed to the helper automatically when deleting permanently. In Move to Trash mode, such items are left alone.

## What keeps it safe [#what-keeps-it-safe]

<Cards>
<Card title="Fixed folders only" description="System cache and log folders and your own home folder, after resolving symlinks. Never a protected folder." />

<Card title="No path tricks" description="Paths with .. are refused, and so is a folder swapped for a link at the last moment." />

<Card title="One app only" description="Paired with the exact build of Reclaim that installed it. Any other program is refused." />

<Card title="Open source" href="https://github.com/kstmostofa/reclaim" description="The helper is small, and its rules are tested. Read it on GitHub." />
</Cards>

## After updating Reclaim [#after-updating-reclaim]

The pairing names one exact build, so after an update the helper refuses the new version. **System** then shows **Pair Again…**, which asks for your password once more. A paid Apple developer certificate would remove this step.

## Local Time Machine snapshots [#local-time-machine-snapshots]

Time Machine keeps snapshots on your Mac's disk between backups, and they hold on to the space of files you deleted since. System lists them; with the helper installed you can tick and delete them. Backups on your backup disk are not affected, and macOS also removes local snapshots on its own when space runs low.

## Removing the helper [#removing-the-helper]

Click **Remove Helper…** in System and enter your password. Everything else in Reclaim keeps working without it.