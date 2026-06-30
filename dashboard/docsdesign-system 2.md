# Design System

## Overview

CareBridge's design system ensures consistency, accessibility, and quality across all platforms.

## Brand Identity

### Mission
Empowering compassionate care through intelligent technology.

### Values
- **Compassion**: Warm, empathetic, supportive
- **Clarity**: Simple, understandable, transparent
- **Trust**: Reliable, secure, professional
- **Innovation**: Modern, intelligent, adaptive

## Color System

### Primary Colors

#### Care Blue
- **Primary**: `#0066CC` (rgb(0, 102, 204))
- **Light**: `#3399FF`
- **Dark**: `#004C99`
- **Usage**: Primary actions, key UI elements

#### Wellness Green
- **Primary**: `#00B894` (rgb(0, 184, 148))
- **Light**: `#55EFC4`
- **Dark**: `#00966B`
- **Usage**: Success states, positive indicators

### Semantic Colors

#### Status Colors
```swift
// iOS
struct StatusColors {
    static let stable = Color(hex: "#00B894") // Green
    static let attention = Color(hex: "#FDCB6E") // Yellow
    static let critical = Color(hex: "#D63031") // Red
    static let info = Color(hex: "#0984E3") // Blue
}
```

```css
/* Web */
:root {
    --status-stable: #00B894;
    --status-attention: #FDCB6E;
    --status-critical: #D63031;
    --status-info: #0984E3;
}
```

### Neutral Colors

```
Gray Scale:
- Gray 900: #1A1A1A (Headings)
- Gray 800: #333333 (Body text)
- Gray 600: #666666 (Secondary text)
- Gray 400: #999999 (Disabled)
- Gray 200: #E0E0E0 (Borders)
- Gray 100: #F5F5F5 (Backgrounds)
- Gray 50:  #FAFAFA (Surfaces)
```

### Accessibility

All color combinations meet WCAG AA standards:
- Text on background: 4.5:1 minimum
- Large text: 3:1 minimum
- Interactive elements: 3:1 minimum

## Typography

### Font Family

#### iOS
```swift
// System font with custom weights
Font.system(.title, design: .default, weight: .bold)
```

- **Primary**: SF Pro (System Default)
- **Monospace**: SF Mono (for codes/data)

#### Web
```css
font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, 
             "Helvetica Neue", Arial, sans-serif;
```

### Type Scale

#### iOS
```swift
// Dynamic Type support
.font(.largeTitle)  // 34pt (default)
.font(.title)       // 28pt
.font(.title2)      // 22pt
.font(.title3)      // 20pt
.font(.headline)    // 17pt, semibold
.font(.body)        // 17pt
.font(.callout)     // 16pt
.font(.subheadline) // 15pt
.font(.footnote)    // 13pt
.font(.caption)     // 12pt
.font(.caption2)    // 11pt
```

#### Web
```css
/* Responsive type scale */
--font-size-h1: clamp(2rem, 5vw, 3rem);
--font-size-h2: clamp(1.5rem, 4vw, 2.25rem);
--font-size-h3: clamp(1.25rem, 3vw, 1.75rem);
--font-size-body: 1rem;
--font-size-small: 0.875rem;
--font-size-caption: 0.75rem;
```

### Font Weights

```
Regular: 400
Medium: 500
Semibold: 600
Bold: 700
```

### Line Height

```
Tight: 1.2 (headings)
Normal: 1.5 (body text)
Relaxed: 1.75 (long-form content)
```

## Spacing

### Scale
```
0:   0px
1:   4px
2:   8px
3:   12px
4:   16px
5:   20px
6:   24px
8:   32px
10:  40px
12:  48px
16:  64px
20:  80px
```

### Usage

#### iOS
```swift
.padding(.horizontal, 16) // Standard screen padding
.padding(.vertical, 8)    // Between related items
.padding(.vertical, 24)   // Between sections
```

#### Web
```css
.container {
    padding: var(--space-4); /* 16px */
}
```

## Layout

### Grid System

#### Web
```css
.grid {
    display: grid;
    grid-template-columns: repeat(12, 1fr);
    gap: var(--space-4);
}
```

#### iOS
```swift
LazyVGrid(columns: [
    GridItem(.adaptive(minimum: 160))
], spacing: 16) {
    // Grid items
}
```

### Breakpoints

#### Web
```css
/* Mobile first approach */
--breakpoint-sm: 640px;   /* Small tablets */
--breakpoint-md: 768px;   /* Tablets */
--breakpoint-lg: 1024px;  /* Desktops */
--breakpoint-xl: 1280px;  /* Large desktops */
```

### Safe Areas (iOS)

```swift
// Respect safe areas
.padding(.horizontal, 20)
.safeAreaInset(edge: .bottom) {
    // Floating action button
}
```

## Components

### Buttons

#### Primary Button

**iOS:**
```swift
Button("Record Update") {
    // Action
}
.buttonStyle(.borderedProminent)
.tint(.blue)
.controlSize(.large)
```

**Web:**
```html
<button class="btn btn-primary">
    Record Update
</button>
```

```css
.btn-primary {
    background: var(--color-primary);
    color: white;
    padding: 12px 24px;
    border-radius: 8px;
    font-weight: 600;
    border: none;
    cursor: pointer;
    transition: all 0.2s;
}

.btn-primary:hover {
    background: var(--color-primary-dark);
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(0, 102, 204, 0.3);
}
```

#### Secondary Button

```css
.btn-secondary {
    background: transparent;
    color: var(--color-primary);
    border: 2px solid var(--color-primary);
}
```

### Cards

**iOS:**
```swift
VStack(alignment: .leading, spacing: 12) {
    Text("Card Title")
        .font(.headline)
    Text("Card content")
        .font(.body)
        .foregroundStyle(.secondary)
}
.padding()
.background(Color(.systemBackground))
.cornerRadius(12)
.shadow(color: .black.opacity(0.1), radius: 8, y: 2)
```

**Web:**
```css
.card {
    background: white;
    border-radius: 12px;
    padding: 24px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    transition: box-shadow 0.2s;
}

.card:hover {
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
}
```

### Form Inputs

**iOS:**
```swift
TextField("Enter patient name", text: $name)
    .textFieldStyle(.roundedBorder)
    .textContentType(.name)
    .autocorrectionDisabled()
```

**Web:**
```html
<div class="form-group">
    <label for="patientName">Patient Name</label>
    <input 
        type="text" 
        id="patientName" 
        class="form-input"
        placeholder="Enter patient name"
    />
</div>
```

```css
.form-input {
    width: 100%;
    padding: 12px 16px;
    border: 1px solid var(--gray-300);
    border-radius: 8px;
    font-size: 16px;
    transition: border-color 0.2s;
}

.form-input:focus {
    outline: none;
    border-color: var(--color-primary);
    box-shadow: 0 0 0 3px rgba(0, 102, 204, 0.1);
}
```

### Navigation

**iOS:**
```swift
NavigationStack {
    List {
        // Content
    }
    .navigationTitle("Patients")
    .navigationBarTitleDisplayMode(.large)
}
```

**Web:**
```html
<nav class="navbar">
    <div class="navbar-brand">CareBridge</div>
    <div class="navbar-links">
        <a href="/patients">Patients</a>
        <a href="/records">Records</a>
        <a href="/insights">Insights</a>
    </div>
</nav>
```

## Icons

### Icon Library

#### iOS
```swift
// SF Symbols
Image(systemName: "heart.fill")
Image(systemName: "person.2.fill")
Image(systemName: "chart.line.uptrend.xyaxis")
Image(systemName: "mic.fill")
```

#### Web
- **Primary**: Lucide Icons
- **Fallback**: Heroicons

```html
<svg class="icon" stroke="currentColor">
    <use href="/icons.svg#heart"/>
</svg>
```

### Icon Sizes

```
Small:  16px
Medium: 24px
Large:  32px
XLarge: 48px
```

## Animations

### Transitions

**iOS:**
```swift
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
```

**Web:**
```css
transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
```

### Loading States

**iOS:**
```swift
ProgressView()
    .progressViewStyle(.circular)
```

**Web:**
```html
<div class="spinner"></div>
```

### Micro-interactions

- Button press: Scale down 98%
- Hover: Lift 2px with shadow
- Focus: Ring glow
- Success: Checkmark animation

## Dark Mode

### iOS
```swift
@Environment(\.colorScheme) var colorScheme

var backgroundColor: Color {
    colorScheme == .dark ? Color(.systemBackground) : .white
}
```

### Web
```css
@media (prefers-color-scheme: dark) {
    :root {
        --bg-primary: #1A1A1A;
        --text-primary: #FFFFFF;
        --border-color: #333333;
    }
}
```

## Illustrations

### Style
- Flat design
- Friendly, approachable
- Simple shapes
- Brand colors
- Diverse representation

### Usage
- Empty states
- Onboarding
- Success/error states
- Feature showcases

## Voice & Tone

### Writing Guidelines

#### General
- Clear and concise
- Warm and supportive
- Professional but friendly
- Person-first language
- Avoid medical jargon

#### Examples

**❌ Don't:**
"Subject exhibits signs of cognitive decline"

**✅ Do:**
"Your mom seemed a bit more confused today"

**❌ Don't:**
"Authentication failed. Error code 401."

**✅ Do:**
"We couldn't sign you in. Please check your password and try again."

## Accessibility

- All components WCAG AA compliant
- Support for Dynamic Type
- VoiceOver optimization
- Keyboard navigation
- High contrast mode

## Resources

### Design Files
- Figma: `assets/design/carebridge-system.fig`
- Icons: `assets/icons/`
- Illustrations: `assets/illustrations/`

### Code
- iOS Components: `ios/CareBridge/DesignSystem/`
- Web Components: `dashboard/src/components/design-system/`

### Documentation
- Storybook: `http://localhost:6006`
- Style guide: `https://design.carebridge.com`
