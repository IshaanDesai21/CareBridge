# CareBridge iOS App

## Overview
Native iOS application for the CareBridge platform, providing caregivers and patients with a comprehensive mobile care management solution.

## Requirements
- Xcode 15.0+
- iOS 17.0+
- Swift 5.9+

## Setup

### Installation
```bash
# Clone the repository
git clone <repository-url>
cd CareBridge/ios

# Open the project
open CareBridge.xcodeproj
```

### Configuration
1. Open the project in Xcode
2. Select the CareBridge target
3. Update the signing & capabilities with your team
4. Add required API keys to `Config.xcconfig`

### Dependencies
This project uses Swift Package Manager for dependencies. Packages are defined in the Xcode project.

## Architecture
The app follows MVVM architecture with SwiftUI and Swift Concurrency:

```
ios/
├── CareBridge/
│   ├── App/               # App entry point
│   ├── Views/             # SwiftUI views
│   ├── ViewModels/        # View models
│   ├── Models/            # Data models
│   ├── Services/          # Business logic & API
│   ├── Utilities/         # Helper functions
│   └── Resources/         # Assets & localizations
└── CareBridgeTests/       # Test suite
```

## Key Features
- SwiftUI-based user interface
- HealthKit integration for health data
- Offline-first architecture with SwiftData
- End-to-end encryption with CryptoKit
- Push notifications
- Voice assistant with SiriKit
- Biometric authentication
- Accessibility support (VoiceOver, Dynamic Type)

## Testing
```bash
# Run tests in Xcode
cmd + U

# Or via command line
xcodebuild test -scheme CareBridge -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Building for Release
1. Select the CareBridge scheme
2. Choose "Any iOS Device" as destination
3. Product → Archive
4. Follow the App Store Connect upload process

## Related Documentation
- [Architecture](../docs/architecture.md)
- [Design System](../docs/design-system.md)
- [Screen Specifications](../docs/screen-specifications.md)
- [Accessibility](../docs/accessibility.md)
