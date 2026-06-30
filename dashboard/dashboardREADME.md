# CareBridge Dashboard

## Overview
Web dashboard for the CareBridge platform, providing a comprehensive interface for caregivers, patients, and healthcare providers.

## Setup

### Prerequisites
- Node.js 18+
- npm or yarn

### Installation
```bash
# Install dependencies
npm install

# Set up environment variables
cp .env.example .env.local
# Edit .env.local with your configuration

# Start development server
npm run dev
```

## Building for Production
```bash
npm run build
npm run start
```

## Testing
```bash
# Run unit tests
npm test

# Run e2e tests
npm run test:e2e
```

## Project Structure
```
dashboard/
├── src/
│   ├── components/   # React components
│   ├── pages/        # Next.js pages
│   ├── hooks/        # Custom hooks
│   ├── services/     # API services
│   ├── store/        # State management
│   └── utils/        # Utility functions
├── public/           # Static assets
└── tests/            # Test files
```

## Tech Stack
- Next.js 14
- React 18
- TypeScript
- Tailwind CSS
- React Query

## Related Documentation
- [Design System](../docs/design-system.md)
- [API Documentation](../docs/api.md)
