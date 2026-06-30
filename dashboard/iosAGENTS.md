# iOS App Agent Instructions

## Context
This is the iOS application component of the CareBridge platform.

## Technology Stack
- Language: Swift
- Framework: SwiftUI
- Minimum Deployment: iOS 17.0
- Architecture: MVVM with Swift Concurrency

## Responsibilities
- Native iOS user interface
- Health data integration (HealthKit)
- Push notifications
- Offline-first capabilities
- Biometric authentication
- Voice assistant integration

## Development Guidelines
- Use SwiftUI for all UI components
- Leverage Swift Concurrency (async/await, actors)
- Follow Apple's Human Interface Guidelines
- Implement proper accessibility features
- Use Swift Testing framework for tests
- Utilize CryptoKit for encryption
- Implement proper error handling

## Key Frameworks
- SwiftUI - User interface
- SwiftData - Local data persistence
- HealthKit - Health data integration
- CloudKit - Cloud synchronization
- CryptoKit - Encryption
- Speech - Voice recognition
- SiriKit - Siri integration
- UserNotifications - Push notifications

## Code Organization
- Use MVVM architecture
- Separate views, view models, and models
- Create reusable components
- Implement proper dependency injection

## Testing
- Use Swift Testing framework with `@Test` and `@Suite` macros
- Write unit tests for view models
- Test business logic thoroughly
- Consider UI tests for critical flows

## Related Documentation
- [Architecture](../docs/architecture.md)
- [Design System](../docs/design-system.md)
- [Accessibility](../docs/accessibility.md)
- [Security](../docs/security.md)
- [Encryption](../docs/encryption.md)
