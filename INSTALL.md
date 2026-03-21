# INSTALL.md – Meeting iOS Setup Guide

## Requirements

| Tool | Version |
|------|---------|
| macOS | 12.0+ |
| Xcode | 14.0+ |
| CocoaPods | 1.12.0+ |
| Ruby | 2.7+ |
| iOS Deployment Target | 13.0+ |

## 1. Install CocoaPods

```bash
sudo gem install cocoapods
```

## 2. Clone the Repository

```bash
git clone https://github.com/maxvanreijn1-glitch/meeting-iOS.git
cd meeting-iOS
```

## 3. Install Dependencies

```bash
pod install
```

This will:
- Download all pods (SSZipArchive, Alamofire, SwiftyJSON, SDWebImage, Realm, CocoaLumberjack)
- Generate `Meetingsmanaged.xcworkspace`
- Generate `Podfile.lock`

## 4. Open the Workspace

**Always open `.xcworkspace`, not `.xcodeproj`:**

```bash
open Meetingsmanaged.xcworkspace
```

## 5. Build and Run

1. Select a simulator or device in the Xcode scheme selector
2. Press **⌘B** to build
3. Press **⌘R** to run

## Dependencies

| Pod | Version | Purpose |
|-----|---------|---------|
| `SSZipArchive` | ~> 2.4 | ZIP archive handling |
| `Alamofire` | ~> 5.7 | HTTP networking |
| `SwiftyJSON` | ~> 5.0 | JSON parsing |
| `SDWebImage` | ~> 5.15 | Async image loading and caching |
| `Realm` | ~> 10.40 | Local data persistence |
| `CocoaLumberjack/Swift` | ~> 3.7 | Logging |

## Troubleshooting

### `pod install` fails with target not found
Ensure the Podfile targets `Meetingsmanaged` (not `LeanIOS`).

### "SSZipArchive.h file not found"
Run `pod install` and open the `.xcworkspace` file (not `.xcodeproj`).

### Signing errors
In Xcode: **Targets → Meetingsmanaged → Signing & Capabilities** → set your Development Team.

### Clean reinstall
```bash
rm -rf Pods Podfile.lock
pod install
```

Then in Xcode: **Product → Clean Build Folder (⇧⌘K)**.
