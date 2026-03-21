# Meetings Managed iOS App

A modern Swift/SwiftUI iOS WebView application for [meetings-managed.com](https://www.meetings-managed.com).

## Requirements

- **Xcode 15.0+**
- **iOS 16.0+** minimum deployment target
- **Swift 5.9+**
- **CocoaPods** (dependency management)

---

## Quick Start

```bash
# Clone the repository
git clone https://github.com/maxvanreijn1-glitch/meeting-iOS.git
cd meeting-iOS

# Install dependencies
pod install

# Open the workspace (NOT the .xcodeproj)
open Meetingsmanaged.xcworkspace
```

---

## Architecture

This app follows **MVVM** (Model–View–ViewModel) with a clean feature-based folder structure:

```
meeting-iOS/
├── App/
│   ├── MeetingApp.swift          # @main SwiftUI App entry point
│   ├── AppDelegate.swift         # UIApplicationDelegate (lifecycle, push notifications)
│   └── ContentRootView.swift     # Root SwiftUI view
│
├── Core/
│   ├── Models/
│   │   └── AppConfiguration.swift  # Codable models for appConfig.json
│   ├── Services/
│   │   ├── ConfigService.swift     # Loads & exposes app configuration
│   │   ├── NetworkMonitor.swift    # NWPathMonitor-based reachability
│   │   ├── LoggingService.swift    # os.Logger-based unified logging
│   │   └── StorageService.swift    # UserDefaults wrapper
│   ├── Utils/
│   │   └── Extensions.swift        # Swift / SwiftUI / WebKit helpers
│   └── DependencyContainer.swift   # DI wiring
│
├── Features/
│   ├── WebView/
│   │   ├── ViewModels/
│   │   │   └── WebViewModel.swift  # Navigation, loading, JS bridge state
│   │   ├── Views/
│   │   │   ├── WebContainerView.swift      # Main SwiftUI screen
│   │   │   ├── WebViewRepresentable.swift  # UIViewRepresentable WKWebView bridge
│   │   │   ├── LoadingView.swift           # Progress bar
│   │   │   └── OfflineView.swift           # No-network fallback
│   │   └── Services/
│   │       ├── JSBridgeService.swift    # WKScriptMessageHandler bridge
│   │       └── NavigationService.swift  # URL allow/deny decisions
│   └── Settings/
│       ├── ViewModels/
│       │   └── SettingsViewModel.swift
│       └── Views/
│           └── SettingsView.swift
│
├── Tests/
│   └── Unit/
│       ├── ConfigServiceTests.swift
│       ├── NavigationServiceTests.swift
│       ├── StorageServiceTests.swift
│       └── WebViewModelTests.swift
│
└── LeanIOS/            # Legacy Objective-C source (kept for reference)
    └── appConfig.json  # Runtime configuration (do not rename)
```

---

## Technology Stack

| Area                | Technology                              |
|---------------------|-----------------------------------------|
| Language            | Swift 5.9+                              |
| UI Framework        | SwiftUI + NavigationStack               |
| WebView             | WKWebView via `UIViewRepresentable`     |
| Reactive            | Combine (`@Published`, `ObservableObject`) |
| Concurrency         | Swift Concurrency (`async/await`, actors) |
| Networking          | Network framework (`NWPathMonitor`)     |
| Logging             | OSLog (`os.Logger`)                     |
| Persistence         | UserDefaults                            |
| Image Caching       | SDWebImage 5.19+                        |
| HTTP Networking     | Alamofire 5.9+                          |
| Dependencies        | CocoaPods                               |

---

## Configuration

App behaviour is controlled by `LeanIOS/appConfig.json`. Key fields:

| Field                          | Description                          |
|--------------------------------|--------------------------------------|
| `general.initialUrl`           | First URL loaded on launch           |
| `general.appName`              | Navigation bar title                 |
| `navigation.iosPullToRefresh`  | Enable pull-to-refresh gesture       |
| `navigation.iosShowOfflinePage`| Show offline placeholder page        |
| `general.enableWindowOpen`     | Allow `window.open()` calls          |
| `general.injectMedianJS`       | Inject Median JS bridge              |
| `general.iosCustomHeaders`     | HTTP headers added to every request  |

---

## JavaScript Bridge

The app exposes a `window.median` / `window.gonative` bridge to web pages:

```javascript
// Call a native action
window.median.call('share', { url: 'https://example.com' }, function(result) {
    console.log('Share completed:', result);
});

// Listen for app resume
window.addEventListener('median_app_resumed', function() {
    console.log('App returned to foreground');
});
```

---

## Testing

Run unit tests from Xcode (⌘U) or via `xcodebuild`:

```bash
xcodebuild test \
  -workspace Meetingsmanaged.xcworkspace \
  -scheme Meetingsmanaged \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

---

## Deep Links & Universal Links

Universal links are handled in `AppDelegate.application(_:continue:restorationHandler:)`.  
Custom URL schemes (`co.median.ios.zpbekxk://`) are handled in `AppDelegate.application(_:open:options:)`.

---

## Migrating to the New Swift/SwiftUI Architecture

The new Swift files live in `App/`, `Core/`, `Features/`, and `Tests/` directories.  
They are **not yet linked** to the Xcode target by default. Follow these steps once:

### 1. Add new source files to the Xcode target

1. Open `Meetingsmanaged.xcworkspace` in Xcode
2. Drag the `App/`, `Core/`, and `Features/` folders into the **Meetingsmanaged** target in the project navigator  
   (check "Add to target: Meetingsmanaged" for all files)
3. Drag `Tests/Unit/` files into the **MedianIOSTests** target

### 2. Remove legacy entry point

The new `App/MeetingApp.swift` uses `@main` and must be the only app entry point.  
Remove `LeanIOS/main.m` from the **Compile Sources** build phase:

1. Select the **Meetingsmanaged** target → **Build Phases** → **Compile Sources**
2. Delete `main.m` from the list (do NOT delete the file from disk until migration is verified)

### 3. Remove / exclude legacy Objective-C files

Once the Swift implementation is verified to work, remove these from the **Compile Sources** phase  
(or delete them entirely):

- `LeanIOS/LEANAppDelegate.{h,m}`
- `LeanIOS/LEANRootViewController.{h,m}`
- `LeanIOS/LEANWebViewController.{h,m}`
- `LeanIOS/LEAN*Manager.{h,m}` (all manager files)
- `LeanIOS/GN*.{h,m}` (all GN-prefixed files)
- `LeanIOS/REFrostedViewController/` (entire folder)

### 4. Update deployment target

In **Project → Build Settings**:
- `IPHONEOS_DEPLOYMENT_TARGET = 16.0` (already updated in this PR)
- `SWIFT_VERSION = 5.9` (already updated in this PR)

---

## Contributing

1. Create a feature branch from `main`
2. Follow Swift API Design Guidelines
3. Ensure all unit tests pass
4. Submit a pull request with a clear description
