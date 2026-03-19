# Playola Radio iOS — Design System

## Color Palette

### Brand Colors
| Token | Hex | Usage |
|-------|-----|-------|
| `.playolaRed` | `#EF6962` | Primary actions, buttons, highlights |
| `.playolaGray` | `#868686` | Secondary text, icons |

### Semantic Colors
| Token | Hex | Usage |
|-------|-----|-------|
| `.success` | `#4CAF50` | Success states |
| `.warning` | `#FFC107` | Warnings |
| `.error` | `#FF5252` | Errors |
| `.info` | `#6EC6FF` | Informational |

### Surfaces
| Usage | Value |
|-------|-------|
| Page background | `Color.black` |
| Card/tile background | `Color(white: 0.15)` |
| Input field background | `Color(hex: "#333333")` |
| Elevated surface | `Color(hex: "#1A1A1A")` |
| Disabled button background | `Color(hex: "#444444")` |
| Placeholder image background | `Color(hex: "#666666")` |
| Placeholder icon color | `Color(hex: "#999999")` |

### Text Colors
| Usage | Value |
|-------|-------|
| Primary text | `.white` |
| Secondary text | `.gray` or `.playolaGray` |
| Disabled text | `.white.opacity(0.5)` |

---

## Typography

### Font Families

**Inter** — Body text, labels, buttons, descriptions. The workhorse font.
- Weights: 400 (Regular), 500 (Medium), 600 (SemiBold), 700 (Bold)

**SpaceGrotesk** — Display/headline text. Used for page titles and feature callouts in NewFeatureTile.
- Weights: 400 (Regular), 500 (Medium), 700 (Bold)

### Type Scale

| Use Case | Font | Size | Weight |
|----------|------|------|--------|
| Feature headline (tiles) | Inter | 32 | Bold (700) |
| Page title (custom rendered) | SpaceGrotesk | 24 | Bold (700) |
| Tile label | SpaceGrotesk | 16 | Medium (500) |
| Section header | Inter | 12 | SemiBold (600) |
| Row title | Inter | 14 | SemiBold (600) |
| Row subtitle | Inter | 12 | Regular (400) |
| Body text | Inter | 16 | Regular (400) |
| Button text | Inter | 12-16 | Medium (500) or SemiBold (600) |
| Small label | Inter | 10 | Regular (400) |

### Rule of Thumb
- **Inter** for anything the user reads or interacts with
- **SpaceGrotesk** for page titles and tile labels only

---

## Spacing

### Page-Level
| Edge | Value |
|------|-------|
| Horizontal padding | `16-24px` (typically 20-24px) |
| Top padding (below nav) | `12-20px` |
| Bottom padding | `24px` |

### Component Spacing
| Context | Value |
|---------|-------|
| Between sections | `20px` |
| Between rows | `0px` (tight) or `8px` (spacious) |
| Inside tiles | `20px` all sides |
| Inside rows | `.horizontal(12), .vertical(8)` |
| Stack spacing (compact) | `4-8px` |
| Stack spacing (standard) | `12-16px` |

---

## Corner Radii

| Context | Value |
|---------|-------|
| Badges, small chips | `4px` |
| Buttons (rectangular) | `4-6px` |
| Cards, tiles, inputs | `8px` |
| Pill buttons | `20px` |
| Circular elements | `.clipShape(Circle())` |

---

## Buttons

### Primary (call to action)
```swift
Text("BUTTON TEXT")
  .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
  .foregroundColor(.white)
  .padding(.horizontal, 12)
  .padding(.vertical, 6)
  .background(Color.playolaRed)
  .cornerRadius(4)
```

### Secondary (dismiss, cancel)
```swift
Text("DISMISS")
  .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
  .foregroundColor(.playolaGray)
  .padding(.horizontal, 12)
  .padding(.vertical, 6)
  .background(Color(hex: "#444444"))
  .cornerRadius(4)
```

### Tile Button (full-width inside tiles)
```swift
HStack {
  Spacer()
  Text(buttonText)
    .font(.custom(FontNames.Inter_500_Medium, size: 16))
    .foregroundColor(.white)
  Spacer()
}
.padding(.vertical, 16)
.background(Color(red: 0.8, green: 0.4, blue: 0.4))
.cornerRadius(6)
```

---

## Row Layout

### Standard Row
```swift
HStack(spacing: 12) {
  // Image (45x45 or 64x64)
  // VStack with title + subtitle
  Spacer()
  // Trailing action
}
.padding(.horizontal, 12)
.padding(.vertical, 8)
.background(Color(hex: "#333333"))
```

### Image Sizes
| Context | Size | Corner Radius |
|---------|------|---------------|
| Row thumbnail | `45x45` | `4px` |
| Large row image | `64x64` | `6px` |
| Placeholder | Same size, `#666666` fill, system icon in `#999999` |

---

## Navigation Bar

### Hidden (custom title in view)
```swift
.navigationBarTitleDisplayMode(.inline)
.toolbarBackground(.hidden, for: .navigationBar)
```

### Visible (standard dark)
```swift
.navigationBarTitleDisplayMode(.inline)
.toolbarBackground(.visible, for: .navigationBar)
.toolbarBackground(Color.black, for: .navigationBar)
.toolbarColorScheme(.dark, for: .navigationBar)
```

---

## Lists
```swift
List { ... }
  .listStyle(.plain)
  .scrollContentBackground(.hidden)
  .background(Color.black)
```

Row modifiers:
```swift
.listRowInsets(EdgeInsets())
.listRowSeparator(.hidden)
.listRowBackground(Color.clear)
```

---

## Search Bar
- Background: `Color(hex: "#333333")`, corner radius `8px`
- Leading: magnifying glass icon (16pt, `.playolaGray`)
- Text: Inter 400, 16pt, white
- Clear button: `xmark.circle.fill`, `.playolaGray`, visible when text present
- Container padding: `.horizontal(16), .vertical(12)` on `Color.black`

---

## Tiles (NewFeatureTile)
- Background: `Color(white: 0.15)`, corner radius `8px`
- Padding: `20px` all sides
- Header: icon + label (SpaceGrotesk 500, 16pt)
- Content: large text (Inter 700, 32pt)
- Description: body text (Inter 400, 14pt, `.gray`)
- Button: full-width, reddish background `Color(red: 0.8, green: 0.4, blue: 0.4)`, corner radius `6px`

---

## Animations
- Badge pulse: `easeInOut(duration: 1.0).repeatForever(autoreverses: true)`
- Shadow pulse: radius 2→8, opacity 0.3→0.8
- Transitions: `.opacity.combined(with: .scale)`

---

## Accessibility
- Minimum touch target: 44x44pt
- All interactive elements need accessibility labels
- Section headers should use `.accessibilityAddTraits(.isHeader)`
- Group related elements with `.accessibilityElement(children: .combine)`

---

## Remote Images
Use SDWebImageSwiftUI with placeholder pattern:
```swift
if let imageUrl = item.imageUrl {
  WebImage(url: imageUrl).resizable().aspectRatio(contentMode: .fill)
    .frame(width: 45, height: 45).clipped()
} else {
  RoundedRectangle(cornerRadius: 4)
    .fill(Color(hex: "#666666")).frame(width: 45, height: 45)
    .overlay(Image(systemName: "music.note").foregroundColor(Color(hex: "#999999")))
}
```
