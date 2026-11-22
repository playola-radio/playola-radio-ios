# 002-manage-series — Implementation plan

The design files beside this plan are the truth; this plan only says how to build them.

Build 002 as two PRs into feature/recorded-shows, after design 001's PR (Series picker and the New Series sheet) and PR #493 (the Schedule sheet) have merged there. Almost everything it calls already exists in the app: getCuratorSeries, getCuratorEpisodes (by station or by Series, always with airings), createSeries, updateSeries (outer nil keeps the schedule, .some(nil) clears it), getAirings, scheduleEpisode, moveAiring, updateEpisode with CuratorEpisodeUpdate(series: .join), getStationSchedulingSettings, SeriesSchedule (reading, writing, words and openSlots with DST handling), CuratorEpisode's state(now:lockMS:) and upcomingAiring(now:), ShowBuilderPageModel(stationId:episodeId:seriesId:slot:) with lazy creation, and the recordedShowsChanged notification. The only new client call is GET /v1/shows/:showId, which the server already serves. No new models, dependencies or server changes. Two PRs because the Add a show sheet is a separate, harder piece (two-step saves, the Schedule sheet hand-off, alerts after dismissal); PR 1's "+ Add show" and "Add a Show" buttons are drawn but do nothing until PR 2, which is acceptable only because feature/recorded-shows does not merge to develop until both are in.

| PR | Title | Depends on | Hard |
|---|---|---|---|
| 1 | feature: let curators see each series' upcoming shows and open time slots, and create or edit a series | — | no |
| 2 | feature: let curators fill a series' open time slot with a new or existing show | 1 | yes |

## PR 1 — feature: let curators see each series' upcoming shows and open time slots, and create or edit a series

Upcoming's "Series" row opens a list of the station's Series, each card showing its next shows and open weekly slots. A card opens the Series page with its drafts, upcoming Shows and next open slots. A curator can create a Series from the list and edit a Series' name and schedule from its page.

**Changes**

- APIClient: add getCuratorSeriesById(jwt, showId) -> CuratorSeries for GET /v1/shows/:showId in APIClient.swift and APIClient+Live.swift, decoding the same CuratorSeries as getCuratorSeries, with the unimplemented test default every other client method has.
- Move ShowBuilderPageModel's private airing-to-interval mapping into one shared helper beside SeriesSchedule: occupiedIntervals(from airings: [Airing], excludingEpisodeId: String? = nil) -> [DateInterval]. It drops the excluded episode's airings first, then maps each remaining airing to startTime ?? airtime through endTime ?? airtime + durationMS, never negative. The builder, the Series list and the Series page all use it, and the builder's behaviour does not change. The list and the page keep the loaded [Airing] (not just intervals) so PR 2 can exclude a Show's own airings.
- Add PlayolaRadio/Views/Pages/CuratorSeriesListPage/ with CuratorSeriesListPageModel.swift, CuratorSeriesListPageView.swift and CuratorSeriesListPageTests.swift (named apart from the listener app's existing SeriesListPage). Add a curatorSeriesListPage case to MainContainerNavigationCoordinator.Path, and make UpcomingShowsPageModel.seriesRowTapped() push it with the station id.
- List load: on viewAppeared and on every recordedShowsChanged for this station (the pattern UpcomingShowsPageModel uses), load in parallel getCuratorSeries, getCuratorEpisodes(stationId), getAirings(stationId) and getStationSchedulingSettings. Show the standard progress view on the first load. On failure, skip cancellations, report other errors the way Upcoming does, show a toast and keep what was shown.
- List content: drop isOneTime Series and keep the server's order. For each card, the Series' upcoming Shows are its episodes whose upcomingAiring(now:) is non-nil, each placed once at that airing, so a Show that airs more than once appears once at its next airing and aired Shows never appear. Open slots come from SeriesSchedule(rrule:)?.openSlots(after: now, in: settings.timeZone, occupiedIntervals: every station airing via the shared helper, limit: 3). Merge Shows and slots by date and take the first 3; the count describes those 3 ("1 show", "2 shows · 1 open", "3 open", with singular and plural and zero parts dropped). With nothing to show, the card shows "No upcoming shows." and no count. The badge reads SeriesSchedule text, "Custom schedule" when the rule can't be read, and is absent for a nil rule. Card texts: a Show "Sunday the 8th at 7pm" with a calendar tile; a slot "Sunday the 22nd · open" with a grey tile and "+ Add show". All dates and times are formatted in settings.timeZone, not the phone's.
- List actions: a card's name pushes the Series page; a Show pushes ShowBuilderPageModel(stationId:, episodeId: show.id, seriesId: nil, slot: nil); "Create a New Series" presents design 001's Series details sheet in New Series mode through a new top-level seriesDetails PlayolaSheet case. It passes the list's loaded StationSchedulingSettings, or nil when none have loaded (for example after a failed first load), in which case 001's America/Chicago fallback applies; it never waits on a load, so it opens at once on every tap, and its successful save (which posts recordedShowsChanged) makes the list reload. "+ Add show" calls an empty addShowTapped(slot:) that PR 2 fills in.
- Add PlayolaRadio/Views/Pages/CuratorSeriesPage/ with CuratorSeriesPageModel.swift, CuratorSeriesPageView.swift and CuratorSeriesPageTests.swift, and a curatorSeriesPage case in the navigation Path. The model is created from the list with the tapped CuratorSeries so its title shows at once.
- Page load: on viewAppeared and on recordedShowsChanged for this station, load in parallel getCuratorSeriesById, getCuratorEpisodes(showId:), getAirings(stationId) and getStationSchedulingSettings, with the same progress, toast and keep-what-was-shown handling.
- Page content: the schedule badge as on the card; the slots note only when the Series has a readable weekly schedule. NOT SCHEDULED YET lists every one of the Series' drafts in server order ("Not scheduled yet · 20 min", pencil tile; a draft with no audio yet reads just "Not scheduled yet", using lengthLabel's nil), or "No drafts in this series." UPCOMING merges the upcoming Shows (at their next airing, "Sunday · 7:00 PM · 38 min") with the next 8 open slots ("Open", "Sunday · 7:00 PM", "+ Add show") by date, or shows "No upcoming shows." when both are empty. "Edit" presents the Series details sheet in Edit mode with the page's current Series (the tapped one until a load replaces it) and its loaded settings, or nil with 001's America/Chicago fallback, so it opens at once even after a failed first load. A Show in either section pushes its builder. "+ Add show" and "Add a Show" call empty actions that PR 2 fills in.
- Edit mode for design 001's SeriesDetailsSheetModel: it opens with the Series' name and, from SeriesSchedule(rrule:), Every week, its days and time (in the station time zone passed by the page). A nil rule opens on No schedule with no days and 7:00 PM. An unreadable rule opens in Custom schedule mode, which shows the name field and a read-only "Custom schedule" row and no note. The title is "Edit Series" and the note reads "Changing the schedule only changes your open slots. Shows that are already scheduled keep their times." Save follows 001's validation rules (a trimmed name, and at least one day for Every week). It calls updateSeries with the trimmed name and rrule .some(rule) for Every week, .some(nil) for No schedule, and nil (left alone) in Custom schedule mode. Saving uses 001's New Series saving behaviour: Save becomes a disabled progress view, and Cancel, swipe and edits are blocked until it finishes. On failure an alert inside the sheet shows the server's message and the input is kept. On success, post recordedShowsChanged and close, so the page reloads with the new name, schedule and slots.
- Every new model is an @MainActor @Observable ViewModel holding all of its text and actions; views only render and have no control flow. Register every new file in PlayolaRadio.xcodeproj/project.pbxproj (app and test targets, with explicit file references). Add changelog.d/manage-series.md with a plain-English Changes bullet. Add qa/ux/manage-series-pages as a visual case covering the list (default, a card with nothing upcoming, empty), the page (default, empty sections) and both Edit Series states, and run make ux-evidence for it.

**Tests**

- UpcomingShowsPageTests: seriesRowTapped pushes the curator Series list for the station.
- CuratorSeriesListPageTests: one-time wrappers are hidden and the server order is kept; a station with no Series shows no cards; a card merges Shows and slots by date and keeps the first 3; the count reads "1 show", "2 shows · 1 open" and "3 open"; a Series with nothing upcoming shows "No upcoming shows." and no count; a slot overlapping any station airing (including another Series' Show) is not open; a Show with two future airings appears once, at the earlier one; aired Shows and drafts are not on cards; there is no badge or slot for a nil rule, and "Custom schedule" with no slots for an unreadable one.
- CuratorSeriesListPageTests with time: with the test's time zone set away from Central, card texts and slots are in Central time. A Sunday 7pm Series lists the correct instants across the November fall-back and the March spring-forward weeks.
- CuratorSeriesListPageTests for loading: a gated load shows the progress view; a failure shows a toast and keeps the previous cards; a cancelled load shows no toast; recordedShowsChanged for this station reloads it, while one for another station does not.
- CuratorSeriesListPageTests for actions: a card's name pushes the Series page with that Series; a Show pushes its builder; "Create a New Series" presents the details sheet in New Series mode, including after a failed first load (no settings, Central time).
- CuratorSeriesPageTests: drafts in NOT SCHEDULED YET with their subtitle, and a draft with durationMS 0 and no airings listed there as "Not scheduled yet"; UPCOMING merges Shows and the next 8 open slots by date; both empty-section messages, including a weekly Series whose every matching time in the next 52 weeks is taken by another Series' airings (no slots, "No upcoming shows."); the slots note only for a readable weekly schedule; "Edit" presents Edit mode with the Series, including after a failed first load (the tapped Series, no settings, Central time); loading, failure and recordedShowsChanged behave as on the list; it is built from getCuratorSeriesById and getCuratorEpisodes(showId:).
- SeriesDetailsSheetTests for Edit mode:
- - opening fills in Every week Tuesday and Thursday 8:00 PM, No schedule, or Custom schedule, depending on the rule;
- - Save is disabled for an empty name and for Every week with no day;
- - the request sends .some(rule), .some(nil), or nil for Custom schedule, with a trimmed title;
- - Save stays busy until updateSeries returns, and a second tap is ignored;
- - a failure keeps the sheet and its input and shows the server's message;
- - success posts recordedShowsChanged and closes;
- - Cancel sends nothing.
- APIClientRecordedShowsTests: getCuratorSeriesById requests GET /v1/shows/:showId and decodes a Series.
- Every new suite uses @Suite(.freshSharedState) and @MainActor, withDependencies for the API, date and time zone, expectNoDifference/expectDifference for values, and async gates instead of sleeps. Run the full ShowBuilderPageTests and ShowBuilderPageSchedulingTests (the shared interval helper), UpcomingShowsPageTests, SeriesDetailsSheetTests, SeriesScheduleTests, APIClientRecordedShowsTests and the new suites with xcodebuild, plus make lint and make changelog-check.

**Screenshots it must match**

- `screenshots/series-list--default.png`
- `screenshots/series-list--card-with-nothing-upcoming.png`
- `screenshots/series-list--empty.png`
- `screenshots/series-page--default.png`
- `screenshots/series-page--empty-sections.png`
- `screenshots/series-details-sheet--edit-series.png`
- `screenshots/series-details-sheet--custom-schedule.png`

**"Done when" items it delivers**

- 1. Upcoming → "Series" opens the Series list, matching its mockup. With no Series it shows only "Create a New Series".
- 2. Each card shows its next 3 items (scheduled Shows and open slots in date order) and a count that matches them ("1 show", "2 shows · 1 open", "3 open"); a card with nothing upcoming shows "No upcoming shows." and no count. A slot already taken by any Show on the station is never shown as open.
- 3. A Show that airs more than once is listed once, at its next airing, on its card and its Series page.
- 4. A Series with no schedule shows no badge, no slots and no slots note. An unreadable schedule shows "Custom schedule" and no slots.
- 5. Open slots and times are correct in Central time regardless of the phone's time zone, including across both daylight-saving changes.
- 6. A card's name opens the Series page, matching its mockup: drafts under NOT SCHEDULED YET; scheduled Shows plus the next 8 open slots (looking up to 52 weeks ahead) under UPCOMING, in date order.
- 7. An empty section keeps its heading and shows its message ("No drafts in this series." / "No upcoming shows.") in place of rows.
- 8. Creating a Series from the list adds its card. Editing a Series' name or schedule updates the page and its open slots, and leaves already-scheduled Shows' times alone.
- 9. Edit Series' Save is disabled while the name is empty, or while "Every week" has no day. A "Custom schedule" Series can be renamed without changing its schedule.
- 10. While Edit Series saves, Save is a disabled progress view; if saving fails, an alert shows the server's message and the sheet stays open with its input.

## PR 2 — feature: let curators fill a series' open time slot with a new or existing show

From any open slot, or from the Series page's "Add a Show" button, a curator can record a new Show for the Series or move one of their existing Shows into it. A slot less than 6 hours away goes through the Schedule sheet so the curator sees that the Show locks right away.

**Changes**

- Add PlayolaRadio/Views/Pages/AddShowToSeriesSheet/ with AddShowToSeriesSheetModel.swift, AddShowToSeriesSheetView.swift and AddShowToSeriesSheetTests.swift, plus an addShowToSeries PlayolaSheet case rendered in MainContainer's standard sheet branch. The presenter (list or page) passes the station id, the Series, the slot (or nil), its loaded StationSchedulingSettings, its loaded station [Airing], and an onAddFinished closure. Fill in PR 1's "+ Add show" (with the slot) and the page's "Add a Show" (no slot) to present it. A slot only exists once settings and airings have loaded, so "+ Add show" always has them. The page's "Add a Show" can be tapped after a failed first load: if the page has no settings or airings yet, it first loads them (getStationSchedulingSettings and getAirings in parallel), keeping them for the page; on failure it skips cancellations, reports, shows the page's load-failure toast and does not present the sheet; on success it presents the sheet. A second tap while that load runs is ignored.
- Sheet text: "Add a show"; the subtitle is "<Series> · Sunday, Nov 22 at 7pm" from a slot, or just the Series name; "Record a New Show" with "Start from scratch for this slot" from a slot. The list heading "OR ADD ONE OF YOUR SHOWS" is shown only when the list has rows.
- Sheet load: on appear call getCuratorEpisodes(stationId). Title, subtitle and "Record a New Show" show at once, with a progress view where the list goes. On failure, skip cancellations, report and toast, and show the nothing-to-offer look.
- Eligibility: a Show is offered when its showId is not this Series, isMultiAiring is false, and either state(now:lockMS: settings.airingEditLockMS) is .draft with hasAudio, or it is .scheduled. Drafts come first in server order, then scheduled Shows by air time. Subtitles: "Not scheduled yet · 18 min"; from a slot, "Moves here from Sun, Nov 8 · 42 min"; with no slot, "Sun, Nov 8 · 42 min". Formatting uses the station time zone and lengthLabel.
- "Record a New Show": dismiss, then push ShowBuilderPageModel(stationId:, episodeId: nil, seriesId: series.id, slot: slot). #493's builder already offers slot first in its Schedule step, and lazy creation means nothing is saved until the first change.
- "Add" from a slot, when the slot is at least settings.airingEditLockMS away: mark that row busy (its "Add" becomes a progress view), disable the other Adds and "Record a New Show" (its action also returns early while busy), and block swipe-down. Step 1 is moveAiring(airing.id, slot) for a scheduled Show or scheduleEpisode(id, stationId, slot) for a draft. Only if step 1 succeeds, step 2 is updateEpisode(id, CuratorEpisodeUpdate(series: .join(series.id))). With no slot, only step 2 runs. When the steps end, success or failure, post recordedShowsChanged for the station, keep any failure, and dismiss the sheet.
- "Add" from a slot that is closer than settings.airingEditLockMS: replace the sheet with .scheduleShow(ScheduleShowSheetModel(episode:, series:, settings:, occupiedIntervals: occupiedIntervals(from: the passed airings, excludingEpisodeId: this Show's id), initialTime: slot, schedule:)). Its schedule closure runs step 1 for the airtime the curator confirms. If step 1 is refused (including AIRING_EDIT_LOCKED or AIRING_OVERLAP), it posts recordedShowsChanged so the screen behind refreshes, then throws step 1's error, so #493's sheet shows it inline as it already does and stays open; no alert is kept for later. If step 1 succeeds, it runs step 2, keeps a step 2 failure without throwing (the Show is now scheduled), and posts recordedShowsChanged. Add an optional dismissed closure to ScheduleShowSheetModel (default nil, so the builder's use is unchanged) and use it to complete the add. While the Schedule sheet saves (isSaving), block Cancel and swipe-down: cancelButtonTapped returns early, the view disables Cancel, and the sheet uses interactiveDismissDisabled(model.isSaving). This applies wherever the sheet is used, the builder included, so the sheet always stays open until its schedule closure (here, both steps) has finished. Cancel or swipe before Schedule is tapped schedules nothing and reports nothing.
- Alerts after dismissal: extend 001's MainContainer onDismiss bridge so that, once SwiftUI finishes dismissing them, it calls the dismissed closure of an Add a show sheet and of a Schedule sheet presented with one. The add calls onAddFinished exactly once, only after both the steps have ended and the sheet that ran them has finished dismissing, in either order. The Add a show sheet's own dismissal when the Schedule sheet replaces it does not count. The presenter then shows a PlayolaAlert, skipping cancellations:
- - step 1 refused: "Couldn't Add", or "Show Locked" for APIError.recordedShowLocked, with the server's message;
- - step 2 failed: "Scheduled, but Not in <Series>" with the server's message;
- - a no-slot join refused: "Couldn't Add".
- The recordedShowsChanged notification already refreshes the list or page.
- Register every new file in project.pbxproj. Add changelog.d/fill-series-slots.md. Add qa/ux/add-show-to-series as a visual case covering the sheet from a slot and the Schedule sheet opened from a near slot, and run make ux-evidence for it.

**Tests**

- AddShowToSeriesSheetTests for content: the from-a-slot and no-slot subtitles and row subtitles; drafts first, then scheduled Shows by air time; this Series' own Shows, locked Shows, Shows with more than one airing, drafts without audio and aired Shows are never offered; standalone Shows and Shows in another Series are offered; with nothing to offer, the heading is hidden.
- AddShowToSeriesSheetTests for loading: with a gated getCuratorEpisodes, "Record a New Show" is present and a progress view shows; a failure shows a toast and the nothing-to-offer look; a cancelled load shows no toast.
- AddShowToSeriesSheetTests for adding from a slot, with gated requests: a draft sends scheduleEpisode at the slot, then the join; a scheduled Show sends moveAiring for its airing, then the join; while working, the row is busy, the other Adds and "Record a New Show" are disabled, swipe is blocked, and calling recordNewShowTapped neither dismisses nor pushes until the add finishes; recordedShowsChanged is posted; the sheet dismisses only after both steps; onAddFinished runs once, after the wired dismissed closure, with no failure.
- AddShowToSeriesSheetTests for failures:
- - a step 1 refusal sends no join and leads to "Couldn't Add" with the server's message, or "Show Locked" for recordedShowLocked;
- - a step 2 failure leads to "Scheduled, but Not in <Series>", and the Show stays scheduled;
- - a no-slot add sends only the join, and its refusal leads to "Couldn't Add";
- - in every case the presenter's presentedAlert is nil until the dismissed closure has run, and also when dismissal finishes before the failure arrives, in which case it shows as soon as the failure arrives;
- - a cancellation shows nothing.
- AddShowToSeriesSheetTests for a near slot: an add inside settings.airingEditLockMS presents scheduleShow in place of the sheet, with the slot as its initial time and with occupied intervals that leave out the Show's own airings but keep every other Show's airings, including another airing at the same station. Its schedule closure:
- - on success runs step 1 then the join;
- - on a step 1 refusal posts recordedShowsChanged and throws, so the Schedule sheet keeps the error inline and stays open, no join is sent, and onAddFinished later reports no failure;
- - keeps a join failure without throwing, so the alert appears after the Schedule sheet's dismissed closure.
- Cancelling the Schedule sheet before Schedule is tapped calls nothing and reports nothing. The Add a show sheet's own dismissal during the hand-off does not call onAddFinished.
- AddShowToSeriesSheetTests for "Record a New Show": it dismisses and pushes the builder with seriesId and slot (and a nil slot with no slot), and sends no request.
- MainContainerTests: the dismissal bridge calls the dismissed closure of an Add a show sheet and of a Schedule sheet presented from one, exactly once each, and still calls the series picker's closure as before.
- ScheduleShowSheetTests: the existing suite still passes. With a gated schedule closure, Cancel is disabled and swipe is blocked while it runs, and cancelButtonTapped then neither dismisses nor stops the save; once the closure returns the sheet dismisses once, and once it throws the sheet stays open with the inline error and Cancel works again. For the near-slot add, attempting Cancel during step 1 and during step 2 leaves the sheet open, both steps run, and the alert (if any) shows only after the sheet closes.
- CuratorSeriesListPageTests and CuratorSeriesPageTests: "+ Add show" presents the sheet with the slot, settings and airings; the page's "Add a Show" presents it with no slot; after a failed first page load, "Add a Show" loads settings and airings and then presents the sheet, or on another failure shows the toast and presents nothing; onAddFinished's failure becomes the page's presentedAlert.
- Same suite conventions as PR 1. Run the full AddShowToSeriesSheetTests, ScheduleShowSheetTests, ShowBuilderPageTests, ShowBuilderPageSchedulingTests, MainContainerTests, CuratorSeriesListPageTests and CuratorSeriesPageTests with xcodebuild, plus make lint and make changelog-check.

**Screenshots it must match**

- `screenshots/add-a-show-sheet--from-a-slot.png`
- `screenshots/schedule-sheet--locks-right-away.png`

**"Done when" items it delivers**

- 11. While the Add a show list loads, "Record a New Show" is already there with a progress view below it; if the list fails to load, a toast shows and the sheet offers only "Record a New Show".
- 12. While an "Add" works, its row shows a progress view and the other "Add" buttons and "Record a New Show" are disabled; the sheet closes only when every step has finished, and any refusal's alert shows after it closes.
- 13. From a slot, adding a draft schedules it at that time and puts it in the Series; adding a scheduled Show moves it there and puts it in the Series. Both then show in that slot on the page.
- 14. If joining the Series fails after scheduling succeeds, an alert says so and the Show stays scheduled at the slot's time.
- 15. A slot less than 6 hours away opens the Schedule sheet at that slot with "Locks right away" showing.
- 16. The Add a show sheet never offers locked Shows, Shows with more than one airing, drafts without audio, or this Series' own Shows.
- 17. "Add a Show" with no slot puts the chosen Show in the Series without changing its time.
- 18. "Record a New Show" from a slot opens the builder for a new Show in the Series, with the slot offered first in its Schedule step. Backing out without changes leaves nothing behind.

<!-- factory: finished plan for design 60a5f9e793704fd8e22bc314417b96f4b5a9aeda622b1ad638b690ed1a62051c, plan 768068b6b3853ce5adb4e20f341ef90a0965f7fb0794a478ba202dfbd5d1af36. Any edit to this file or the design undoes it; run "factory finalize" again. -->
