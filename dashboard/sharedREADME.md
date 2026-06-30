# Shared Resources

## Overview
This directory contains shared resources, utilities, and code used across multiple components of the CareBridge platform.

## Contents

### Models
Shared data models and schemas used by backend, dashboard, and iOS app.

### Types
TypeScript type definitions and Swift protocol definitions.

### Constants
Shared constants, configuration values, and enumerations.

### Utilities
Common utility functions used across platforms.

### Documentation
Shared documentation and specifications.

## Usage

### Backend
```python
from shared.models import User, CareTask
```

### Dashboard
```typescript
import { User, CareTask } from '@shared/models';
```

### iOS
```swift
import SharedModels
```

## Contributing
When adding shared resources:
1. Ensure they are truly platform-agnostic
2. Document all interfaces thoroughly
3. Write tests for utility functions
4. Update this README with new additions
