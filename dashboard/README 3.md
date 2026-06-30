# CareBridge

## Overview
CareBridge is a comprehensive care coordination platform that connects patients, caregivers, and healthcare organizations through AI-powered assistance and real-time communication.

## Features
- 🤖 AI-powered voice assistant
- 📊 Real-time wellness tracking
- 👥 Multi-user collaboration
- 🔒 End-to-end encryption
- 📱 iOS mobile app
- 💻 Web dashboard
- 🌐 Offline-first architecture

## Quick Start

### Prerequisites
- Node.js 18+
- PostgreSQL 15+
- Xcode 15+ (for iOS)
- Swift 5.9+

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/CareBridge.git
cd CareBridge

# Run setup script
./scripts/setup.sh
```

## Project Structure

```
CareBridge/
├── backend/        # Node.js API server
├── dashboard/      # Web dashboard (SvelteKit)
├── ios/            # iOS app (SwiftUI)
├── shared/         # Shared schemas and types
├── docs/           # Comprehensive documentation
├── assets/         # Design assets and media
└── scripts/        # Build and deployment scripts
```

## Documentation

- [Architecture](docs/architecture.md)
- [Product Specification](docs/product-spec.md)
- [API Reference](docs/api-reference/)
- [Database Schema](docs/database.md)
- [Deployment Guide](docs/deployment.md)

## Development

### Backend
```bash
cd backend
npm install
npm run dev
```

### Dashboard
```bash
cd dashboard
npm install
npm run dev
```

### iOS
Open `ios/CareBridge.xcodeproj` in Xcode and build.

## Contributing
See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## Security
See [SECURITY.md](SECURITY.md) for security policies.

## License
See [LICENSE](LICENSE) for details.

## Support
For support, email support@carebridge.com or open an issue.
