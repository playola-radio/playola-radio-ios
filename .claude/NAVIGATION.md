# Navigation

## Sheet Presentation

Sheets are presented via the `PlayolaSheet` enum and `MainContainerNavigationCoordinator`.

### Adding a new sheet type

1. Add a case to `PlayolaSheet` enum in `Views/Reusable Components/PlayolaSheet.swift`:
```swift
enum PlayolaSheet: Hashable, Identifiable, Equatable {
  case player(PlayerPageModel)
  case myNewSheet(MyNewSheetModel)  // Add your case
}
```

2. Handle the case in `MainContainer.swift`'s `.sheet()` or `.fullScreenCover()` modifier:
```swift
.sheet(
  item: Binding(
    get: {
      switch model.mainContainerNavigationCoordinator.presentedSheet {
      case .player, .feedbackSheet, .myNewSheet:  // Add to the list
        return model.mainContainerNavigationCoordinator.presentedSheet
      // ...
      }
    },
    // ...
  ),
  content: { item in
    switch item {
    case .myNewSheet(let myModel):  // Add case
      MyNewSheetView(model: myModel)
    // ...
    }
  }
)
```

### Presenting a sheet from a model

```swift
// In your model, inject the navigation coordinator
@ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
var mainContainerNavigationCoordinator

// Present the sheet
func shareButtonTapped() {
  let model = MyNewSheetModel(items: [...])
  mainContainerNavigationCoordinator.presentedSheet = .myNewSheet(model)
}

// Dismiss the sheet
func dismissButtonTapped() {
  mainContainerNavigationCoordinator.presentedSheet = nil
}
```

## Stack Navigation

Pages are pushed onto per-tab navigation stacks via `MainContainerNavigationCoordinator`.

### Pushing a page

```swift
// In your model
@ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
var mainContainerNavigationCoordinator

func editProfileButtonTapped() {
  let model = EditProfilePageModel()
  mainContainerNavigationCoordinator.push(.editProfilePage(model))
}
```

### Adding a new pushable page

1. Add a case to the `Path` enum in `Core/Navigation/MainContainerNavigationCoordinator.swift`:
```swift
enum Path: Hashable, Equatable {
  case editProfilePage(EditProfilePageModel)
  case myNewPage(MyNewPageModel)  // Add your case
  // ...

  @MainActor @ViewBuilder
  var destinationView: some View {
    switch self {
    case .myNewPage(let model):  // Add case
      MyNewPageView(model: model)
    // ...
    }
  }
}
```

### Navigation methods

```swift
mainContainerNavigationCoordinator.push(.somePage(model))  // Push onto current tab's stack
mainContainerNavigationCoordinator.pop()                   // Pop one page
mainContainerNavigationCoordinator.popToRoot()             // Pop to tab root
mainContainerNavigationCoordinator.replace(with: .page)    // Replace stack with single page
```

## Changing Tabs Programmatically

```swift
@ObservationIgnored @Shared(.activeTab) var activeTab

func goToRewardsButtonTapped() {
  $activeTab.withLock { $0 = .rewards }
}
```

Available tabs: `.home`, `.stationsList`, `.rewards`, `.profile`, `.broadcast`, `.library`, `.listeners`, `.settings`
