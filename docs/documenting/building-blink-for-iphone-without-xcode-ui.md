# Building Blink for iPhone (without using the Xcode UI)

This document explains what’s realistically possible when building Blink for a **physical iPhone** while avoiding the **Xcode GUI** as much as possible.

## Reality check: “without Xcode”

- **You cannot build an iOS app without Apple’s iOS SDK**, which is distributed as part of **Xcode**.
- What *is* realistic: install Xcode, do any required “first time” account/signing setup once, and then build/install primarily from the **terminal** via `xcodebuild` and `xcrun`.

## Requirements

- macOS with Xcode installed (`xcode-select -p` should point at `/Applications/Xcode.app/Contents/Developer`)
- A physical iPhone + USB connection (or paired Wi‑Fi debugging)
- Apple code signing:
  - **Recommended:** paid Apple Developer Program membership (stable signing, fewer restrictions)
  - **Possible but limited:** free Apple ID provisioning (often requires disabling capabilities; profiles expire quickly)

## One-time Xcode setup (mostly CLI)

Even if you avoid the Xcode UI day-to-day, a one-time setup step is common:

- Accept Xcode license / run first-launch setup:

```bash
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
```

- Sign into your Apple ID in Xcode at least once if you want “automatic signing” to work smoothly (certs/profiles end up in your login keychain).

## Project prep (dependencies/resources)

If you don’t already have frameworks/resources downloaded, follow the repo’s README build step:

```bash
./get_frameworks.sh
./get_resources.sh
rm -rf Blink.xcodeproj/project.xcworkspace/xcshareddata/
```

## Configure identifiers (bundle + team)

Blink uses an `.xcconfig` file to set your team and bundle identifiers.

1) Copy the template (if you haven’t already):

```bash
cp template_setup.xcconfig developer_setup.xcconfig
```

2) Edit `developer_setup.xcconfig`:

- `TEAM_ID` **must be your 10‑character Apple Team ID** (not your email).
  - Find it in the Apple Developer portal: **Membership** section.
- `BUNDLE_ID` should be unique to you (e.g. `com.yourname.blink`).

## (Optional) Disable capabilities that require extra setup

Blink may include capabilities like iCloud, Push Notifications, and Keychain Sharing.

- If you’re trying to build with minimal signing friction (especially on a free account), you may need to **turn these off** in the Xcode project’s target settings and/or adjust entitlements.
- The upstream README also suggests disabling them if you want to build without those features.

There isn’t a fully “no‑Xcode‑UI ever” way to toggle capabilities, because they’re stored in the project configuration and entitlements.

## Build from the terminal (device)

Use `xcodebuild` to compile for a connected iPhone. The example below puts build outputs in a predictable location.

1) Find your device identifier:

```bash
xcrun devicectl list devices
```

2) Build for the device:

```bash
DERIVED_DATA="$PWD/build/DerivedData"
DEVICE="<your device udid (or name)>"

xcodebuild \
  -project Blink.xcodeproj \
  -scheme Blink \
  -configuration Debug \
  -destination "platform=iOS,id=$DEVICE" \
  -derivedDataPath "$DERIVED_DATA" \
  -allowProvisioningUpdates \
  build
```

If you want Xcode to auto-register your device on your developer account as part of automatic signing, you can also add:

```bash
-allowProvisioningDeviceRegistration
```

The resulting app bundle is typically at:

```bash
APP="$DERIVED_DATA/Build/Products/Debug-iphoneos/Blink.app"
```

## Install onto the iPhone (CLI)

With modern Xcode, `devicectl` is the supported CLI installer:

```bash
xcrun devicectl device install app --device "$DEVICE" "$APP"
```

If you see authorization prompts/errors, make sure the iPhone is unlocked, you’ve tapped “Trust This Computer”, and Xcode has completed any one-time device setup.

## Common issues / troubleshooting

- **“TEAM_ID is an email”**: `TEAM_ID` must be the 10‑char Team ID from the Developer portal.
- **Provisioning/codesign failures**:
  - Ensure you are signed into Xcode at least once so it can manage certificates/profiles.
  - Re-run the build with `-allowProvisioningUpdates`.
- **Entitlements/capabilities errors**:
  - Disable iCloud/Push/Keychain Sharing (or configure them properly) to match your account.
  - Free accounts are much more likely to hit capability restrictions.
- **Device not found**:
  - Confirm `xcrun devicectl list devices` shows the phone.
  - Reconnect USB, unlock device, and ensure you’ve trusted the computer.
- **`devicectl` “Authorization is required …”**:
  - Unlock the iPhone and confirm you tapped “Trust This Computer”.
  - On macOS, ensure the terminal app has **Developer Tools** permission (System Settings → Privacy & Security → Developer Tools).
  - You may need to open Xcode once and let it finish device/pairing setup.

## Notes

- Running on a physical device always requires Apple signing; there’s no supported way around that.
- Apple’s terms apply when building/installing on personal devices.
