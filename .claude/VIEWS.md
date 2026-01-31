# View Patterns

## Alerts

Use the custom `.playolaAlert` modifier instead of SwiftUI's `.alert(item:)`:

```swift
// Good
.playolaAlert($model.presentedAlert)

// Bad - don't use this
.alert(item: $model.presentedAlert) { $0.alert }
```

## Colors

Use colors from `Color+Hex.swift` and `Color+Palette.swift`:

```swift
// Primary colors
.playolaRed          // #EF6962 - primary action color
.playolaGray         // #868686 - secondary text

// Semantic colors (from Color+Palette.swift)
.success             // #4CAF50 - green
.warning             // #FFC107 - yellow/orange
.error               // #FF5252 - red
.info                // #6EC6FF - blue

// Common hex colors for backgrounds
Color(hex: "#333333")  // Row backgrounds
Color(hex: "#1A1A1A")  // Section backgrounds
Color(hex: "#444444")  // Disabled/secondary button backgrounds
Color(hex: "#666666")  // Placeholder image backgrounds
Color(hex: "#999999")  // Placeholder icon color
Color.black            // Main view backgrounds
```

## Fonts

Use `FontNames` constants from `FontNames.swift`:

```swift
FontNames.Inter_400_Regular   // Body text
FontNames.Inter_500_Medium    // Medium emphasis
FontNames.Inter_600_SemiBold  // Titles, buttons, section headers
FontNames.Inter_700_Bold      // Strong emphasis
```

Common font sizes:
- Section headers: `size: 12` with `Inter_600_SemiBold`
- Row titles: `size: 14` with `Inter_600_SemiBold`
- Row subtitles: `size: 12` with `Inter_400_Regular`
- Small labels: `size: 10` with `Inter_400_Regular`
- Body text: `size: 16` with `Inter_400_Regular`

## List Styling

Standard list setup for dark theme:

```swift
List {
  // content
}
.listStyle(.plain)
.scrollContentBackground(.hidden)
.background(Color.black)
```

Standard row modifiers:

```swift
.listRowInsets(EdgeInsets())
.listRowSeparator(.hidden)
.listRowBackground(Color.clear)
```

## Row Layout

Standard row structure:

```swift
HStack(spacing: 12) {
  // Image (45x45)
  // VStack with title/subtitle
  Spacer()
  // Action button or status
}
.padding(.horizontal, 12)
.padding(.vertical, 8)
.background(Color(hex: "#333333"))
```

## Navigation Bar

Standard dark navigation bar setup:

```swift
.navigationTitle(model.navigationTitle)
.navigationBarTitleDisplayMode(.inline)
.toolbarBackground(.visible, for: .navigationBar)
.toolbarBackground(Color.black, for: .navigationBar)
.toolbarColorScheme(.dark, for: .navigationBar)
```

## Images

Use `SDWebImageSwiftUI` for remote images:

```swift
import SDWebImageSwiftUI

if let imageUrl = item.imageUrl {
  WebImage(url: imageUrl)
    .resizable()
    .aspectRatio(contentMode: .fill)
    .frame(width: 45, height: 45)
    .clipped()
} else {
  // Placeholder
  RoundedRectangle(cornerRadius: 4)
    .fill(Color(hex: "#666666"))
    .frame(width: 45, height: 45)
    .overlay(
      Image(systemName: "music.note")
        .foregroundColor(Color(hex: "#999999"))
    )
}
```

## Buttons

Standard action button style:

```swift
Button(action: onAction) {
  Text("BUTTON TEXT")
    .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
    .foregroundColor(.white)
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(Color.playolaRed)
    .cornerRadius(4)
}
```

Secondary/dismiss button style:

```swift
Button(action: onDismiss) {
  Text("DISMISS")
    .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
    .foregroundColor(.playolaGray)
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(Color(hex: "#444444"))
    .cornerRadius(4)
}
```
