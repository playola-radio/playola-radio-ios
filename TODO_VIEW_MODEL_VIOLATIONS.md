# View/Model Pattern Violations TODO

Views that have hardcoded text, logic, or formatting that should be moved to Models.

> **Opportunistic Refactoring**: Whenever you touch one of these files for any reason, refactor it to fix the violations at that time. Don't make a separate task - just fix it while you're there.

## High Priority (7-8 violations each)

### ContactPageView
- [ ] "Your Profile" - should be model.navigationTitle
- [ ] "Switch to Listening Mode" - should be in model
- [ ] "Switch to Broadcasting Mode" - should be in model
- [ ] "Liked Songs" - should be in model
- [ ] "Notifications" - should be in model
- [ ] "Contact Us" - should be in model
- [ ] "Ask An Artist A Question" - should be in model
- [ ] "Log out" - should be in model

### BroadcastPageView
- [ ] "READY TO PLACE" - should be in model
- [ ] "LIVE NOW" - should be in model
- [ ] Notification placeholder text - should be model property
- [ ] "Send Notification" - should be in model
- [ ] "Cancel" - should be in model

### BroadcastersListenerQuestionPageView
- [ ] "No Questions Yet" - should be in model
- [ ] "When listeners send you questions..." - should be in model
- [ ] Formatting logic (transcription, listenerName, timeAgo, durationString) - should be model methods
- [ ] "Show less" / "Show more" - should be in model
- [ ] "Answered" - should be in model

## Medium Priority (5-6 violations each)

### RecordPageView
- [ ] "Your recording will appear here" - should be in model
- [ ] "Recording" - should be in model
- [ ] "Tap to Record", "Tap to Stop", "Try Again" - should be model properties
- [ ] "Discard", "Use Recording" - should be in model
- [ ] formatTime() function - move to model

### EditProfilePageView
- [ ] "First Name" - should be in model
- [ ] "Last Name" - should be in model
- [ ] "Email" - should be in model
- [ ] Email explanation text - should be in model
- [ ] "Save Profile" - should be in model
- [ ] "Edit Profile" - should use model.navigationTitle

### NotificationsSettingsPageView
- [ ] "No stations available" - should be in model
- [ ] "No stations are currently available..." - should be in model
- [ ] "All Notifications" - should be in model
- [ ] "Enable or disable all station notifications" - should be in model
- [ ] "Stations" section header - should be in model

### SongSearchPageView
- [ ] "Search for songs to add to your schedule" - should be in model
- [ ] "No songs found" - should be in model
- [ ] "LIBRARY" section header - should use model property
- [ ] "Cancel" - should be in model
- [ ] "SELECT" - should be in model

## Lower Priority (3-4 violations each)

### SignInPageView
- [ ] "Welcome to Playola" - should be in model
- [ ] "Sign in to access your personalized radio stations" - should be in model
- [ ] Footer text about Terms and Privacy Policy - should be in model
- [ ] "Sign in with Google" - should be in model

### ConversationListPageView
- [ ] "No conversations" - should be in model
- [ ] formatTime() function - move to model
- [ ] "Unknown User" fallback - should be in model

### SupportPageView
- [ ] "Yesterday" - should be in model
- [ ] formatTime() function - move to model

### ListenerQuestionDetailPageView
- [ ] Waveform placeholder text - should be model property
- [ ] "Recording" - should be in model
- [ ] "Discard" and action button labels - should be in model

### AskQuestionPageView
- [ ] Instruction text - should be model.instructionsText
- [ ] "Send Question" - should be in model

### RewardsPageView
- [ ] "Listener Rewards" - should use model.navigationTitle
- [ ] "Your rewards" - should be in model
- [ ] "Earn rewards..." description - should be in model

### PlayerPage
- [ ] "NOW PLAYING" - should be in model
- [ ] "ON AIR" - should be in model
- [ ] "LIVE" - should be in model
- [ ] "Ask the Artist" - should be in model

---

## Pattern to Follow

**In Model:**
```swift
// MARK: - Properties
let navigationTitle = "Page Title"
let emptyStateMessage = "No items found"
let submitButtonText = "Submit"

var formattedDuration: String {
  // formatting logic here
}
```

**In View:**
```swift
Text(model.navigationTitle)      // Good
Text(model.emptyStateMessage)    // Good
Text(model.formattedDuration)    // Good

Text("Page Title")               // Bad - hardcoded
Text("No items found")           // Bad - hardcoded
```
