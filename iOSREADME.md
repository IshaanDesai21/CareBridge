# CareBridge iOS App

Patient-facing iOS application for the CareBridge healthcare coordination platform.

## Features

- 🔐 User Authentication
- ❤️ Daily Wellness Check-ins
- 💊 Medication Tracking
- 📅 Appointment Management
- 📔 Personal Journal
- 👤 Patient Profile Management

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Setup

### 1. Install Xcode

Download and install Xcode from the Mac App Store.

### 2. Open the Project

```bash
cd iOS
open CareBridge.xcodeproj
```

### 3. Configure API Endpoint

The app is configured to connect to `http://localhost:3000/api` by default. Make sure your backend is running before testing the app.

### 4. Build and Run

1. Select a simulator or device
2. Press `Cmd + R` to build and run
3. The app will launch in the simulator

## Project Structure

```
CareBridge/
├── CareBridgeApp.swift          # App entry point
├── Managers/
│   └── AuthenticationManager.swift
├── Models/
│   └── Models.swift             # Data models
├── Services/
│   └── APIService.swift         # API client
└── Views/
    ├── Authentication/
    │   ├── LoginView.swift
    │   └── RegisterView.swift
    ├── Home/
    │   └── HomeView.swift
    ├── Wellness/
    │   ├── WellnessView.swift
    │   └── WellnessCheckinView.swift
    ├── Medications/
    │   └── MedicationsView.swift
    ├── Journal/
    │   └── JournalView.swift
    ├── Profile/
    │   └── ProfileView.swift
    ├── Components/
    │   └── EmptyStateView.swift
    └── MainTabView.swift
```

## Testing

### Test Account

You can register a new account in the app, or use these credentials if seeded:

- Email: `patient@example.com`
- Password: `password123`

### API Connection

If you're running on a physical device, update the `baseURL` in `APIService.swift` to use your Mac's local IP address instead of `localhost`.

## Accessibility

CareBridge prioritizes accessibility with:

- Dynamic Type support
- VoiceOver compatibility
- High contrast UI
- Large tap targets
- Simple navigation

## Architecture

The app follows MVVM architecture with:

- **Views**: SwiftUI views for UI
- **Managers**: State management (AuthenticationManager)
- **Services**: API communication (APIService)
- **Models**: Data structures

## Development

### Adding New Features

1. Create model in `Models/Models.swift`
2. Add API methods in `Services/APIService.swift`
3. Create view in appropriate `Views/` subfolder
4. Update navigation in `MainTabView.swift` if needed

### Code Style

- Use SwiftUI best practices
- Follow Apple's Human Interface Guidelines
- Ensure accessibility compliance
- Use async/await for asynchronous operations
