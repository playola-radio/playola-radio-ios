# Page Creation Workflow

**Key principle:** The Model is the complete, portable representation of the page. ALL text, behavior, and state live in the Model. The View is ONLY layout and styling. If porting to another platform, only the View should need rebuilding.

When creating a new page:

## 1. Create the Model

Create `Views/Pages/MyNewPage/MyNewPageModel.swift`:

```swift
import Dependencies
import IdentifiedCollections
import Sharing

@MainActor
@Observable
class MyNewPageModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.api) var api

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator

  // MARK: - Properties

  let navigationTitle = "My New Page"
  var items: IdentifiedArrayOf<Item> = []
  var isLoading = false
  var presentedAlert: PlayolaAlert?

  // MARK: - View Helpers (all display text lives here)

  var emptyStateMessage: String {
    "No items yet. Add some to get started!"
  }

  var itemCountLabel: String {
    "\(items.count) item\(items.count == 1 ? "" : "s")"
  }

  var showEmptyState: Bool {
    !isLoading && items.isEmpty
  }

  // MARK: - User Actions

  func viewAppeared() async {
    await loadItems()
  }

  // MARK: - Private Helpers

  private func loadItems() async {
    guard let token = auth.playolaToken else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      items = try await IdentifiedArray(uniqueElements: api.getItems(token))
    } catch {
      presentedAlert = .errorLoadingItems
    }
  }
}
```

## 2. Create the View

Create `Views/Pages/MyNewPage/MyNewPageView.swift`:

```swift
import SwiftUI

struct MyNewPageView: View {
  @Bindable var model: MyNewPageModel

  var body: some View {
    Group {
      if model.showEmptyState {
        Text(model.emptyStateMessage)  // Text from model, not hardcoded
          .foregroundColor(.playolaGray)
      } else {
        List {
          Section(header: Text(model.itemCountLabel)) {  // Text from model
            ForEach(model.items) { item in
              Text(item.name)
            }
          }
        }
      }
    }
    .navigationTitle(model.navigationTitle)  // Title from model
    .playolaAlert($model.presentedAlert)
    .onAppear { Task { await model.viewAppeared() } }
  }
}
```

## 3. Create Tests

Create `Views/Pages/MyNewPage/MyNewPageTests.swift`:

```swift
import XCTest
@testable import PlayolaRadio

@MainActor
final class MyNewPageTests: XCTestCase {
  func testViewAppearedLoadsItems() async {
    @Shared(.auth) var auth = Auth(playolaToken: "test-token")

    let model = withDependencies {
      $0.api.getItems = { _ in [Item.mock] }
    } operation: {
      MyNewPageModel()
    }

    await model.viewAppeared()

    XCTAssertEqual(model.items.count, 1)
  }
}
```

## 4. Wire up navigation

If the page is pushable, add to `Path` enum (see `.claude/NAVIGATION.md` "Stack Navigation" section).
If the page is a sheet, add to `PlayolaSheet` enum (see `.claude/NAVIGATION.md` "Sheet Presentation" section).
