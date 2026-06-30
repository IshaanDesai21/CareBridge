# Assets

## Overview
This directory contains project assets including images, icons, design files, and other media resources.

## Structure

```
assets/
├── icons/              # App icons and UI icons
├── images/             # Images and graphics
├── logos/              # Brand logos
├── design/             # Design files (Figma, Sketch, etc.)
├── fonts/              # Custom fonts
└── videos/             # Video resources
```

## Asset Guidelines

### Icons
- Format: SVG (preferred), PNG with @2x and @3x for iOS
- Size: Multiple sizes for different use cases
- Style: Consistent with design system

### Images
- Format: WebP (web), PNG/JPEG (iOS)
- Optimization: All images should be optimized
- Naming: Use descriptive, kebab-case names

### Logos
- Provide multiple variants (light/dark, different sizes)
- Include brand guidelines

### Design Files
- Keep source design files (Figma, Sketch, etc.)
- Export assets using consistent naming

## Usage

### iOS
```swift
Image("logo-primary")
Image(systemName: "heart.fill")
```

### Dashboard
```typescript
import logo from '@/assets/logos/logo-primary.svg';
```

## Contributing
When adding new assets:
1. Follow naming conventions
2. Optimize file sizes
3. Document any special requirements
4. Update this README if adding new categories
