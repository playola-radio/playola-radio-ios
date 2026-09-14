# Live shows (formerly "AMA show runner")

> Renamed S39 to a generic **live-shows** primitive; `ask-me-anything` is the first show `type`. The data-layer contract is **§S39** (authoritative); everything above §S39 in the data-layer sections (S37/Phase 5/S38) is a superseded reasoning trail. The S1–S36 visual-design log remains valid.

Status: H including its buffer indicator, and setup states 01, 01b, 02, 03 and 04 are visually approved (S31, 2026-09-13). H1 and H2 are also visually approved (S33). Q1–Q4 are approved with the optional song-after-Q/A action (S36). D–G are archived in the canvas Drafts area. Data contracts, additional states and implementation plan are not yet approved; not implementation-ready.

## Target surfaces and bases

- Surfaces: iOS curator runner and listener player/station-list experience, with backend scheduling support.
- iOS repository: `/Users/brian/conductor/workspaces/playola-radio-ios/kathmandu-v3`
- Inspected iOS commit: `7a249970e8d4d65ba2600ebd61f4ee400b7c5706` (current with `origin/develop` at prerequisite check).
- Backend repository: `/Users/brian/playola/playola`
- Inspected backend HEAD and local develop: `b78c2953f35fa3b1c2f40cb5b532a869d1cc06c6`.
- Canvas: `design/playola-ios.pen`, accessible through Pencil MCP.

## Scope

Design a near-live Ask Me Anything runner for a station curator. Listeners submit recorded questions; the curator reads transcripts, records answers and other voicetracks, and schedules music and Q&A into the station broadcast. Display the current listener count and the remaining scheduling buffer. All newly scheduled content must respect the two-minute scheduling boundary.

### Agreed behavior

- Prepare an opening queue before pressing Start Show. The latest request specifies a ten-minute readiness requirement; setup and disabled/enabled Start states are now being designed.
- Setup begins by recording an intro, followed by a guided playlist state containing only that intro. The curator builds the first ten minutes with songs, past Q&As and voicetracks, including song intros. This latest direction supersedes automatic ten-minute prefill on entering setup; song suggestions remain useful. Ten minutes of recorded speech is not required.
- Distinguish scheduled audio remaining from time available before the two-minute scheduling boundary. Audio still uploading or processing does not count as secured buffer.
- Answer workflow: record, optionally preview/retry, then Add to Show. Append the listener question and curator answer together to the prepared queue, with expected airtime. Allow subsequent reordering outside the two-minute boundary.
- When the buffer gets low, add one fallback song at a time. Show the proposed song and a countdown before insertion without interrupting an active recording. Exact thresholds and race behavior remain to be designed.
- Prefer fallback songs from the regular programming displaced by the AMA; station-library songs are also suitable choices. Allow the curator to swap the suggestion.
- Offer an optional intro for the upcoming fallback song while time permits. The song may air alone if the curator is occupied.
- Preparation should offer a show-intro prompt explaining that listeners can use Ask the Artist on the player page to record questions for the curator to answer during the show.
- Prioritize questions arriving during this show in the runner inbox; keep the existing backlog one tap away. The curator can answer in any order, and submissions do not air until selected and paired with an answer added to the show.
- Approved H reuses the familiar Broadcast on-air and playlist rows, with three add actions after the playlist. Audio appends directly without staging; Q&A opens a separate answering flow and appears as one paired playlist item. These approved choices supersede the earlier staging-based explorations.
- Listener player shows an explicit AMA-happening-now state and a prominent Ask a Question action, retaining the existing question-recording flow. A station hosting an AMA floats to the top of the listener's station list. Exact list surfaces and timing remain to be specified.
- Starting an AMA automatically notifies the station's followers. No curator toggle or separate send action. Recipient eligibility, delivery timing/content, duplicate prevention and interaction with existing notification cooldowns still require contract design.
- End Show offers an outro recording, finishes the remaining queued content, then returns to regular programming. The curator need not choose a duration in advance.
- If the curator leaves the app or loses connection, fallback music keeps the station playing during a grace period. If they do not return, automatically return to regular programming and end the AMA promotion. Exact grace duration, presence detection and handling of queued/processing content remain to be designed.

## Non-goals and deferred ideas

- This is a design effort; application implementation happens in later sessions.
- Reusing the existing Q&A screen wholesale is not a requirement. Reuse useful components and capabilities where appropriate.
- Required preparation of four or five song intros is tabled. Optional intros prepared in advance for use only within this show may be revisited; that larger feature is not approved for the initial scope.

## Existing state inspected

- Shipped Broadcast frame `f3K4Q0`: songs and voicetracks staged in Ready to Place, then inserted into the schedule. `BroadcastPageModel` exposes upcoming spins and restricts deletion to spins more than 120 seconds away.
- Shipped broadcaster questions frame `OQtHt`: question list with pending/answered filters, audio playback and transcripts.
- Existing exploratory AMA frames `PKL5j` and `HvVZz`: inline answer recording, suggested song, audience count and buffer display. These are reference material, not approved visual contracts for this feature.
- `AskQuestionPageModel`: listener recording/review/upload and instructions that the question and response may air on the station.
- `ListenerQuestionDetailPageModel`: answer recording, review/retry, processing and answer registration.
- Backend `listenerQuestions.lib.ts` currently links an answer and creates a Q&A airing at a randomized time roughly two days later. AMA needs a deliberately designed scheduling path for this show.
- Backend models inspected: ListenerQuestion (question and answer AudioBlock references; status; listener/station ownership), Spin (station/audio references, airtime, end-of-message time, optional ListenerQuestionAiring and spin-group references).

Existing Broadcast, questions list, and answer idle/recording/review screenshots are saved under `exports/existing/` using their canvas IDs as filenames. Full relevant field tables and request/response contracts are still pending.

## Visual exploration V1

Three alternatives in the canonical canvas, in zone `dGvzn` (AMA Runner · Exploring), below Home v2. These depict the same show moment and are not approved screens.

| Direction | Frame | Emphasis | Tradeoff | Preview |
| --- | --- | --- | --- | --- |
| A — Questions first | `f9reh` | Browse incoming transcripts and answer inline; buffer and backup song stay visible | Full queue requires opening Queue | [PNG](exports/exploration/f9reh.png) |
| B — Schedule first | `k06CM4` | See on-air content, upcoming pairs/songs, locked items and reorder handles | Questions have less room and answering opens a focused view | [PNG](exports/exploration/k06CM4.png) |
| C — One answer at a time | `n7lNyi` | Large transcript and prominent recording action, compact on-air/next summary | Browse other questions and the full queue via separate controls | [PNG](exports/exploration/n7lNyi.png) |

All use the existing canvas typography/color tokens and show 38 listeners, 7 new questions, a separate backlog entry, voice-track/song actions, End, and a suggested backup song with optional Intro and Swap actions. Exploration PNGs, resolved screen JSON, and a token snapshot are in `exports/exploration/`.

Sample timing is internally consistent: the on-air song has 1:18 remaining, followed by a 1:24 Q&A, a 3:05 song and a 0:45 Q&A, totaling 6:32 queued and 4:32 beyond the two-minute boundary. The sample automatic-add countdown of 3:32 assumes insertion with 3:00 of queued audio left (one minute ahead of the boundary); this threshold is a proposal for discussion, not an approved contract. Queue 4 counts the on-air item plus three upcoming items in these explorations.

Visual checks: all three frames were screenshot-reviewed after layout settled; the Pencil layout checker reported no clipping problems. Each screen is 393 × 852, exported at 2×. Recording, review, low-buffer and other states will be designed for the selected direction, one screen/state approval at a time.

## Visual revision V2 — Familiar Broadcast

Frame `TPitr` (AMA Runner · V2 · Familiar Broadcast), to the right of the initial three alternatives in the same zone. [PNG preview](exports/exploration/TPitr.png); resolved JSON alongside it. This is a proposed revision, not an approved screen.

- Reuses actual existing components: `EqHkj` circular broadcast actions (slightly smaller circles), `GpwDu` staging rows, `th8Fu` grouped schedule rows, and `k7Cd7m` navigation. Now Playing is copied from the shipped Broadcast screen.
- Keeps VoiceTrack and Add Song actions in their familiar position; Questions shows the new-question count and opens a separate inbox/answering flow. The already-approved automatic notification on Start makes a Notify button unnecessary here.
- Replaces the large buffer panel with one compact readout and audience count. A secondary line distinguishes queued audio from the locked two-minute window.
- Places the suggested fallback song in Ready to Place, labeled with its automatic-add countdown. Opening that row would offer intro and swap options. Manual placement remains available; auto-fill chooses only its designated backup item and must not silently publish arbitrary staged recordings.
- Retains the ready VoiceTrack above the fallback song and the on-air/upcoming queue below. The question and answer appear as adjacent, grouped rows; the pair moves together and locked rows show lock icons. Q&A still uses the previously approved Add to Show action to append automatically. Regular manually created songs and voicetracks retain staging/placement behavior.
- V2 sample: current song has 1:18 left; next are a 0:24 listener question, a 1:00 answer, a 3:05 song, and a 0:45 voicetrack. Total secured queue is 6:32. The extra 0:14 recording in staging and suggested backup song are excluded from the buffer.
- Proposed question-screen behavior: retain a compact buffer while reading/recording; complete Add to Show there and show the resulting airtime, allowing the curator to continue with questions or return to the runner. Detailed navigation and recording states have not been designed or approved.
- Screenshot-reviewed and checked for clipping after layout settled; 393 × 852, PNG exported at 2×.

## Visual revision V3 — Timing in context

The user requested three more variations of the familiar Broadcast direction, noting that the “4:32 to add more” banner did not provide enough information for its visual footprint. These are new explorations, not approved screens.

All three copy V2's familiar actions, staging and grouped schedule. The standalone status banner is removed. AMA mode and 38 listeners appear under the station name; Questions opens separately. The same sample audio, timings and backup insertion threshold from V2 apply. Existing manual staging actions and automatic Add to Show behavior remain as described above.

New zone `G0JLmd` (AMA Runner · V3) is one row below the earlier explorations.

| Direction | Frame | Timing treatment | Tradeoff | Preview |
| --- | --- | --- | --- | --- |
| D — Coverage in the queue | `h4ZY4a` | 6:32 queued beside Upcoming; automatic-add countdown on the staged backup song | Two-minute-boundary details require tapping queue coverage; locked row icons stay visible | [PNG](exports/exploration/h4ZY4a.png) |
| E — Queue timeline | `UtE2s` | An Upcoming timeline relates 6:32 scheduled to 2:00 locked and 4:32 still editable | Most explicit timing, but more labels than D or F | [PNG](exports/exploration/UtE2s.png) |
| F — Simplified | `o23lK` | Coverage and automatic-song notice removed at user request | Buffer visibility and backup-song controls remain to be revisited | [PNG](exports/exploration/o23lK.png) |

F now omits the entire music status block (text, icon, and disclosure). Its original proposed entry to backup-song options is therefore absent for this iteration. Only actual manually staged audio remains in Ready to Place. The backup is excluded from queued duration until actually scheduled. The user requested this visual removal for now; automatic music protection remains in product scope.

D explores making the two-minute boundary an on-demand detail during healthy operation; simplified F currently has no buffer-detail entry. Low-buffer emphasis and the expanded timing detail still need design and approval; this exploration does not remove the scheduling constraint or low-buffer protection.

All three were visually inspected and checked for clipping after layout settled. PNGs and resolved JSON are saved in `exports/exploration/` at 393 × 852 logical size / 2× PNG resolution.

### F follow-up — Combined Q&A row

At user request, F displays a question and its answer as one queue item titled **Question and Answer: Maya**, with combined duration 1:24 and airtime in 1:18. The next rows are VoiceTrack (0:45, in 2:42), then Hummingbird (3:05, in 3:27). This replaces F’s two separate question/answer rows; the other alternatives remain historical explorations. The paired item remains indivisible for placement/reordering and preserves its earliest-airtime lock. Total queued audio including the on-air song remains 6:32.

### F follow-up — Match the running app

User provided a screenshot of Broadcast in practice, preserved as [reference](exports/existing/broadcast-in-practice.png). Removed the Upcoming label and its 40-point heading area from F; an 8-point gap now separates the on-air progress line from the first queue row. Now Playing retains title, artist, LIVE NOW badge and progress line; its artist subtitle no longer adds a remaining-time label. Queue rows use the app’s absolute-airtime style: at 9:42:18am, at 9:43:42am and at 9:44:27am, consistent with the existing 9:41 sample. Q&A, VoiceTrack and Hummingbird retain their agreed order.

### F follow-up — End Show and drag guidance

Moved End Show from the navigation header to a visible rounded button pinned above the bottom tabs. It has a raised dark fill, subtle border, and a 44-point height with horizontal insets. It remains reachable as the playlist scrolls and opens the previously agreed outro/wrap-up flow. Added a small downward arrow and “Drag an item down into the playlist” between staging and the on-air row. This explains individual-item placement; existing two-minute lock rules still determine valid drop positions. The cue is intended for nonempty staging. The rest of F’s content and ordering remain intact.

### F follow-up — Single-line show header

Replaced the station name and separate AMA/audience subtitle with one header row: Ask Me Anything on the left and 38 listening on the right. The header is 44 points tall instead of 60, returning 16 points to the playlist area.

## Visual comparison G — Add Audio in the playlist

New frame `rIca5` (AMA Runner · G · Add Audio in Playlist) is immediately to the right of F. F is preserved for comparison. [PNG](exports/exploration/rIca5.png), with resolved JSON alongside it. G copies the latest F and removes only the top ADD TO SHOW heading and the three action buttons. A single coral Add Audio button appears directly after the last playlist row, within the scrolling playlist; End Show remains pinned above the tabs. Following the user’s next revision, G also removes Ready to Place and its drag guidance. The title/listener count, now-playing presentation, Q&A grouping and queue order are retained. The freed space goes to the playlist area.

The intended Add Audio entry opens the existing choices (Voicetrack, Song, Q/A); this choice presentation is not yet designed. In G, accepted audio appends directly to the playlist once ready, with no separate staging or drag-to-place step. Q&A remains paired; subsequent reordering is available outside the lock boundary. Upload/processing and retry presentation still need design; unfinished audio must not count toward the secured buffer. This explicitly supersedes manual staging for G, while F retains it for comparison. This is an additional layout exploration, not a visual approval.

## Visual comparison H — Three playlist actions

Frame `K9H7f` (AMA Runner · H · Three Playlist Actions) now follows state 04 in the approved design row. [PNG](exports/approved/K9H7f.png), with resolved JSON alongside it. H copies current G, replacing the single Add Audio button with the existing circular Voicetrack, Song and Q/A controls directly after the last playlist item. The controls now sit in a padded, rounded Add to Show group, separated from the playlist rows, with the helper Added to the end of your playlist. Each audio-type icon has a small lower-right plus badge. Audio still appends without staging. Header, content, order, times, End Show and navigation are unchanged. F and G remain available for comparison. User approved the completed H layout on 2026-09-13 (revision S27).

## Approved running-show screen

- Frame: `K9H7f`, AMA Runner · H · Three Playlist Actions.
- Approved revision: H including the S30 buffer readout above End Show; approved 2026-09-13 in S31. The padded Add to Show group and plus badges remain from the S27 approval.
- Canonical canvas: `design/playola-ios.pen`.
- Approved exports: `exports/approved/`. Earlier explorations remain as comparison material and are not implementation contracts.
- This approval covers the running-show screen shown in the mockup; it does not silently approve unshown preparation, low-buffer, recording, error or recovery states.

## Setup and waiting-state mockups — Revision P2

Five setup frames and H now form the approved design zone `eoeNV` at y=15578. All six screens are approved in S31. Canvas order is 01 → 01b → 02 → 03 → 04 → H; original state IDs and numbering are preserved. Drafts D–G are retained in zone `G0JLmd` at y=17162, immediately below. Their status is archived draft, not approved.

| State | Frame | Behavior shown | Preview |
| --- | --- | --- | --- |
| 01 — Record an Intro | `u1jha` | Empty setup starts with the user's intro guidance and a prominent Record Intro action. Start Show is disabled; 0:00 of 10:00 ready. | [PNG](exports/approved/u1jha.png) |
| 01b — Build Your Opening | `cDCux` | Intro already recorded. Guidance explains building ten minutes with songs, past Q&As and song intros. 0:30 ready; Start disabled. | [PNG](exports/approved/cDCux.png) |
| 02 — Almost Ready | `M6FLxv` | Opening playlist totals 8:35. Footer says Add 1:25 more; Start Show is disabled. Add controls remain at the playlist end. | [PNG](exports/approved/M6FLxv.png) |
| 03 — Ready to Start | `F4XUs4` | Intro included and 10:35 ready. Start Show is enabled. The notification sentence was removed at user request; automatic notification behavior remains unchanged. | [PNG](exports/approved/F4XUs4.png) |
| 04 — Waiting to Air | `OFqgG` | Start accepted; the current regular song remains on air. Your Show Starts in 2:18 and the scheduled start time explain the transition. Playlist additions remain available. | [PNG](exports/approved/OFqgG.png) |

### Preparation semantics

- The intro prompt announces the AMA, directs listeners to the Question button on the Player screen, and says the curator will try to answer as many questions as possible, per S28.
- Setup shows SETUP instead of a live listener count. Regular station programming continues; the empty/partial/ready views show the curator's draft opening playlist, not a second on-air schedule.
- Readiness is completed, accepted show audio. Uploading/processing audio and the regular station song do not count toward the ten-minute requirement. Before Start, the prepared duration does not tick down with wall-clock time.
- The example partial playlist is Show Intro 0:30, Hummingbird 3:05, Question and Answer: Maya 1:24, and Whiskey Papers 3:36, totaling 8:35. The ready state adds a 2:00 voicetrack, totaling 10:35. These durations are illustrative design data.
- Draft rows show durations instead of invented airtimes. The intro is shown pinned first; the exact intro replacement/removal interaction still needs agreement.
- Intro is the first task. State 01b contains that completed intro and a contextual Add to Show prompt: Let’s get a little ahead. Its copy explains building the first ten minutes with songs and past Q&As, using Voicetrack for song intros. Approved H’s direct-append behavior remains; no staging/drag step is reintroduced by this helper. It is a sparse-playlist guidance state, not a literally empty list. The generic Add to Show treatment appears once more content has been added.

### Waiting-to-air semantics

- The waiting sample is at 9:41 with the intro accepted for 9:43:18 (2:18 ahead). The currently playing My Boots belongs to regular programming; LIVE NOW describes that audio, not an already-started AMA.
- Start must choose a valid track boundary at least two minutes ahead when the server accepts the schedule. If the current spin ends too soon, intervening regular programming must finish before the intro. A countdown may later pass below two minutes without violating the original scheduling lead time.
- Opening airtimes in the sample are 9:43:18, 9:43:48, 9:46:53, 9:48:17 and 9:51:53. The final clip ends at 9:53:53, for 10:35 of show content.
- The waiting screen says listeners have been notified and the show starts automatically. Notification copy should accurately describe the imminent start; listener discovery timing still requires design.
- The Start action is no longer present once accepted. This mockup uses a status footer while waiting; cancellation/abandonment behavior remains an open design detail. Once the intro airs, the screen transitions into the approved running-show layout with End Show.

All five states were screenshot-reviewed and checked after layout settled with no reported clipping. PNGs are 786 × 1704; resolved screen JSON is alongside each image. Recording, preview, processing/error and interruption states remain future design work.

## Approval log

These entries record the scope decisions approved in chat, in chronological order. They do not approve unfinished details or the document as a whole.

1. Revision S1 — User chose preparing enough audio and pressing Start; accepted the timing distinction; explicitly allowed redesign beyond the current Q&A screen.
2. Revision S2 — User approved automatic placement of the Q&A pair with reordering afterward.
3. Revision S3 — User liked one-song fallback protection, raised optional song intros, and then accepted optional intros while deferring mandatory multi-song intro preparation.
4. Revision S4 — User accepted fallback suggestions from displaced programming and also proposed a selection from the station library.
5. Revision S5 — User replied “love it” to End Show offering an outro, draining remaining queued content, and returning to regular programming without a preset show duration.
6. Revision S6 — User approved prioritizing new questions over the existing backlog.
7. Revision S7 — User emphatically approved a listener AMA state with a prominent question button and requested promotion to the top of the listener's station list.
8. Revision S8 — User approved automatically notifying followers on Start and explicitly rejected a notification toggle.
9. Revision S9 — User approved prefilling preparation with roughly ten minutes of upcoming songs, then allowing an intro, backlog answers, replacements and reordering before Start.
10. Revision S10 — User accepted a grace period for curator absence/disconnection before an automatic return to regular programming, with fallback music protecting playback.
11. Revision S11 — User requested three layout directions. V1 delivers alternatives A/B/C; no direction has been selected or visually approved yet.
12. Revision S12 — User preferred A but found it cluttered, required stronger reuse of `f3K4Q0` staging/queue/actions, and suggested offloading question/answering to a separate screen. V2 explores that suggestion; no V2 visual approval yet.
13. Revision S13 — User said V2 was closer but still cluttered, singled out the “4:32 to add more” banner as insufficiently useful for its footprint, and requested three more variations. V3 delivers D/E/F; no screen has been visually approved.

14. Revision S14 — User named F their favorite but still found the designs cluttered, and explicitly requested removing the coverage and automatic-song countdown text for now. Removed the whole status block from F in place; this is a targeted revision, not approval of the complete screen.

15. Revision S15 — User requested combining question and answer into one item labeled “Question and Answer: Maya,” followed by VoiceTrack and then Hummingbird. Updated F in place with the combined duration and corrected airtimes.

16. Revision S16 — User requested removing Upcoming and matching the provided live Broadcast screenshot. Updated F’s on-air/queue transition and absolute-airtime presentation, preserving the agreed content and staging.

17. Revision S17 — User suggested moving End Show to the list end or screen bottom and requested a downward-drag cue for staging. The revised proposal pins End Show above the tabs and adds the staging instruction; exact placement still awaits visual feedback.

18. Revision S18 — User clarified that End Show should retain a visible button appearance. Replaced the plain-text treatment with a filled, bordered, rounded button in the same bottom location.

19. Revision S19 — User requested removing the station name, using Ask Me Anything as the title, and placing the listener count on the same line at top right to save vertical space. Updated F accordingly.

20. Revision S20 — User requested an indication that the top action group adds content. Added the heading ADD TO SHOW above VoiceTrack, Add Song and Questions, using the same section-label styling as Ready to Place.

21. Revision S21 — User requested the exact action labels Voicetrack, Song and Q/A. Updated the three labels in F, removing the inline new-question count from the Q/A label and matching its weight to its peers.

22. Revision S22 — User requested removing the ellipsis from the button label. F now reads End Show.

23. Revision S23 — User requested another version almost identical to F, preserving F for comparison, replacing the three top actions with an adding-audio button at the end of the playlist. Created G (`rIca5`) accordingly.

24. Revision S24 — User requested removing Ready to Place in G because added audio goes to the playlist bottom. Removed staging and its drag instruction from G; accepted audio now appends directly. F remains unchanged for comparison.

25. Revision S25 — User requested H, identical to G except that the playlist-end Add Audio button becomes the three buttons. Created H (`K9H7f`) with Voicetrack, Song and Q/A at the playlist end.

26. Revision S26 — User requested clearer adding affordances for H, including padding/enclosure, and suggested a plus at the bottom right of every icon. Added the padded Add to Show group, placement helper, and lower-right plus badges to Voicetrack, Song and Q/A.

27. Revision S27 — User explicitly said “let’s lock in H,” approving `K9H7f` (AMA Runner · H · Three Playlist Actions) after the S26 visual revision. They requested separate mockups for intro-first empty setup, less than ten minutes ready, and waiting to air after Start. A ready-to-start mockup will also show the threshold transition. New states still require visual approval.

28. Revision S28 — User clarified step one: prompt the curator to record an intro announcing the AMA, directing listeners to the Question button on the Player screen, and saying they will try to answer as many questions as possible. The empty-state prompt uses that guidance. User also explicitly requested separate mockups for the states.

29. Revision S29 — User explicitly locked 01 (`u1jha`, AMA Setup · 01 · Record an Intro) and 02 (`M6FLxv`, AMA Setup · 02 · Almost Ready). Recorded their individual approvals and exported them under exports/approved. User requested a new intervening state after recording the intro; created 01b (`cDCux`) with ten-minute preparation guidance. Removed the notification sentence from 03 and changed 04’s countdown to Your Show Starts in 2:18. New 01b and revised 03/04 are not yet visually approved.

30. Revision S30 — User proposed adding 03’s progress indicator to H, showing remaining buffer as a percentage of ten minutes. Updated the working H frame with “6:32 buffered” and “65% of 10 min” above End Show, using the same compact readout and progress bar as preparation. This addition awaits visual approval; the approved H exports preserve the S27 baseline, and exploration exports contain the revision.

31. Revision S31 — User explicitly approved H with its buffer indicator and all numbered states: 01 (`u1jha`), 01b (`cDCux`), 02 (`M6FLxv`), 03 (`F4XUs4`) and 04 (`OFqgG`). Grouped all six frames into the blue Approved Design area, moved D–G to the separate Drafts row below, and refreshed PNG, resolved JSON and both HTML exports in exports/approved. Earlier S29/S30 pending statuses are superseded by this approval. This is visual approval of the shown screens; remaining contracts and unshown states still need design.

### Approved active buffer indicator (S30, approved S31)

The footer reports scheduled audio remaining, including the unplayed portion of the current item, excluding unscheduled or processing audio. The example has 6:32 remaining, approximately 65% of the ten-minute target. The bar caps at 100%; the duration continues to show the full remaining time above ten minutes. The two-minute scheduling minimum corresponds to 20%, not an empty bar. H1/H2 now show the approved warning styling and a three-minute insertion example; the scheduler must preserve the two-minute minimum.

## Approved buffer protection mockups — S32, approved S33

Two separate states based on approved H sit immediately to its right in blue approved zone `Tx61O`. The approved H and setup states remain unchanged.

| State | Frame | Behavior shown | Preview |
| --- | --- | --- | --- |
| H1 — Song About to Be Added | `GLrlG` | Amber 3:30 buffered / 35% of 10 min. One line beneath the progress bar says Adding Hummingbird in 0:30. The unscheduled suggestion does not count toward the buffer or appear as a committed playlist row. | [PNG](exports/approved/GLrlG.png) |
| H2 — Song Automatically Added | `VPjJg` | Thirty seconds later, Hummingbird has been appended at 9:44:30am. Buffer rises from 3:00 to 6:05 / 61%. The green progress bar returns and a brief confirmation says Hummingbird added to keep your show going. | [PNG](exports/approved/VPjJg.png) |

The example proposes insertion at three minutes remaining, before the two-minute scheduling minimum; it does not wait for playback buffer to reach zero. Both examples use My Boots ending at 9:42:21, followed by Maya's 1:24 Q&A and a 0:45 voicetrack, ending at 9:44:30. H1 is at 9:41:00; H2 is at 9:41:30 (both display 9:41 in the status bar). The confirmation is transient; its exact duration is not yet settled. Thresholds, fallback-selection availability, insertion failure and concurrency behavior still require contract design. Optional intro and suggestion-swap entry points remain to be designed; these mockups focus on the status transition. Both screens are visually approved in S33.

32. Revision S32 — User requested the approaching automatic-insertion and just-inserted states. Created H1 (`GLrlG`) and H2 (`VPjJg`) beside H, preserving the existing layout and putting the concise warning/confirmation alongside the buffer meter. Exported PNG and resolved JSON for review; no new visual approval is implied.

33. Revision S33 — User responded “LOVE IT!” to H1 (`GLrlG`, Song About to Be Added) and H2 (`VPjJg`, Song Automatically Added), approving both visual states. Marked their canvas area blue and labels approved; saved PNG, JSON and both HTML exports with the other approved screens. The example uses a three-minute insertion point; failure handling and scheduler contract details remain future design work.

## Song and Voicetrack reuse — S34

User explicitly requires reusing Broadcast's Song and Voicetrack interfaces. `BroadcastPageModel.onAddSongTapped()` presents `SongSearchPageModel(searchMode: .all)`; `onAddVoiceTrackTapped()` presents `RecordPageModel`. AMA should use those existing search/selection and recording/review interfaces. The acceptance destination changes to the AMA opening/live playlist, per approved H's direct-append behavior, with processing excluded from ready buffer. Broadcast itself retains its staging behavior. Scheduler integration and upload failures require implementation contracts; no application code was changed.

## Approved Q/A picker and answer flow — S36

Four mockups in zone `Kc5c1`, below Drafts at y=18746, adapt the existing question list `OQtHt` and answer states `t9aeF`, `t69Km`, `ZCBuR`. All four are visually approved in S36.

| State | Frame | Behavior shown | Preview |
| --- | --- | --- | --- |
| Q1 — Question Picker | `NeOtx` | All / Unanswered / Answered filters, with All selected. Each card has an explicit answer-status badge. Every filter sorts by question submission date, newest first; new submissions show New this show beside their timestamp. Transcript expansion and question-audio sampling remain available. Unanswered cards open the recorder; answered cards open existing-pair review. | [PNG](exports/approved/NeOtx.png) |
| Q2 — Read and Record | `E4LFx` | Full listener transcript, question playback and scrubbing, familiar response recorder, persistent buffer. | [PNG](exports/approved/E4LFx.png) |
| Q3 — Recording Answer | `HadXP` | Transcript remains visible; elapsed recording time, waveform and Stop recording. Question audio is paused/disabled while recording. | [PNG](exports/approved/HadXP.png) |
| Q4 — Review and Add | `Q52Pi9` | Preview the answer, Re-record, or Add to Show. Question audio remains available. The pair's total duration is shown (0:28 + 0:56 = 1:24). Optional Add a song after this opens the reused Broadcast song picker. | [PNG](exports/approved/Q52Pi9.png) |

The original detail implementation (`ListenerQuestionDetailPageView`/`Model`) supports question seeking and answer review via `PlaybackScrubberView`; preserve those capabilities. The existing Upload Response action processes audio and registers the answer, then returns to root. AMA's Add to Show must additionally append the question/answer pair after successful readiness and scheduling; submission alone is not scheduling success. Retrying must not duplicate a pair. Playback of question, answer and station monitoring must not overlap microphone capture. Existing two-minute answer-length guidance is retained in these drafts; that recording limit is separate from the broadcast scheduling minimum.

Proposed navigation after successful addition: return to the picker with a brief confirmation and update the buffer, so another question can be answered. An optional clarification was sent in chat; this is the working assumption until the user chooses otherwise. Back from the picker returns to the show. Refresh must preserve the question currently being read or answered. The 6:32 meter is an illustrative snapshot in each mockup; in use it updates as playback proceeds and fallbacks are inserted, even on this screen. Preserve the approved low-buffer/auto-add feedback without interrupting an answer. During preparation, show prepared duration instead of a ticking live buffer.

Still to design: filtered empty lists and existing-pair preview, empty/loading/transcription-pending states, upload/processing/scheduling success and error states, microphone permission and interruption handling, leaving an unsaved answer, and long transcript scrolling that keeps recording controls and buffer reachable. Submission-date ordering is confirmed newest first within every filter. Intake timing and handling after scheduling still need contract decisions. Answered questions must let the curator preview the existing answer before appending the pair. Answered describes the presence of a completed answer; it does not mean already scheduled in this show.

34. Revision S34 — User required reuse of Broadcast Song and Voicetrack flows and requested designing the AMA Q/A picker/recorder using the existing Q/A screens as a guide, specifically retaining transcript reading and recording sampling. Recorded the reuse requirement and produced Q1–Q4 for review. Filter organization and post-add navigation are proposals, not user-approved decisions.

35. Revision S35 — User requested an All option, visible answered/unanswered status, and clarification of Earlier versus Past Q/As. Explained that the former meant unanswered backlog and the latter completed pairs. Replaced those ambiguous source filters with All / Unanswered / Answered in Q1 (`NeOtx`), added status badges to every sample card and a New this show marker for fresh submissions. The mockup now includes both answered and unanswered examples. This revised picker awaits visual approval.

36. Revision S36 — User approved the revised picker (“GREAT!”), confirmed submission-date sorting (newest first within each filter), and said the Q/A flow was good. They then accepted the proposed optional Add a song after this action and explicitly requested adding it to the approved design. Added the action to Q4 (`Q52Pi9`), marked Q1–Q4 approved on the canvas, and refreshed approved PNG/JSON/HTML exports.

### Optional song after a Q/A — approved S36

Q4 includes a secondary Add a song after this action above the review buttons. It opens the existing Broadcast song picker. Selection returns to Q/A review with the selected song, where it can be changed or removed before acceptance. Add to Show schedules the question and answer together, followed immediately by the selected song; without a selection it schedules only the pair. Cancelling the song picker preserves the answer and leaves Add to Show available. The song is optional and introduces no mandatory prompt. The Q/A remains one indivisible paired item, while its following song is a normal playlist item. Respect the two-minute scheduling boundary for all inserted audio; ordering and retry/failure handling require a backend contract. The selected-song row and its change/remove controls are described here but not yet separately mocked up.

## Open questions

- Question inbox: stable tie-breaking for equal submission dates, dismissal and unanswered-question behavior; when the show-specific intake window begins.
- Preparation: finalize intro replacement/removal rules, presentation of song suggestions and start placement in the existing schedule. The post-intro state now guides manual additions toward ten minutes.
- Listener discovery: exact station-list surfaces and ordering when multiple AMAs are active; timing of promotion/badge relative to Start and actual airtime; notification eligibility/cooldowns and delivery details; preparation and wrap-up states.
- Buffer: warning and insertion thresholds, recording/processing allowance, fallback selection/intro deadlines and automatic-insertion races.
- Queue: movement granularity, replacement/deletion, already committed items, and changes to expected airtimes.
- Ending: cutoff for question intake, treatment of processing items, and the exact transition back to regular programming.
- Reliability: grace-period duration and presence definition, app backgrounding, recording interruptions, recovery, queue handling on automatic end and repeated requests. Long active recordings must be considered when defining presence.
- Audience count: existing data source, meaning and refresh cadence.
- Models, endpoint contracts, authorization, migrations and scheduler integration require design and review.

## Remaining design work

Complete the relevant contract survey; design unshown recording, error and recovery states; settle remaining product details; approve each screen and applicable states; design backend model and endpoint changes; run opposite-provider adversarial review and disposition findings; write implementation plan; export and verify approved designs; ship design PR to develop.

## Data Layer — models, endpoints, and LIVE-episode rules (Opus, S37)

> **SUPERSEDED by S39 (2026-09-13).** The entire data layer below (S37 → Phase 5 → S38) assumed a heavy design — a dedicated `AmaSession` table, a continuous auto-fill worker, a shared serialization boundary, measured-duration readiness, and a lifecycle state machine. The product owner rejected that as over-engineered and pivoted to a slim generic **live-shows** primitive; see **§S39 — Pivot to the generic `live-shows` primitive** for the authoritative model. S37/Phase 5/S38 are kept only as the reasoning trail. Do NOT implement anything below.

All changes target the playola backend (`/Users/brian/playola/playola`, `develop` `b78c2953f35fa3b1c2f40cb5b532a869d1cc06c6`). iOS is an API consumer only; the items below are a **needs list for the server repo**, not iOS work. This section is designed against the real backend, surveyed in-session via three exploration passes over `src/db/models/*` and `src/lib/scheduler/*`.

### Existing substrate this design reuses (surveyed S37)

- **Authoring → air stack:** `Show → Episode → EpisodeSegment → Airing → Spin`. `Episode` owns an ordered list of `EpisodeSegment`s (each holds `audioBlockId` **XOR** `songRequestId`, a `position`, and computed `offsetMS`/`fades`). `createAiring({episodeId, stationId, airtime})` → `insertAirings` materializes the whole ordered segment list into N `Spin`s in one atomic pass (shared `spinGroupId = airing.id`) and deletes/reflows the regular spins it displaces. This is the "insert multiple tracks atomically" primitive — it already exists.
- **Boundary takeover:** `findStartTimeForShow` walks to the end of the currently-airing spin-group and starts the airing there — the "airs after the current song finishes" behavior, for free.
- **Live-schedule editing:** `insertSpin` / `moveSpin` / `deleteSpin` (`src/lib/scheduler/scheduler.ts`) each enforce a **2-minute locked-in horizon** (`SPIN_TOO_SOON_*`), recompute the affected sub-range, and top up a **3-hour minimum runway**. `getStationSchedule({lockedIn})` is the read-side mirror. These are the primitives the Broadcast live editor already uses.
- **Q&A pipeline (already built + wired):** `ListenerQuestion` (question `audioBlockId`, `answerAudioBlockId`, `status` `pending|answered|declined`; transcript on `AudioBlock.transcription`) + submit/list/answer/decline endpoints. Answering today auto-creates a `ListenerQuestionAiring` at a **random airtime ~2 days out**; the general scheduler materializes each airing into a **tagged question-spin + answer-spin pair** (`Spin.listenerQuestionAiringId`), which clips/tapes/timeline key on.
- **Recorded audio → schedulable:** voicetrack presigned-URL → S3 intake → LUFS-normalize (poll status) → `POST /v1/stations/:id/voicetracks` → `AudioBlock` (+ async Whisper transcription). Reused verbatim for intros and Q&A answers.
- **`voicetrackSession` is NOT reusable** — it is an admin analytics report that retroactively clusters aired voicetrack spins, not a stateful builder.

### Decisions locked with the user (S37)

1. **The AMA session *is* an `Episode`** (`kind='ama'`) under a lazily-created, per-station "Ask Me Anything" `Show`. No new session/wrapper model. Past AMAs = past episodes → history for free.
2. **A Q&A playlist item is an `EpisodeSegment.listenerQuestionId`** (three-way XOR) that expands into the tagged question+answer spin pair at materialization.
3. **Runway is server-authoritative.** The 10-minute ready gate and the low-buffer/auto-fill thresholds are server constants surfaced as `amaConfig`; the server *enforces* the gate and *runs* auto-fill. Buffer values can change without an iOS release; client meters are a reflection only.
4. **"End Show" is a wrap/drain, not a truncate.** Lifecycle: `building` (client-side only) → `live` → `wrapping` → `ended`. There is no "cut the airing" primitive.
5. **The live timeline is spin-authoritative** after go-live. Live add/reorder/delete reuse the existing Broadcast live-schedule spin primitives. `EpisodeSegment`s record the *opening* playlist and its Q&A linkages; the live timeline is the spins, tagged as the AMA airing group.
6. **AMA Q&A spins feed clips/tapes/timeline** like scheduled Q&As: materializing a Q&A mints a `ListenerQuestionAiring` purely as the tag those subsystems already key on (`EpisodeSegment.listenerQuestionId` is authoritative; the LQAiring is a derived scheduling/tag artifact).
7. **Auto-fill is compute-only** — no pending-fallback table; the next fallback pick is computed and committed under the existing per-station Redis scheduling lock.

### Rules for the LIVE (`kind='ama'`) episode type

This is a new episode type: an episode edited *while it airs*. Its semantics:

1. **Born committed.** `POST …/ama-sessions` carries the ordered opening array; the server enforces `readyMS ≥ readyThresholdMS` (10 min) and materializes it as an Airing at create. There is no server-side "building" episode — building is a client-side assembly of `audioBlockId`/`songRequestId`/`listenerQuestionId`.
2. **Boundary takeover.** Inserted into the next available slot; AMA spins begin the moment the currently-airing spin/group finishes (`findStartTimeForShow`), never mid-song. "Waiting to Air" is *derived* from `now < firstAmaSpinAirtime`, not a stored status.
3. **Preemption.** AMA spins preempt and reflow the regular rotation they displace (existing `insertAirings` behavior).
4. **Live edits = live-schedule editing.** Add / reorder / delete reuse `insertSpin`/`moveSpin`/`deleteSpin` — same 2-minute lock, same reflow. A song/voicetrack add = one spin; a Q&A add = the tagged question+answer pair (a spin-group moved/deleted atomically).
5. **No-gap invariant (core new rule).** The AMA group must always hold `≥ lowBufferThresholdMS` of queued audio ahead of the playhead. Any edit that would drop below it, plus a periodic compute-only check under the Redis scheduling lock, triggers auto-fill of one fallback song (preferring displaced regular programming, else station library). A cut-off/disconnected curator never yields dead air or an abrupt snap back to rotation. Auto-fill inserts *outside* the 2-minute lock, so the real trigger threshold sits above 2 min (H1 shows 3:00).
6. **Wrap drains.** `finish` sets `wrapping`, disables auto-fill, optionally appends a closing voicetrack; the queue plays out; when the last AMA spin ends → `ended`, rotation resumes, and question-intake for the show closes.
7. **Q&A tagging.** Each Q&A (opening or live) mints a `ListenerQuestionAiring` so both spins carry `listenerQuestionAiringId` (and, for AMA, also the AMA `airingId`) and surface in clips/tapes/timeline.

### (a) Changes to existing models

- **`Episode`** (becomes the AMA session):
  - `kind ENUM('regular','ama') NOT NULL DEFAULT 'regular'` — discriminator.
  - `status ENUM('live','wrapping','ended') NULL` — set only for `kind='ama'`. **Stored, not derived** (the `wrapping` intent — auto-fill off — is not recoverable from spins).
  - `endedAt DATE NULL` — the hard marker for "question-intake closed" + history. `startedAt` is **derived** from the Airing's first AMA spin (not stored).
- **`EpisodeSegment`** (Q&A support):
  - `listenerQuestionId UUID NULL` FK → `listenerQuestions.id`. Now exactly one of `{audioBlockId, songRequestId, listenerQuestionId}` (validated in the lib, matching the existing XOR-in-lib convention).
- **`ListenerQuestion`**: no columns change. `status='answered'` continues to mean "answer audio exists," independent of whether/where it has aired (matches approved "Answered ≠ already scheduled").
- **`Station`**: **no new column.** "Live-AMA floats to top / player shows AMA-now" is served by a *computed* `activeAma` field in the station + station-list serializers, sourced from `Episode(kind='ama', status IN ('live','wrapping'))` for the station. (Needs an index on `Episode.status`/`kind`; query cost is a review item.)

### (b) Changes to existing endpoints

1. **Answer** `POST /v1/stations/:stationId/listener-questions/:questionId/answer` — add optional `defer` (boolean): when true, set `answerAudioBlockId` + `status='answered'` but **skip** the auto ~2-day `ListenerQuestionAiring`. AMA answers use `defer:true` and are placed via the episode/segment.
2. **Station + station-list serializers** — add computed `activeAma` (nullable block: `{ episodeId, startedAt }` or similar).
3. **Live edits** route through the existing Broadcast live-schedule spin endpoints (`insertSpin`/`moveSpin`/`deleteSpin`), with the no-gap/auto-fill invariant and Q&A-group atomicity enforced in the scheduler when the affected spins are an AMA group. A thin AMA add-dispatcher (below) fronts adds so the client doesn't hand-craft raw spin calls.

### (c) New models

**None.** `amaConfig` is server constants; follower notifications reuse the existing `sentPushNotification*` infra + cooldowns; auto-fill is compute-only (no pending-fallback table).

### (d) New endpoints (curator-scoped, `checkUserPermissionToEditStation`)

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `/v1/stations/:stationId/ama-sessions` | Create + go-live. Body = ordered opening array of `{audioBlockId | songRequestId | listenerQuestionId}`. Server enforces `readyMS ≥ readyThresholdMS`, ensures the AMA Show, creates `Episode(kind='ama', status='live')` + Airing at the next boundary, materializes spins, notifies followers. Returns session + `amaConfig`. |
| GET | `/v1/stations/:stationId/ama-sessions/current` | One-stop runner poll: ordered items (resolved audio/song/Q&A), `readyMS`/`bufferedMS`, listener count, pending fallback pick, `amaConfig`. |
| POST | `/v1/stations/:stationId/ama-sessions/:sid/items` | Live add-dispatcher: `{audioBlockId | songRequestId | listenerQuestionId}` → one spin (song/voicetrack) or a tagged Q&A pair, appended via the spin primitives, respecting the 2-min lock + no-gap. |
| POST | `/v1/stations/:stationId/ama-sessions/:sid/finish` | Wrap: `status='wrapping'`, disable auto-fill, optional closing voicetrack; queue drains. |
| DELETE | `/v1/stations/:stationId/ama-sessions/:sid` | Cancel a session before its first AMA spin airs (delete the not-yet-aired AMA spins, resume rotation). |

Reorder/delete of live items reuse the existing `moveSpin`/`deleteSpin` endpoints (type-agnostic), with the AMA scheduler layer treating a Q&A `spinGroup` atomically and re-asserting the no-gap invariant.

**Server behaviors (not endpoints):** auto-fill tick (maintain `bufferedMS ≥ lowBufferThresholdMS`, prefer displaced programming); grace-period auto-wrap on curator disconnect (presence detection open, from S10); `live → ended` transition when the last AMA spin finishes (closes intake).

### `amaConfig` (proposed constants — server-owned)

`readyThresholdMS = 600000` (10:00 gate), `lowBufferThresholdMS` (~180000, H1 shows 3:00), `autoAddLeadMS` (~30000, H1 "in 0:30"), `answerMaxMS = 120000` (2:00), `introMaxMS = 600000` (10:00). Exact non-`readyThresholdMS` values to confirm; all live server-side so they change without an iOS release.

### Open contract questions (carried into adversarial review)

- **Indivisible Q&A pair under spin edits** — `moveSpin`/`deleteSpin` are single-spin; the AMA layer must treat a Q&A `spinGroup` (= LQAiring id) atomically.
- **Auto-fill vs. 2-min lock** — trigger threshold must exceed 2 min (≥3:00 per H1); confirm and define the race/idempotency story under the Redis lock.
- **`activeAma` query cost** — index on `Episode(kind, status)`; verify the station-list serializer stays cheap (no N+1).
- **Store-vs-derive** — `status` stored, `startedAt` derived, `endedAt` stored; confirm no third state ("waiting-to-air") needs storing.
- **Grace-period presence detection** (open since S10) — heartbeat vs. connection signal; grace duration; handling of queued/processing items on auto-wrap.
- **Follower-notification** eligibility/cooldown/dedup via existing push infra.
- **Fallback selection** — displaced-programming source + curator swap (S4); library fallback when no displaced item exists.
- **Q&A tag duplication** — `EpisodeSegment.listenerQuestionId` authoritative vs. minted `ListenerQuestionAiring`; confirm consistency story (decision #6).

### S37 approval

37. Revision S37 — User approved the data-layer shape: AMA session *is* an `Episode` (spin-authoritative live editing, reusing the existing live-schedule primitives); Q&A via `EpisodeSegment.listenerQuestionId` feeding clips/tapes/timeline; server-authoritative runway/`amaConfig`; wrap/drain end-show; compute-only auto-fill; and the create call carrying the ≥10-min opening array with server-enforced readiness. Zero new tables. Backend models/endpoints/authorization/migrations still require the opposite-provider adversarial review below before implementation-ready.

## Phase 5 — Opposite-provider adversarial review (Codex `gpt-6-astra`, read-only)

Codex reviewed the S37 contract against the real backend source. **Verdict: not implementation-ready as written.** Meta-finding: the S37 contract *overstates what the existing scheduler primitives guarantee.* The reusable pieces are the `Show → Episode → Airing → Spin` relationships, tagged standalone Q&A materialization, the `checkUserPermissionToEditStation` helper, the recorded-audio pipeline, and the timing utilities. The live mutation path must be a **new transactional AMA scheduling path built from those utilities**, not the existing public `insertSpin`/`moveSpin`/`deleteSpin`/`insertAirings` used unchanged. Findings + disposition below.

### ADOPTED into the contract (no further decision needed)

- **F1 — Atomicity/lock is not real today (Critical).** `createAiring` saves the Airing *before* scheduling; `insertAirings` and the three spin-edit fns create/delete/update spins with **no transaction and no scheduling lock**. Only `createSchedule` takes the Redis lock (and loads its snapshot *before* acquiring it); `updateStationSchedule` releases the lock before calling `insertAirings`. → **Contract change:** define ONE AMA mutation boundary that (acquire station scheduling lock → read fresh state → compute the complete change → validate → commit all session/airing/LQA/spin writes in a single DB transaction). Separate lock-owning entry points from internal helpers that assume a held lock/txn (avoid nested `createSchedule` lock re-acquire). Require durable request idempotency keyed by request/session ID; recovery is by that ID, not client connection state.
- **F2 — Existing routes bypass station-edit authz (Critical).** `Airing` routes (`src/api/airing/index.ts`) and `Episode` routes (`src/api/episode/index.ts`) require auth only — an authenticated user could mutate an AMA Airing/segment through them. `answerQuestion` authorizes on the URL station but looks the question up by `questionId` only (cross-station edit possible). Voicetrack registration (`src/api/station/index.ts:41`) lacks the station-edit middleware. (Broadcast spin controllers *do* check — that survey claim held.) → **Contract change:** close these bypasses as part of this feature; bind every referenced resource (session, Airing, question, anchor spins, audio) to the authorized station. A protected AMA dispatcher alone is insufficient.
- **F3 — `spinGroupId` cannot express both group levels (Critical).** One column can't be both `airing.id` (session) and `listenerQuestionAiring.id` (pair). Real behavior differs from S37: `deleteSpin` **rejects every spin with an `airingId`**; `moveSpin` already moves the whole `spinGroupId` group and rejects intra-group / mid-airing moves; `insertSpin` can insert *between* a Q&A question and answer and does not carry the LQA tag; appends don't inherit AMA membership; the insert API accepts neither `airingId` nor `listenerQuestionAiringId`. → **Contract change:** session membership = `airingId`; Q&A atomicity = `listenerQuestionAiringId`/pair group. Build **AMA-specific item operations over complete pairs + singletons** that reuse the timing calculations but NOT the public mutation fns unchanged. Lock/act on the *complete* pair, not its unfinished subset. Generic Broadcast edits must reject or dispatch AMA-affecting changes (including inserts between pair members).
- **F5 — The 2-min check does not freeze the final schedule (High).** `insertSpin` checks the anchor's end-of-message time, then `scheduleSpinAirtimes` subtracts overlap — a 2:10 anchor with 30s overlap yields a 1:40 insertion that still passed the check; insertion can also rewrite an already-locked anchor's fades. → **Contract change:** validate *final* airtimes + playback-affecting fields (fades/volume) immediately before commit; preserve the committed prefix and pair completeness; settle one equality/boundary convention (read filter includes equality; mutation checks currently allow it too).
- **F6 — Boundary takeover/preemption only partial (High).** `findStartTimeForShow` finds the spin before `desiredStart` and walks its group; it does **not** enforce the 2-min horizon or "current song," and a current group may be a whole regular show. `insertAirings` *deletes* displaced rotation (doesn't preserve it), treats standalone LQA spins as regular, reuses one stale snapshot across multiple airings, does not top up after insertion, and can no-op on an empty/out-of-window schedule. → **Contract change:** define takeover as the first permitted boundary at/after the commitment horizon; settle precedence vs regular shows / scheduled Q&As / other committed groups; creation must verify successful materialization + post-show coverage before returning success.
- **F7 — The shared rescheduler can destroy the live timeline (High, correctness bomb).** `calculateAiringRepositions` deletes and rebuilds an Airing's spins **from its `EpisodeSegment`s** when the first spin drifts earlier than nominal airtime — but AMA segments hold only the *opening* playlist, so this discards live additions, resurrects deleted opening items, changes spin IDs, and drops question-only segments. `deleteAiringFromSchedule` deletes **all station spins from the airing start onward** then regenerates — unsuitable for cancel. → **Contract change:** explicitly EXCLUDE `kind='ama'` airings from template-based reconstruction and generic destructive rescheduling; preserve committed AMA spins + their IDs; opening segments are *provenance*, not a rebuild recipe.
- **F8 — The three-way persisted XOR contradicts existing data (High).** The current XOR is an *input* rule, not a row invariant: `getEpisodeById` and song-request sync legitimately set `audioBlockId` while retaining `songRequestId`, so rows with both are valid. Materialization skips null `audioBlockId` but later dereferences the final segment's `audioBlock` (a trailing unresolved request fails *after* earlier spins were created). → **Contract change:** do NOT add a literal 3-column DB XOR constraint. Keep it a lib input rule. At AMA create/add, **resolve every request to playable audio or reject**; expand Q&As before computing subsequent offsets; an estimated request duration is not secured buffer.
- **F9 — "LQAiring is purely a tag" is false (High).** `ListenerQuestionAiring.hasMany(Spin)` is real AND an LQAiring is an *executable* scheduling record: `insertAirings` re-materializes it whenever no tagged spins exist — so deleting both pair spins but keeping the LQAiring can recreate the pair, and leaving one spin makes it look materialized. Timeline reads use `LQAiring.airtime` (moving spins leaves the displayed start stale); tape rendering keys the answer off the question's *current* `answerAudioBlockId` (re-answering breaks old tapes). Live-added Q&As have no `EpisodeSegment` (contradicts "segment is always authoritative"). → **Contract change:** define LQA scheduling ownership — either delete unplayed derived LQAs *with* their pairs or persist enough state to exclude them from standalone scheduling; sync `LQAiring.airtime` on move; keep historical pair/answer identity stable across re-answer.
- **F11 — Readiness isn't server-authoritative yet (High).** `createVoicetrack` trusts the supplied `durationMS` (verifies S3 existence only). Three different timing calcs exist (`durationMS − overlap` for opening segments; `endOfMessageMS − overlap` for live spins; a third for Episode duration) — summing nominal file durations can pass the 10-min gate without 10 min of *contiguous* broadcast. → **Contract change:** one coverage calculation over resolved/validated media + final scheduled timing; measure *contiguous* coverage; reject gaps, bad timing markers, missing audio, unresolved requests, incomplete Q&As; enforce recording limits against trusted metadata.
- **F13 — Column justification (Medium).** `Episode.kind` keep; `Episode.status` keep (with explicit transitions + regular/AMA consistency checks — `wrapping` intent is genuinely non-derivable); `Episode.endedAt` **keep only for the cancel/terminal-reconciliation case** (a never-aired cancel has no last-spin end to derive from) — in the aired case it equals the preserved final spin end and is otherwise derivable; `EpisodeSegment.listenerQuestionId` keep but it does NOT own live-added pairs; no stored "waiting-to-air" state, no stored start time (derive from *all* session spins).
- **F14 — `activeAma` needs batching + uniqueness (Medium).** Per-station serializer query = N+1 across station lists. `Episode(kind,status)` doesn't scope to a station (Episode has `showId`, not `stationId`). → **Contract change:** batch-fetch active-AMA candidates by collected station IDs via Show/Airing; batch-aggregate spin bounds; partial index on `episodes(showId)` for active states. Enforce **one active AMA per station** (partial unique index only works with one canonical AMA Show per station). "On air now" ≠ `status='live'` — a *waiting* session must NOT get the AMA-now badge; badge keys off `now ≥ firstAmaSpinAirtime`.
- **F15b / F16 — Notification + missing endpoints (Medium).** `sendStationNotification` publishes-then-logs (swallows log failure), no idempotency/cooldown in that path — sent-history is not an outbox. → define eligibility, actual-airtime vs create-time delivery, cancellation behavior, durable dedup. **Missing from contract, now added:** a **GET amaConfig before create** (client needs the 10-min gate value to render readiness); recovery/history lookup by session ID after ambiguous create (ended/cancelled outcomes); a definition of "show intake closed" that doesn't block ordinary station questions; `defer` must also skip the scheduled-airing *notification* and define re-answer/existing-future-airing behavior; migration ordering (fields before code; backfill existing episodes as `regular`/null — never `live`; readers/workers deployed before writers; no persisted XOR; enum rollback + FK-delete behavior; add associations/types/indexes/uniqueness).

### DECISIONS REQUIRED (surfaced to user after S37) — see S38

- **D1 — Model: Episode-with-exceptions vs. dedicated AMA session model (F1/F12).** Codex: Episode reuse "works structurally" but collides in several places — Episode has `showId` not `stationId`, can have multiple Airings across stations, `durationMS` describes segments not the edited live show, airing listener-analytics use nominal airtime + Episode duration, schedule serialization maxes actual-spin-end with nominal Episode-end (deleted opening content keeps the reported end artificially late), live-station detection infers the window from opening segments. A dedicated session model would simplify station ownership / lifecycle / presence / active-session uniqueness — but would NOT fix the scheduler-transaction or pair-edit work (those are required either way). "Zero tables" is not itself a simplicity argument.
- **D2 — Fallback semantics (F15a).** `insertAirings` *deletes* displaced rotation, so a later compute-only tick cannot resurrect "displaced programming" unless it was preserved somewhere. Options: (a) fallback = surviving post-AMA rotation / station library only (simplest; displaced music returns naturally at wrap); (b) preserve the displaced queue durably so auto-fill can prefer it (matches the approved "prefer displaced programming" wording but needs storage). Empty-library behavior + deterministic selection (so a restart doesn't re-roll a random pick, and an approved curator "swap" survives) must be defined.
- **D3 — No-gap failure path (F4).** An unconditional "never dead air" cannot rest on a fallible tick: the Redis lock is 300s with no fencing/renewal, the existing worker runs every 15 min, and at 3:00 remaining a ~61s delay pushes the AMA tail inside the 2-min horizon (append becomes illegal; inserting after a later regular song causes a *premature return to rotation*). Need a guaranteed emergency-coverage path when the deadline can't be met — likely a graceful early return-to-rotation (product-visible) rather than a hard guarantee. Also: one fallback song may not restore the threshold after a large delete — must add enough coverage atomically or reject the edit. Requires an explicit deadline budget: `trigger buffer > 120s + detection delay + contention/retry + compute/commit + overlap + safety margin`.
- **D4 — Compound Q&A + following song atomic add (F16).** The approved product action pairs a Q&A answer with an optional song after it; a single-item `/items` endpoint can't guarantee adjacency or all-or-nothing. → the live add-dispatcher must accept an **ordered multi-item atomic batch**. (Leaning adopt; confirming product intent.)
- **D5 — Finish/cancel/wrapping state contract (F10).** Cancel "before first airtime" falls *inside* the locked horizon (deliberate exception, or restrict to editable window?). Are add/reorder/delete legal during `wrapping`? How do concurrent finish/refill/add serialize? Outro still uploading — exclude, await, or reject? DELETE-on-retry-after-success return? A live session with zero remaining spins — ended, or refill failure? Presence needs a defined server-observed heartbeat/lease (polling + mobile connection state are not adequate). Needs a full transition table + idempotency + stale-revision conflict behavior.

## S38 — Authoritative contract (post-review decisions)

**This section supersedes the S37 model/endpoint specifics above** (which assumed Episode reuse + the existing public spin mutators). S37 and the Phase 5 findings remain as the reasoning trail. User resolved D1–D5 on 2026-09-13.

### Decisions

- **D1 = Dedicated model.** A new `AmaSession` model owns the session (station, lifecycle, uniqueness) instead of reusing `Episode`. This *dissolves* rather than patches three findings: no `Episode`/`EpisodeSegment` changes at all (F8's persisted-XOR problem disappears — no three-way segment column); AMA spins are not `Episode`-backed, so they sit structurally outside the generic template-reconstruction/destructive-reschedule machinery (F7); and session membership gets its own tag instead of overloading `spinGroupId`/`airingId` (F3).
- **D2 = (a) Library/surviving-rotation fallback.** Auto-fill does NOT try to resurrect the rotation `insertAirings` deleted. Fallback songs come from the station library / surviving rotation, chosen **deterministically and durably** so a restart doesn't re-roll the pick and an approved curator swap survives. Displaced music returns naturally when the show wraps.
- **D3 = Graceful early return-to-rotation** is the honest failure path when the no-gap deadline can't be met. No unconditional "never dead air" guarantee resting on a fallible tick.
- **D4 = Atomic group add.** The live add endpoint accepts an **ordered group committed all-or-nothing** (a Q&A = question+answer pair lands together; nothing wedges between them; covers a future "answer + song" set).
- **D5a = Freeze on wrap.** Once `finish` is called, the draining queue is frozen — no add/reorder/delete during `wrapping`.
- **D5b = No cancel.** The session is not created server-side until takeover is imminent, so *create is the commit*. There is no cancelable waiting-to-air state and **no DELETE endpoint**. (Consequently `endedAt` is always derivable from the final spin — the never-aired-cancel case that motivated storing it is gone.)
- **D5c = Auto-fill count is the presence signal.** No heartbeat, no connection state. **N consecutive auto-filled songs with no new curator content → the session auto-wraps** (same graceful path as D3). Necessary for termination: without it, a vanished curator yields an endless AMA of fallback songs.

### Model (dedicated)

- **NEW `AmaSession`** — 1 table.
  - `id`, `stationId` FK → `stations.id`.
  - `status ENUM('live','wrapping','ended')`.
  - **No stored `startedAt`/`endedAt`** (S38 refinement, 2026-09-13). Both derive from the session's spins: start = `min(spin.airtime)`, end = `max(spin end)`. The first spin's airtime is computed + written at create (D5b: create only when takeover is imminent, so the boundary is already locked), never moves (edits/auto-fill append after the head), and is immutable once aired — so a stored column could only go stale. F7-exclusion means AMA spins are never reconstructed, so there is nothing to protect. "On air now" = `now ≥ min(spin.airtime) AND status IN ('live','wrapping')`.
  - A way to track **consecutive auto-fills since last curator activity** for D5c (stored counter reset on curator edit, or derived from trailing spins — mechanism chosen in the plan).
  - **One active AMA per station** enforced by a partial unique index on `(stationId)` where `status IN ('live','wrapping')`.
- **NEW column `Spin.amaSessionId UUID NULL`** FK → `amaSessions.id` — session-membership tag. This is the second grouping level F3 said `spinGroupId` couldn't provide: **session membership = `amaSessionId`; Q&A pair atomicity = the existing `listenerQuestionAiringId`.** The generic scheduler must (1) protect `amaSessionId`-tagged spins from reflow/deletion by other airings and (2) never template-reconstruct them.
- **NO changes to `Episode` / `EpisodeSegment`** (dedicated model replaces that path entirely).
- **`ListenerQuestion`**: no columns. Answer endpoint gains `defer` (skip the auto ~2-day `ListenerQuestionAiring` **and** its scheduled-airing notification).
- **`Station`**: no column; **computed, batched** `activeAma` in the station + station-list serializers, sourced from `AmaSession(status IN ('live','wrapping'))` with spin bounds batch-aggregated (no N+1). "On air now" badge keys off `now ≥ startedAt`, not merely `status='live'` (a waiting session is not yet on air).

### Endpoints (curator-scoped via `checkUserPermissionToEditStation`)

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/v1/stations/:stationId/ama-config` (or folded into an existing config read) | `amaConfig` so the client can render the 10-min readiness gate *before* create. |
| POST | `/v1/stations/:stationId/ama-sessions` | Create = go-live. Body = ordered opening group. Server resolves every song-request to playable audio, enforces **contiguous** ready ≥ `readyThresholdMS`, creates `AmaSession(status='live')`, materializes tagged spins at the next boundary, notifies followers. No cancel. |
| GET | `/v1/stations/:stationId/ama-sessions/current` | Runner poll: resolved ordered items, `readyMS`/`bufferedMS`, listener count, next fallback pick, `amaConfig`. Also serves recovery/history lookup by session id after an ambiguous create. |
| POST | `/v1/stations/:stationId/ama-sessions/:sid/items` | Live add — **ordered atomic group** (D4). Song/voicetrack = 1 spin; Q&A = tagged pair. |
| POST | `/v1/stations/:stationId/ama-sessions/:sid/reorder` and item DELETE | Live reorder/delete via **AMA-specific pair-aware operations** (reuse timing math, not the public `move`/`deleteSpin`). Illegal during `wrapping` (D5a). |
| POST | `/v1/stations/:stationId/ama-sessions/:sid/finish` | Wrap: `status='wrapping'`, disable auto-fill, freeze the queue, optional closing voicetrack; queue drains → `ended`; intake closes. |

### Server behaviors (not endpoints)

- **One transactional AMA mutation path** (F1): acquire station scheduling lock → read fresh state → compute complete change → validate final airtimes/fades → commit all writes in one DB transaction; idempotency keyed by request/session id; lock-owning entry points separated from internal helpers.
- **No-gap auto-fill** maintaining *contiguous* buffer ≥ `lowBufferThresholdMS`, fallback per D2, with an explicit deadline budget (`trigger > 120s + detection + contention/retry + compute/commit + overlap + safety`) so it inserts before the 2-min lock closes; add enough coverage to restore the threshold after a large delete, or reject the edit.
- **Presence auto-wrap** (D5c): N consecutive auto-fills with no curator activity → `wrapping`.
- **Graceful early return-to-rotation** (D3) when the deadline can't be met.
- **Close the F2 authz bypasses** touched by AMA (voicetrack registration at minimum; Airing/Episode generic mutators guarded or rejected for AMA-affecting changes). **Includes a delete guard** (2026-09-13, agreed): the generic `ListenerQuestionAiring` delete currently nulls its spins' pair id — AMA must block that delete for AMA-owned pairs to preserve Q&A pair atomicity.
- **`live → ended`** when the last AMA spin finishes.

### Deferred to the Phase 6 Codex-architected implementation plan

Exact transaction/lock boundary + idempotency-key design; the scheduler integration surface for protecting `amaSessionId` spins (reflow protection + reconstruction exclusion); deadline-budget numbers, auto-fill cadence, and Redis lease-loss handling; deterministic fallback selection + empty-library behavior + curator-swap durability; follower-notification eligibility/dedup; migration ordering (add `AmaSession` + nullable `Spin.amaSessionId`; deploy AMA-aware readers/workers before writers; backfill nothing); presence-counter mechanism (stored vs derived); exact `amaConfig` values.

### S38 approval

38. Revision S38 — User resolved D1–D5: **dedicated `AmaSession` model** (+ nullable `Spin.amaSessionId` tag) instead of `Episode` reuse; **library/surviving-rotation fallback** (deterministic, durable); **graceful early return-to-rotation** as the no-gap failure path; **atomic ordered-group add**; **queue frozen on wrap**; **no cancel** (create is the commit); **auto-fill-count presence** (N consecutive fills → auto-wrap). All Phase 5 findings dispositioned (adopted or dissolved by the dedicated model). Ready for the Phase 6 implementation plan, which is architected through Codex.

## S39 — Pivot to the generic `live-shows` primitive (authoritative model)

**This section supersedes the S37/S38 data layer.** After the Phase 6 plan was drafted against S38, the product owner rejected the heavy design outright: *"The live show follows the exact same scheduling rules as the regular scheduler, so we gain nothing by separating it into its own subsystem."* The feature is renamed from "AMA Show Runner" to a generic **live show** primitive — `ask-me-anything` is the first `type`; later types (e.g. `song-requests`) reuse it without the Q&A layer. The full backend needs list lives in `implementation-plan.md` (rewritten S39); this is the contract summary. Validated by a read-only Codex (`gpt-6-astra`) architecture consult against the real backend.

### What changed from S38, and why it's safe

| S38 (dropped) | S39 (kept) | Why safe |
| --- | --- | --- |
| Dedicated `AmaSession` subsystem | Slim `liveShows` identity row; live content is ordinary editable spins tagged `liveShowId` | The scheduler already treats spins as the live timeline; a session is just an identity + membership tag. |
| 15s continuous-autofill worker + fallback deck + presence counter | 3 trailing "filler" spins + the station's own rotation | `insertSpin` **shifts** rotation later (`scheduler.ts:1332`) instead of deleting it, so when fillers finish the already-scheduled rotation plays immediately — no worker, no gap. Indefinite continuation + continuous repair are genuinely lost; that matches the product (a show expires after its content). |
| Shared `withStationScheduleMutation` boundary | Reuse the **existing** station Redis lock for the few concurrent writers + one txn per edit | With no live worker there's no second writer to invent a boundary for; the real writers (top-up, episode/LQ insert, giveaway congrats, airing edit) just need the existing lock, taken with the read moved inside it. |
| Measured-duration readiness (`measuredDurationMS`) | Client-supplied duration, as the existing editor already accepts | Fillers/rotation absorb a wrong duration. Residual risk only for freshly-recorded Q&A answers; accepted for v1. |
| `status` enum / `wrapping` / revision concurrency / receipts | Liveness + start/end **derived** from member spins + `endingSpinId` | Single sequential writer under the lock; no state machine needed. |

### Model (slim)

- **NEW `liveShows`** — 1 table: `id`, `stationId` FK, `curatorId` FK (who started it), `type` ENUM (first value `ask-me-anything`), `endingSpinId` UUID NULL FK → spins, `createdAt`/`updatedAt`. **No status/start/end/revision/count columns** — all derived. `endingSpinId` makes `end` idempotent and distinguishes "ended normally" (set) from "abandoned" (unset + last member spin in the past). **No `canceledAt`** (user: no future use). One live show per station at a time, enforced in application logic inside the station lock (no status column to index).
- **NEW `spins.liveShowId`** UUID NULL FK → `liveShows`, default null — membership tag, `ON DELETE RESTRICT`.
- **NEW `spins.isFiller`** boolean default false — marks just-in-time filler spins for tail maintenance + removal at `end`.
- **NO changes to `Episode`/`EpisodeSegment`/`Show`.** Live content is plain spins, never Episode-backed and never one show-wide `spinGroupId` (that would trip airing-delete/group-move rules). The only `spinGroupId` in a live show is a Q&A question→answer pair.
- **`ListenerQuestion`**: no columns. Answer endpoint gains a deferred mode during a live show (record + link answer, skip the auto ~2-day `ListenerQuestionAiring` and its listener notification; insert the pair into the live queue via the editor). Existing auto-airing path stays untouched but bypassed during a live show.
- **`Station`**: no column; liveness is **computed and batched** into the station + station-list serializers — a station is live iff it has a member spin (content, filler, or ending) with `airtime <= now AND endOfMessageTime > now`. One batched query over collected station ids; live stations stable-sorted first.

### Endpoints (curator-scoped via `checkUserPermissionToEditStation`)

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `/v1/stations/:stationId/liveShow` | Go-live. Body `{ type, audioBlockIds: [~10] }`. Under the station lock, one txn: find next safe boundary (song boundary ≥ the existing 2-min horizon, not colliding with a scheduled airing), **create the `liveShows` row first** (`endingSpinId = NULL`, so the `spins.liveShowId` FK resolves — no deferred FK needed), then batch-insert the explicit spins + **3 trailing fillers** tagged with that `liveShowId`; enqueue the go-live push **after commit**. Returns `liveShowId` + derived `scheduledStartsAt`/`scheduledEndsAt`. |
| POST | `/v1/stations/:stationId/liveShow/:liveShowId/end` | Body `{ audioBlockId }`. Under the lock, one txn: append the ending spin after the last live/filler spin, set `endingSpinId`, remove still-removable (future, outside the horizon) fillers. Idempotent via `endingSpinId`; `:liveShowId` prevents ending a later show. |

Live editing (add/reorder/delete, answer Q&A) reuses the **existing** spin/airing endpoints — the spins already carry `liveShowId`; those endpoints gain filler-tail maintenance and (for `ask-me-anything`) the deferred-answer behavior.

### Four scheduler changes (the only places "same rules as the regular scheduler" is false in the real code)

1. **Commitment horizon** — inherited free: live edits call the same `deleteSpin`/`moveSpin`/insert functions that already reject edits inside the 2-minute window (`SPIN_TOO_SOON_TO_DELETE` `scheduler.ts:889`, `SPIN_TOO_SOON_TO_MOVE` `:1059`, `SPIN_TARGET_TOO_SOON` `:1125`). **No new constant.** (The general-editor check is *leaky* — insert validates un-overlapped airtime before overlap subtraction, rewrites already-started anchor fades, and airing update/delete bypass it entirely; that's a pre-existing condition affecting all edits, left **out of scope**.)
2. **Preemption protection** — check `liveShowId` wherever the scheduler treats a spin as disposable by `airingId` (episode insertion `:446`, LQ insertion `:627`, airing suffix-delete `:742`), so live spins are protected like airing spins; start/extend respects scheduled airings as hard boundaries.
3. **Plain editable spins** with `liveShowId` membership; `spinGroupId` only for Q&A pairs (never a whole-show group).
4. **Deferred Q&A answer** during a live show — insert directly into the live queue, no random airtime / auto-airing / listener notification; existing auto-airing path stays but is bypassed (slated for removal later).

### Server behaviors (not endpoints)

- **Concurrency:** reuse the existing (non-reentrant) station Redis lock around the participating writers (top-up, episode/LQ insert, giveaway congrats insertSpin, airing edit/delete) with the state read moved inside the lock; one transaction per edit + its filler repair. No new boundary subsystem.
- **Filler tail:** re-ensure 3 replaceable *future* fillers after the live content on each edit. Curator keeps up → show continues; curator falls behind/disappears → up to 3 fillers air, then the shifted rotation resumes and the show is over (no `endingSpinId`).
- **Go-live push:** one durable BullMQ job per `liveShowId` on the existing queue, re-validated at fire time (rescheduled → defer; canceled/past → suppress; live → send + dedup). No generic scheduled-push exists today; follows the giveaway-worker pattern.

### Genuinely lost vs. S38 (accepted)

Indefinite show continuation; continuous live-repair; a measured-duration guarantee (residual risk only for freshly-recorded Q&A answers inside the live sequence). All acceptable for v1 and consistent with the product intent.

### S39 approval

39. Revision S39 — User rejected the S38 heavy design and approved the generic **live-shows** primitive: slim `liveShows` identity row + `spins.liveShowId`/`isFiller`; two endpoints (`liveShow` create, `liveShow/:id/end`); live edits reuse the existing schedule editor unchanged; the 2-min horizon is inherited (no new constant); 3 filler spins + insertion-shift give graceful fallback to rotation with no worker; deferred Q&A answers during a show; liveness derived + batched; one durable go-live push. Four small scheduler guards are the only real deltas. Estimated ~2 PRs. Feature/dir renamed `ama-show-runner` → `live-shows`; the S1–S36 visual-design log remains valid. `implementation-plan.md` rewritten to match. Ready for the design PR to `develop`.
