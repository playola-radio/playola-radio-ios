# Audio App Intents Schema — SDK API Notes (Research Spike, Task 1)

**Status: CRITICAL FINDING — the `.audio` schema domain described in the task does NOT exist in the installed SDK.**

This Xcode/SDK predates the WWDC 2026 `.audio` App Intents domain. The schema-based App
Intents domains that DO ship here are the iOS 18.x "Apple Intelligence" domains (Books,
Mail, Photos, Browser, etc.). There is **no** `playAudio` intent schema, **no**
`liveRadioStation` / `algorithmicRadioStation` entity schema, and **no** Music/Audio/Radio
domain marker protocol anywhere in the `AppIntents` module interface.

## Environment

- `xcode-select -p` → `/Applications/Xcode-26.5.0.app/Contents/Developer`
- `xcodebuild -version` → **Xcode 26.5, Build 17F42**
- iPhoneOS SDK: `/Applications/Xcode-26.5.0.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk` (`CanonicalName: iphoneos26.5`, `Version: 26.5`)
- iPhoneSimulator SDK: `…/iPhoneSimulator26.5.sdk`
- Other installed Xcodes: `Xcode-26.3.0`, `Xcode-26.4.1`, `Xcode-26.5.0` (26.5 is the newest — none newer to probe).

### Files read (source of truth)

- **Device interface:**
  `/Applications/Xcode-26.5.0.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk/System/Library/Frameworks/AppIntents.framework/Modules/AppIntents.swiftmodule/arm64e-apple-ios.swiftinterface`
  (11,752 lines; built Apr 18 2026 per file mtime)
- **Simulator interface (cross-checked, identical domain set):**
  `…/iPhoneSimulator26.5.sdk/System/Library/Frameworks/AppIntents.framework/Modules/AppIntents.swiftmodule/x86_64-apple-ios-simulator.swiftinterface`

There is **no** separate `MediaIntents` or `AssistantIntents` framework in this SDK. The
only framework dirs matching intent/assistant/media are: `AppIntents.framework`,
`Intents.framework` (legacy SiriKit), `IntentsUI.framework`, and the private
`_AppIntents_SwiftUI` / `_AppIntents_UIKit` glue frameworks. All schema machinery lives
inside `AppIntents`.

---

## 1. Macro name + imports

**SOURCE:** device `.swiftinterface`, lines 83, 669, 1482, 2300, 10292.

The current schema-conformance macros are `@AppIntent(schema:)`, `@AppEntity(schema:)`,
`@AppEnum(schema:)`. The older `@AssistantIntent(schema:)` / `@AssistantEntity(schema:)`
spellings still exist but are **deprecated, renamed to the `@App*` forms**.

Verbatim:

```swift
// line 2300 — current entity macro
@attached(memberAttribute) @attached(extension, conformances: AppIntents.AppEntity, AppIntents.AssistantSchemaEntity, AppIntents.FileEntity, AppIntents.UniqueAppEntity, AppIntents.URLRepresentableEntity, names: named(__assistantSchemaEntity)) public macro AppEntity<T>(schema: T) = #externalMacro(module: "AppIntentsMacros", type: "AppEntityMacro") where T : AppIntents.AssistantSchemas.Entity

// line 10292 — current intent macro
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
@attached(memberAttribute) @attached(extension, conformances: AppIntents.AppIntent, AppIntents.AssistantSchemaIntent, AppIntents.ShowInAppSearchResultsIntent, AppIntents.OpenIntent, AppIntents.DeleteIntent, AppIntents.AudioPlaybackIntent, AppIntents.AudioRecordingIntent, AppIntents.LiveActivityIntent, AppIntents.URLRepresentableIntent, names: named(__assistantSchemaIntent)) public macro AppIntent<T>(schema: T) = #externalMacro(module: "AppIntentsMacros", type: "AppIntentMacro") where T : AppIntents.AssistantSchemas.Intent

// line 1482 — enum macro
@attached(extension, conformances: AppIntents.AppEnum, AppIntents.AssistantSchemaEnum, names: named(__assistantSchemaEnum)) public macro AppEnum<T>(schema: T) = #externalMacro(module: "AppIntentsMacros", type: "AppEnumMacro") where T : AppIntents.AssistantSchemas.Enum

// line 83 — DEPRECATED entity macro (renamed to AppEntity)
@available(*, deprecated, renamed: "AppEntity")
@attached(...) public macro AssistantEntity<T>(schema: T) = #externalMacro(module: "AppIntentsMacros", type: "AssistantEntityMacros") where T : AppIntents.AssistantSchemas.Entity
```

**Import:** a single `import AppIntents`. No `import MediaIntents` / `import
AssistantIntents` — those modules do not exist in this SDK.

The `schema:` argument is a value like `.books.audiobook` or `.books.playAudiobook`,
selected from the `AssistantSchemas.<Domain>Intent` / `<Domain>Entity` marker-protocol
extensions (see §6). The actual required-property enforcement is done by the
`AppIntentsMacros` compiler plugin (`AppEntityMacro` / `AppIntentMacro`), **not** declared
in the text interface — so the per-schema required parameters are not literally quotable
from the `.swiftinterface`; the macro emits diagnostics at build time if a conforming type
is missing a required property.

---

## 2. `playAudio` intent schema

**NOT PRESENT IN SDK.** There is no `playAudio` intent and no Audio/Music intent domain.

Searches over the full device interface returned zero hits for `playAudio` (non-audiobook),
`liveRadio`, `algorithmicRadio`, `RadioStation`, `MusicIntent`, and zero hits total for the
regex `Music|Radio|Station`.

The closest existing analog (for downstream reference only) is in the **Books** domain:

```swift
// line 7008 — Books domain "play audiobook" intent schema (string name "PlayAudiobookIntent")
@_alwaysEmitIntoClient public var playAudiobook: some AppIntents.AssistantSchemas.Intent {
    get {
        if #available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
            return AssistantSchema.IntentSchema("PlayAudiobookIntent")
        } else { fatalError("Do not reference schema types directly") }
    }
}
```

Its required parameter shape (an entity parameter, `perform()` return type, etc.) is NOT
expressed in the interface — it is enforced by the macro plugin. So we cannot quote
`playAudio`'s required `mediaItems` / `MediaSearch` parameters from this SDK because the
schema itself is absent.

Also present but unrelated (these are the legacy *system* media-control protocols, not the
schema): `AudioPlaybackIntent` (line 1204) and `AudioRecordingIntent` (line 971), both
`: AppIntents.SystemIntent`. These power play/pause/system audio control, not a
"play this radio station by name" search intent.

---

## 3. `liveRadioStation` / `algorithmicRadioStation` entity schemas

**NOT PRESENT IN SDK.** No `liveRadioStation`, `algorithmicRadioStation`, or any radio/music
entity schema exists. Zero hits.

For shape reference, the analogous **Books** entity schemas look like this (string names
only; required props are macro-enforced, not in the interface):

```swift
// line 7116 — "audiobook" entity schema (string name "AudiobookEntity")
@_alwaysEmitIntoClient public var audiobook: some AppIntents.AssistantSchemas.Entity {
    get {
        if #available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
            return AssistantSchema.EntitySchema("AudiobookEntity")
        } else { fatalError("Do not reference schema types directly") }
    }
}
```

The conforming entity must satisfy `AssistantSchemaEntity : AssistantEntity : AppEntity`
(see §7), but the specific required fields (id / title / etc.) for a radio-station schema
cannot be quoted because the schema does not exist here.

---

## 4. The query type

**SOURCE:** device `.swiftinterface`, lines 624–631.

`IntentValueQuery` **does exist** in this SDK and is the protocol an app implements to
resolve a value parameter. Verbatim:

```swift
@available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *)
@_alwaysEmitConformanceMetadata public protocol IntentValueQuery : AppIntents.PersistentlyIdentifiable, AppIntents._SupportsAppDependencies, Swift.Sendable {
  associatedtype Input : AppIntents._IntentValue
  associatedtype ResultValue = Self.Result.Result.ValueType where Self.ResultValue == Self.Result.Result
  associatedtype Result : AppIntents.ResultsCollection = [Self.ResultValue]
  init()
  func values(for input: Self.Input) async throws -> Self.Result
}
```

Key points:
- The app implements `func values(for input: Input) async throws -> Result`.
- `Input` is some `_IntentValue` (the search term / criteria); `Result` is a
  `ResultsCollection`, defaulting to `[ResultValue]`.
- **`@available` floor is iOS 26.0** (see §5) — newer than `EntityQuery` (iOS 16). This is
  the query type the WWDC-2026 media docs reference, and it is present even though the audio
  schema that would use it is not.

Other query protocols present: `EntityQuery` (iOS 16, line 409), `EntityStringQuery`,
`EntityPropertyQuery`, `EnumerableEntityQuery`, `UniqueAppEntityQuery`.

---

## 5. `@available` floor

**SOURCE:** device `.swiftinterface`, per-symbol annotations.

| Symbol | `@available` (verbatim) | Line |
|---|---|---|
| `.audio` domain / `playAudio` / `liveRadioStation` / `algorithmicRadioStation` | **N/A — not in SDK** | — |
| `AssistantSchemas` enum + `Model`/`Intent`/`Entity`/`Enum` markers + `IntentSchema`/`EntitySchema` structs | `@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)` | 41–63 |
| Each existing domain marker (`BooksIntent`, `MailIntent`, …) declaration | `@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)` | e.g. 6976, 6977 |
| The concrete schema *values* inside each domain (e.g. `playAudiobook`, `audiobook`) gate at runtime with | `if #available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)` | e.g. 7010, 7118 |
| `@AppIntent(schema:)` / `@AppEntity(schema:)` macros | `@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)` | 10291, (entity macro un-annotated/inherits) |
| `AssistantEntity` / `AssistantSchemaEntity` protocols | `@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)` | 1961, 66 |
| **`IntentValueQuery`** | **`@available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *)`** | 624 |

Net: the *existing* schema machinery is effectively an **iOS 18.0** floor at runtime
(markers say 16.0 but every concrete schema value `#available`-gates to 18.0). The
`IntentValueQuery` resolution protocol is **iOS 26.0**. The app's deployment target is iOS
18.0/18.1, so `IntentValueQuery` would require `@available(iOS 26, *)` gating regardless.

**The real `.audio` schema floor cannot be measured here because the schema is absent.** Per
Apple's public docs the `.audio` domain shipped in the iOS 26.x line; this SDK is
iphoneos26.5 yet still lacks it, so the domain is almost certainly **newer than 26.5**
(i.e. a later 26.x point release / a 26.6+ or WWDC-2026 seed not installed on this machine).

---

## 6. One entity type vs two (heterogeneous results)

**Cannot be answered from this SDK** because neither `playAudio` nor the two radio entity
schemas exist. Documenting the structural evidence so the downstream decision is informed:

- Domains expose multiple entity schemas under one marker protocol. Example — the Books
  domain marker `BooksEntity` exposes `book`, `audiobook`, and `settings` entity schemas
  (lines 7100–7140). So a single *domain* covering both `liveRadioStation` and
  `algorithmicRadioStation` is plausible by analogy.
- **However**, schema conformance binds **one concrete Swift type → one schema**
  (`@AppEntity(schema: .books.audiobook)`). The `playAudio` intent's audio parameter is
  resolved by an `IntentValueQuery` whose `Result` is a `ResultsCollection` (default
  `[ResultValue]`) of a *single* `ResultValue` type. Whether that `ResultValue` can be a
  protocol/`AnyEntity`-style heterogeneous box (returning both station kinds) vs. one
  concrete entity is **exactly the detail that lives in the `.audio` schema definition we
  can't see**. **This must be re-verified against an Xcode that actually contains the
  `.audio` domain before committing to a one-intent-two-entities design.** (docs-level
  expectation: a single `playAudio` intent with a `MediaSearch`-style query returning mixed
  media items, but UNVERIFIED in SDK.)

---

## 7. Anything surprising that would bite an implementer

1. **The `.audio` domain is simply not in Xcode 26.5.** This is the headline. Any code
   written today against `@AppIntent(schema: .audio.playAudio)` /
   `@AppEntity(schema: .audio.liveRadioStation)` will **fail to compile** on this machine —
   the schema accessors don't exist. Implementation is BLOCKED on a newer Xcode, OR the plan
   must fall back to a **custom (non-schema) App Intent** (a plain `AppIntent` +
   `AppEntity` + `EntityQuery`/`AppShortcuts`), which works on iOS 18 today and is fully
   under our control. The fallback is the pragmatic path given the iOS 18.0/18.1 deployment
   target.

2. **`@AssistantIntent`/`@AssistantEntity` are deprecated → use `@AppIntent`/`@AppEntity`
   with `schema:`.** Old WWDC-2024 sample code uses the `@Assistant*` spelling; don't copy it.

3. **Required schema properties are invisible in the `.swiftinterface`.** They're enforced by
   the `AppIntentsMacros` plugin at compile time, surfaced only as build diagnostics. The
   only way to learn a schema's exact required parameters is to (a) build against an SDK that
   has it and read the macro error messages, or (b) Apple's online docs. You cannot reverse
   these from the interface text.

4. **`IntentValueQuery` is iOS 26.0-only.** Even on a future SDK with the `.audio` schema,
   the resolution query is gated to iOS 26. With our iOS 18.0/18.1 floor, the schema path
   (intent + query) is unavailable to the bulk of our users at runtime. A custom AppShortcut
   with a parameterized phrase ("Play {station} on Playola") backed by an `EntityQuery`
   (iOS 16+) is the portable choice.

5. **`AssistantSchemaEntity` brings `isAssistantOnly` and a default
   `typeDisplayRepresentation`** (lines 66–82). Schema-conforming entities also pull in
   `FileEntity`, `UniqueAppEntity`, `URLRepresentableEntity` conformances via the `@AppEntity`
   macro's `@attached(extension, conformances: …)` list — more surface than a hand-rolled
   `AppEntity`.

6. **`Sendable` is required** on `IntentValueQuery` and on App Intents generally; entities
   need `DisplayRepresentation` / `typeDisplayRepresentation` and an `EntityQuery`-typed
   `defaultQuery`. Standard App Intents requirements, but worth stating for the fallback.

---

## Bottom line for the plan

- **BLOCKED on the SDK premise:** the `.audio` App Intents schema domain (`playAudio`,
  `liveRadioStation`, `algorithmicRadioStation`) is **not present** in Xcode 26.5 /
  iphoneos26.5, the newest Xcode on this machine.
- **Recommended fallback (no newer Xcode needed):** ship a **custom App Intent**, not a
  schema-conformant one — `AppIntent` + `AppEntity(RadioStation)` + `EntityQuery` +
  `AppShortcutsProvider` with a parameterized "Play {station} on Playola" phrase. This is
  iOS 16/18-compatible, matches our deployment target, and keeps one `RadioStation` entity
  type that can represent both live and algorithmic stations (our own type, our rules — no
  schema forcing one-vs-two).
- If we specifically need the system `.audio` "play this on Playola from anywhere" Siri
  surface, that requires installing the Xcode that actually contains the `.audio` domain and
  re-running this spike against it.
