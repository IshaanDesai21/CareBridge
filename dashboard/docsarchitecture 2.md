# Architecture

## Overview
CareBridge follows a modern, scalable architecture with clear separation of concerns across backend, web dashboard, and iOS app.

## High-Level Architecture

```
┌─────────────────┐
│   iOS App       │
│   (SwiftUI)     │
└────────┬────────┘
         │
         │ HTTPS/WebSocket
         │
┌────────▼────────┐
│  API Gateway    │
└────────┬────────┘
         │
┌────────▼────────────────────┐
│     Backend API             │
│  (Node.js + Express)        │
└────────┬────────────────────┘
         │
    ┌────┴─────┬──────────┐
    ▼          ▼          ▼
┌────────┐ ┌────────┐ ┌────────┐
│PostGres│ │ Redis  │ │  S3    │
│   DB   │ │ Cache  │ │Storage │
└────────┘ └────────┘ └────────┘
         │
    ┌────▼─────┐
    │   AI     │
    │ Service  │
    └──────────┘
```

## System Components

### 1. iOS App
- **Technology**: SwiftUI, Swift 5.9+
- **Architecture**: MVVM + Clean Architecture
- **Features**:
  - Offline-first with local persistence
  - Real-time updates via WebSocket
  - Voice recording and playback
  - Push notifications
  - Biometric authentication

### 2. Web Dashboard
- **Technology**: SvelteKit, TypeScript
- **Architecture**: Component-based
- **Features**:
  - Responsive design
  - Real-time data visualization
  - Organization management
  - Analytics and reporting

### 3. Backend API
- **Technology**: Node.js, Express, TypeScript
- **Architecture**: Layered architecture
- **Layers**:
  - Routes: HTTP endpoints
  - Controllers: Request handling
  - Services: Business logic
  - Repositories: Data access
  - Models: Data structures

### 4. Database
- **Primary**: PostgreSQL
- **Cache**: Redis
- **Storage**: S3-compatible object storage

### 5. AI Service
- **Technology**: OpenAI API integration
- **Features**:
  - Voice transcription
  - Natural language processing
  - Contextual memory
  - Wellness analysis

## Design Patterns

### Backend
- **Repository Pattern**: Data access abstraction
- **Service Layer**: Business logic encapsulation
- **Dependency Injection**: Loose coupling
- **Event-Driven**: Async operations

### iOS
- **MVVM**: View-ViewModel-Model separation
- **Repository Pattern**: Data source abstraction
- **Observer Pattern**: Reactive updates
- **Coordinator Pattern**: Navigation management

### Dashboard
- **Component-Based**: Reusable UI components
- **Store Pattern**: State management
- **Service Layer**: API communication

## Data Flow

### Authentication Flow
```
User → App → Backend → Verify Credentials → JWT Token → App Storage
```

### Voice Assistant Flow
```
User speaks → Record → Upload → Transcribe → AI Process → Response → TTS → Play
```

### Real-Time Updates Flow
```
Event → Backend → WebSocket → Connected Clients → UI Update
```

## Security Architecture

### Layers
1. **Transport**: HTTPS/TLS 1.3
2. **Authentication**: JWT tokens
3. **Authorization**: RBAC
4. **Data**: Encryption at rest and in transit
5. **API**: Rate limiting, input validation

### Security Zones
- **Public**: Unauthenticated endpoints
- **Authenticated**: User-specific data
- **Organization**: Multi-tenant isolation
- **Admin**: Privileged operations

## Scalability

### Horizontal Scaling
- Stateless API servers
- Load balancer distribution
- Database read replicas
- Redis clustering

### Vertical Scaling
- Resource optimization
- Query optimization
- Caching strategies
- Connection pooling

## Monitoring & Observability

### Metrics
- API response times
- Error rates
- Database performance
- Cache hit rates
- User activity

### Logging
- Structured JSON logs
- Centralized log aggregation
- Error tracking
- Audit trails

### Alerting
- Performance degradation
- Error spikes
- Security events
- System health

## Deployment Architecture

### Environments
- **Development**: Local development
- **Staging**: Pre-production testing
- **Production**: Live system

### Infrastructure
- **Hosting**: Cloud provider (AWS/GCP/Azure)
- **CDN**: Static asset delivery
- **CI/CD**: Automated deployment pipeline
- **Backup**: Automated backups and recovery

## Technology Decisions

See [decisions/](decisions/) for detailed Architecture Decision Records (ADRs).
