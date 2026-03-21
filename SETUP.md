# Meeting iOS – Setup & Build Guide

## Prerequisites

- **Xcode 14+** (macOS only)
- **CocoaPods** – dependency manager for iOS projects
- **Ruby** – required for CocoaPods and `plugins.rb`

## 1. Install CocoaPods

If CocoaPods is not already installed, run:

```bash
sudo gem install cocoapods
```

## 2. Install Project Dependencies

Navigate to the project root and install all pods:

```bash
cd /path/to/meeting-iOS
pod install
```

> **Important:** `pod install` generates (or updates) `Podfile.lock` and the `Pods/` directory.  
> You must run this before opening the project in Xcode.

## 3. Open the Workspace in Xcode

Always open the **`.xcworkspace`** file — **not** the `.xcodeproj`:

```bash
open Meetingsmanaged.xcworkspace
```

Or in Xcode: **File → Open → Meetingsmanaged.xcworkspace**

## 4. Build & Run

1. Select a simulator or connected device from the scheme selector.
2. Press **⌘B** (or **Product → Build**) to build.
3. Press **⌘R** (or **Product → Run**) to run.

## 5. Clean Build (if needed)

If you encounter build issues after updating pods or switching branches:

```bash
# Remove derived data and pods
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf Pods Podfile.lock

# Reinstall
pod install
```

Then clean in Xcode: **Product → Clean Build Folder (⇧⌘K)**.

## Dependencies

| Pod | Version | Purpose |
|-----|---------|---------|
| `SSZipArchive` | ~> 2.6.0 | ZIP file handling |

Additional service plugins (e.g. push notifications) are loaded automatically from `LeanIOS/appConfig.json` via `plugins.rb`.

## Minimum Requirements

| Requirement | Version |
|-------------|---------|
| iOS Deployment Target | 13.0+ |
| Xcode | 14.0+ |
| CocoaPods | 1.12.0+ |

## Troubleshooting

### "No such module" errors
- Make sure you opened the `.xcworkspace` and ran `pod install` first.

### Signing errors
- In Xcode, go to **Targets → Meetingsmanaged → Signing & Capabilities** and set your Development Team.

### Pod install fails with checksum mismatch
- Delete `Podfile.lock` and `Pods/`, then run `pod install` again.
