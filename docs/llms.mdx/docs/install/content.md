# Install (/docs/install)

## Download [#download]

<Steps>
<Step>
### Get the app [#get-the-app]

[Download Reclaim.dmg](https://github.com/kstmostofa/reclaim/releases/latest/download/Reclaim.dmg), the latest version, ready to run: there is nothing to build. The [release page](https://github.com/kstmostofa/reclaim/releases/latest) also has `Reclaim.dmg.sha256` to check it, and the same app as `Reclaim.zip`.
</Step>

<Step>
### Check the download (optional) [#check-the-download-optional]

In Terminal, in the folder you downloaded to:

```sh
shasum -a 256 -c Reclaim.dmg.sha256
```

It should print `Reclaim.dmg: OK`.
</Step>

<Step>
### Move it to Applications [#move-it-to-applications]

Double-click `Reclaim.dmg` and drag **Reclaim** onto the **Applications** folder in the window that opens. Then eject the disk image in Finder.
</Step>
</Steps>

## Open it the first time [#open-it-the-first-time]

Reclaim is not notarized by Apple, because notarization needs a paid developer membership, so macOS blocks it the first time. You do this once per version.

<Steps>
<Step>
### Try to open it [#try-to-open-it]

Double-click Reclaim in Applications. macOS says it cannot verify the app. Click **Done**.
</Step>

<Step>
### Open Privacy & Security [#open-privacy--security]

Go to **System Settings › Privacy & Security** and scroll to the Security section.
</Step>

<Step>
### Allow it [#allow-it]

Next to the message about Reclaim, click **Open Anyway** and confirm with your password or Touch ID.
</Step>
</Steps>

<Callout>
The source is public, so you can also [build it yourself](#build-from-source) instead of trusting a download.
</Callout>

## Give it Full Disk Access [#give-it-full-disk-access]

Without it, macOS asks for permission the first time any app opens Desktop, Documents, Downloads, iCloud Drive or another app's data, and the app has to wait for your answer. To keep scans from stalling, Reclaim skips those folders until it has Full Disk Access, and the Overview says so, with a button to the right settings page.

<Steps>
<Step>
### Open the setting [#open-the-setting]

Go to **System Settings › Privacy & Security › Full Disk Access**.
</Step>

<Step>
### Add Reclaim [#add-reclaim]

Click **+**, choose **Reclaim** in Applications, and make sure its switch is on.
</Step>

<Step>
### Scan again [#scan-again]

Quit and reopen Reclaim, then scan.
</Step>
</Steps>

No app can grant this to itself, and Reclaim never asks again once it is on.

<Callout>
Your Music, TV and Photos libraries are always skipped, even with Full Disk Access, because macOS protects them with permissions of their own. Reclaim never suggests anything inside them.
</Callout>

## Updating [#updating]

Download the new release and replace the old app in Applications. Because each build is signed separately, macOS may ask you to repeat **Open Anyway**, you may need to switch Full Disk Access off and on again, and the [helper](/docs/system#after-updating-reclaim), if you use it, asks to be paired again.

## Uninstalling [#uninstalling]

<Steps>
<Step>
### Remove the helper [#remove-the-helper]

If you installed it: open **System** in the sidebar and click **Remove Helper…**.
</Step>

<Step>
### Remove the app [#remove-the-app]

Quit Reclaim and move it from Applications to the Trash.
</Step>

<Step>
### Remove its settings and history (optional) [#remove-its-settings-and-history-optional]

```sh
rm ~/Library/Preferences/io.github.kstmostofa.reclaim.plist
rm -r ~/Library/Application\ Support/Reclaim
```
</Step>

<Step>
### Tidy up permissions [#tidy-up-permissions]

Remove it from **Full Disk Access** and, if you turned it on, from **Login Items** in System Settings.
</Step>
</Steps>

## Build from source [#build-from-source]

You need Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
git clone https://github.com/kstmostofa/reclaim.git
cd reclaim
xcodegen generate
open Reclaim.xcodeproj
```

The engine's tests run with `swift test` in `Packages/ReclaimCore`. They only ever create and delete files in temporary folders.